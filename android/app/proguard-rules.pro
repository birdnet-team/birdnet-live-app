# Keep ONNX Runtime JNI bindings
-keep class ai.onnxruntime.** { *; }

# Keep Flutter plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress warnings for Play Core deferred components (not used)
-dontwarn com.google.android.play.core.**

# play-services-location is excluded in build.gradle (see the comment there),
# so geolocator's FusedLocationClient and GeolocationManager are left with
# dangling references to it. R8 errors on missing classes, so they must be
# suppressed.
#
# Enumerating the classes works today — only those R8 still reaches after
# shrinking need a rule — but that set is an artefact of which FusedLocationClient
# methods survive, so a geolocator upgrade or an R8 change can silently add a
# new one and break the release build only. Suppress the whole tree instead;
# the app calls no GMS API of its own, and Play Asset Delivery lives under
# com.google.android.play, so this hides nothing we care about.
-dontwarn com.google.android.gms.**
