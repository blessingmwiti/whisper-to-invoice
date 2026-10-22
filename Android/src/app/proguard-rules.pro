###############################################################################
# Whisper to Invoice - R8 / ProGuard configuration for the release build.
#
# AGP 8+ runs R8 in "full mode": only the members that are statically reachable
# survive, and everything else is renamed. The rules below cover the parts of
# the app that R8 cannot see because they are reached through reflection, JNI
# or code that is generated at build time.
#
# Rules contributed by the dependencies themselves (AndroidX, Hilt, WorkManager,
# ML Kit) are shipped inside the AARs and are applied automatically. The ones
# below are for the libraries that do not ship complete rules (Gson, Moshi,
# protobuf, Room) and for the parts of this app that R8 cannot see.
###############################################################################


# ----------------------------------------------------------------------------
# Attributes
# ----------------------------------------------------------------------------
# Generic signatures are required by Gson/Moshi to resolve types such as
# Map<String, List<String>> in the model and skill allowlists.
-keepattributes Signature

# Kotlin metadata and the runtime visible annotations that are read reflectively:
#   * @kotlin.Metadata          -> kotlin-reflect (LiteRT-LM tool discovery)
#   * @Tool / @ToolParam        -> LiteRT-LM function calling
#   * @SerializedName           -> Gson
#   * @JsonClass                -> Moshi
#   * @JavascriptInterface      -> WebView JS bridge
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,AnnotationDefault,InnerClasses,EnclosingMethod

# Keep line numbers so that stack traces stay readable, but hide the original
# source file name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile


# ----------------------------------------------------------------------------
# LiteRT-LM - JNI
# ----------------------------------------------------------------------------
# liblitertlm_jni.so resolves these classes with FindClass() and calls their
# methods with GetMethodID(), and it binds the native methods below through the
# Java_<class>_<method> symbol convention. Any rename breaks the binding with
# an UnsatisfiedLinkError / NoClassDefFoundError at runtime.
-keep class com.google.ai.edge.litertlm.LiteRtLmJni { *; }
-keep class com.google.ai.edge.litertlm.LiteRtLmJni$* { *; }
-keep class com.google.ai.edge.litertlm.NativeLibraryLoader { *; }
-keep class com.google.ai.edge.litertlm.InputData { *; }
-keep class com.google.ai.edge.litertlm.InputData$* { *; }
-keep class com.google.ai.edge.litertlm.BenchmarkInfo { *; }
-keep class com.google.ai.edge.litertlm.LiteRtLmJniException { *; }


# ----------------------------------------------------------------------------
# LiteRT-LM - function calling (kotlin-reflect)
# ----------------------------------------------------------------------------
# The @Tool functions are discovered through kotlin-reflect
# (KClasses.getFunctions / KFunction.getName) and are never called directly, so
# R8 would remove them. The tool name and the parameter names are sent to the
# model, therefore the class, the methods and their names must be preserved.
-keep class * implements com.google.ai.edge.litertlm.ToolSet {
    @com.google.ai.edge.litertlm.Tool <methods>;
}
-keepclassmembers class * {
    @com.google.ai.edge.litertlm.Tool <methods>;
}

# The annotations themselves are read reflectively to build the schema that is
# sent to the model. Without the annotation classes R8 drops them together
# with the descriptions of the tools and of their parameters.
-keep class com.google.ai.edge.litertlm.Tool { *; }
-keep class com.google.ai.edge.litertlm.ToolParam { *; }
# The parameter annotations are stored in a separate attribute.
-keepattributes RuntimeVisibleParameterAnnotations

# kotlin-reflect itself: the implementation is not safe to be optimized or
# merged by R8, the metadata of every reflected upon class is needed.
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**


# ----------------------------------------------------------------------------
# Gson
# ----------------------------------------------------------------------------
# Gson resolves the type adapter of a model reflectively (TypeToken +
# ReflectiveTypeAdapterFactory) and casts the result through a raw Class.
# R8 cannot follow that lookup and concludes that Gson.fromJson() always
# throws. Every call site is wrapped in a try/catch, so R8 removes the whole
# code path - including the model allowlist, the skill allowlist and the
# invoice storage. Keeping the library and the call sites prevents this.
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.ai.edge.gallery.ui.modelmanager.ModelManagerViewModel { *; }
-keepclassmembers class com.google.ai.edge.gallery.customtasks.agentchat.SkillManagerViewModel { *; }
-keepclassmembers class com.google.ai.edge.gallery.customtasks.invoiceextraction.InvoiceRepository { *; }
-keepclassmembers class com.google.ai.edge.gallery.customtasks.invoiceextraction.InvoiceExtractionViewModel { *; }

# The models are instantiated by Gson through reflection, and some of them are
# only reachable through an erased generic (List<AllowedModel>), so R8 would
# remove them. The field names are the JSON keys, so they are kept as well.
-keep class com.google.ai.edge.gallery.data.ModelAllowlist { *; }
-keep class com.google.ai.edge.gallery.data.AllowedModel { *; }
-keep class com.google.ai.edge.gallery.data.DefaultConfig { *; }
-keep class com.google.ai.edge.gallery.data.SocModelFile { *; }
-keep class com.google.ai.edge.gallery.data.NamedDeviceGroup { *; }
-keep class com.google.ai.edge.gallery.data.DeviceRequirements { *; }
-keep class com.google.ai.edge.gallery.data.SkillAllowlist { *; }
-keep class com.google.ai.edge.gallery.data.AllowedSkill { *; }
-keep class com.google.ai.edge.gallery.data.ModelFile { *; }
-keep class com.google.ai.edge.gallery.customtasks.invoiceextraction.SavedInvoice { *; }
-keep class com.google.ai.edge.gallery.customtasks.invoiceextraction.InvoiceData { *; }
-keep class com.google.ai.edge.gallery.customtasks.invoiceextraction.InvoiceLineItem { *; }
-keep class com.google.ai.edge.gallery.customtasks.invoiceextraction.InvoiceDto { *; }
-keep class com.google.ai.edge.gallery.customtasks.invoiceextraction.ItemDto { *; }

# The allowlist enums are deserialized by name, and R8 removes enum constants
# that are not referenced by the app code.
-keep enum com.google.ai.edge.gallery.data.ModelCapability { *; }
-keep enum com.google.ai.edge.gallery.data.RuntimeType { *; }
-keep enum com.google.ai.edge.gallery.data.AICoreModelReleaseStage { *; }
-keep enum com.google.ai.edge.gallery.data.AICoreModelPreference { *; }


# ----------------------------------------------------------------------------
# Moshi
# ----------------------------------------------------------------------------
# Moshi looks up the generated adapter by name (Class.forName("<Model>JsonAdapter")),
# which R8 cannot detect. When such an adapter is removed, R8 concludes that
# Moshi.adapter() always throws and drops the whole call site together with the
# model class, so the adapters have to be kept by name.
-keep class **JsonAdapter {
    <init>(...);
}
# The models themselves are the key of the adapter lookup, keep them as well.
-if @com.squareup.moshi.JsonClass class *
-keep class <1> { *; }
# The annotation itself is read at runtime by Moshi.
-keep class com.squareup.moshi.JsonClass { *; }

# The classes that resolve an adapter have to be kept as well: R8 cannot see
# the reflective lookup inside Moshi, so it may conclude that
# Moshi.adapter() always throws and remove the code that uses it - most
# notably the "send_email" / "send_sms" branches of IntentHandler, which are
# wrapped in a try/catch and would then be optimized away completely.
-keepclassmembers class com.google.ai.edge.gallery.customtasks.agentchat.IntentHandler { *; }
-keepclassmembers class com.google.ai.edge.gallery.customtasks.agentchat.AgentTools { *; }
-keepclassmembers class com.google.ai.edge.gallery.customtasks.agentchat.SkillTesterBottomSheet { *; }

# Moshi also uses kotlin-reflect to read the @Json names of the models.
-keepclassmembers class * {
    @com.squareup.moshi.Json <fields>;
}


# ----------------------------------------------------------------------------
# protobuf (lite)
# ----------------------------------------------------------------------------
# protobuf-javalite does not ship ProGuard rules. The generated messages and
# the outer *Proto classes hold the serialized file descriptor that is parsed
# lazily at runtime.
-keep class com.google.ai.edge.gallery.proto.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**


# ----------------------------------------------------------------------------
# WebView JavaScript bridge
# ----------------------------------------------------------------------------
# The bridge is called from JavaScript as "AiEdgeGallery.onResultReady(...)",
# so the method names annotated with @JavascriptInterface must survive.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.google.ai.edge.gallery.customtasks.agentchat.ChatWebViewJavascriptInterface { *; }


# ----------------------------------------------------------------------------
# WorkManager
# ----------------------------------------------------------------------------
# WorkManager persists the worker class name in its database and instantiates
# the worker reflectively. WorkManager keeps the name of ListenableWorker
# subclasses, this rule additionally keeps the constructor of the app worker.
-keep class com.google.ai.edge.gallery.worker.** {
    <init>(...);
}
-keepnames class * extends androidx.work.ListenableWorker


# ----------------------------------------------------------------------------
# Hilt / Dagger
# ----------------------------------------------------------------------------
# The custom tasks are contributed to the home screen through a multibinding
# set (@IntoSet). The generated Dagger code references the implementations
# directly, only the names are kept for readability.
-keepnames class * implements com.google.ai.edge.gallery.customtasks.common.CustomTask
-keepnames interface com.google.ai.edge.gallery.customtasks.common.CustomTask

# Entry points that are resolved through reflection by Hilt.
-keep,allowobfuscation class * implements dagger.hilt.EntryPoint { *; }
-keep,allowobfuscation class * implements dagger.hilt.internal.GeneratedEntryPoint { *; }


# ----------------------------------------------------------------------------
# TensorFlow Lite
# ----------------------------------------------------------------------------
# The interpreter is instantiated from native code, which resolves the Java
# classes by name.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**


# ----------------------------------------------------------------------------
# Room
# ----------------------------------------------------------------------------
# Room instantiates the generated "<Db>_Impl" class through its no-arg
# constructor, room-runtime does not ship any rules for it.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}


# ----------------------------------------------------------------------------
# ML Kit
# ----------------------------------------------------------------------------
# ML Kit discovers its components by instantiating the registrar reflectively.
-keep class com.google.mlkit.common.internal.CommonComponentRegistrar {
    <init>();
}


# ----------------------------------------------------------------------------
# Miscellaneous
# ----------------------------------------------------------------------------
# OpenID AppAuth serializes its requests and responses with org.json, it does
# not use reflection. Keep the names of the activities that it contributes to
# the manifest for readability.
-keepnames class net.openid.appauth.**

# Keep the enum valueOf()/values() of the app enums that are parsed from JSON.
-keepclassmembers enum com.google.ai.edge.gallery.** {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
