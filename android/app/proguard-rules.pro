# flutter_local_notifications : utilise Gson pour (dé)sérialiser les données
# de notification. Sans ce keep, R8 obfusque les champs et les notifications
# échouent silencieusement en release.
-keep class com.dexterous.** { *; }

# Gson (transitif de flutter_local_notifications)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
