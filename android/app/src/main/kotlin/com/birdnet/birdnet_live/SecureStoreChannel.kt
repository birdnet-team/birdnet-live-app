package com.birdnet.birdnet_live

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Keychain-style key-value store — the Android half of the
 * `com.birdnet/secure_store` channel. See lib/features/upload/secret_store.dart
 * for the contract, SecureStoreChannel.swift and secure_store_channel.cpp for
 * the iOS and Windows halves.
 *
 * Values are encrypted with an AES-GCM key that lives in the Android Keystore
 * (never leaves the secure hardware where available) and stored as
 * `base64(iv):base64(ciphertext)` in a private SharedPreferences file. A value
 * that no longer decrypts — after a Keystore reset, for example — reads as
 * missing rather than failing, so the app can ask the user to re-enter it.
 */
class SecureStoreChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "com.birdnet/secure_store"
        private const val KEY_ALIAS = "birdnet_secure_store"
        private const val PREFS = "birdnet_secure_store"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val prefs by lazy { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }

    init {
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key.isNullOrEmpty()) {
            result.error("bad_args", "key is required", null)
            return
        }
        try {
            when (call.method) {
                "read" -> result.success(read(key))
                "write" -> {
                    val value = call.argument<String>("value")
                    if (value == null) {
                        result.error("bad_args", "value is required", null)
                    } else {
                        write(key, value)
                        result.success(null)
                    }
                }
                "delete" -> {
                    prefs.edit().remove(key).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("secure_store", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private fun write(key: String, value: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val ciphertext = Base64.encodeToString(cipher.doFinal(value.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
        prefs.edit().putString(key, "$iv:$ciphertext").apply()
    }

    private fun read(key: String): String? {
        val stored = prefs.getString(key, null) ?: return null
        val parts = stored.split(':')
        if (parts.size != 2) return null
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey(),
                GCMParameterSpec(GCM_TAG_BITS, Base64.decode(parts[0], Base64.NO_WRAP)),
            )
            String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
        } catch (_: Exception) {
            // Key rotated or Keystore reset: the value is unrecoverable.
            null
        }
    }
}
