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

# Room instantiates its generated database classes reflectively through the
# no-argument constructor (Room.getGeneratedImplementation). Room 2.6.1's own
# consumer rule is `-keep class * extends androidx.room.RoomDatabase`, which in
# R8 full mode (the AGP 8+ default) keeps the class but not that constructor,
# so WorkManager's androidx.startup initializer died at process start with
# "NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []" in
# the 1.3.0 release build (#297, #298). Debug builds are not shrunk and never
# showed it.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
