# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# Keep public classes and methods for React Native module bridge
-keep class com.technotoil.image_videoeditor.** { *; }

# Keep MLKit and FFmpeg dependencies if they use reflection
-keep class com.google.mlkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
