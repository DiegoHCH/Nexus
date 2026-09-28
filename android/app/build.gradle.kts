import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 🔴 **La llave de release, si está.** En el Mac, `android/key.properties`
// (fuera de git) apunta a la llave y trae su contraseña; en el CI, las mismas
// cuatro cosas llegan por el entorno desde los secretos del repo. Sin ninguna
// de las dos se firma con la de depuración, que es lo que quiere quien corre la
// app en su teléfono para probar: así `flutter run --release` sigue andando.
//
// Tiene que ser **siempre la misma llave**: Android no deja instalar encima una
// app firmada con otra, y la app del teléfono se actualiza sola desde las
// releases de GitHub —ver `LaActualizacionDelTelefono`—.
val laLlave = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
    System.getenv("NEXUS_ANDROID_KEYSTORE")?.let { setProperty("storeFile", it) }
    System.getenv("NEXUS_ANDROID_PASSWORD")?.let {
        setProperty("storePassword", it)
        setProperty("keyPassword", it)
    }
    System.getenv("NEXUS_ANDROID_ALIAS")?.let { setProperty("keyAlias", it) }
}
val hayLlaveDeRelease = laLlave.getProperty("storeFile")?.let { file(it).exists() } == true

android {
    namespace = "com.example.nexus"
    // 37 y no lo que traiga Flutter: `flutter_secure_storage` —el paquete que
    // guarda el token del canal— exige compilar contra la 37, y con la 36 el build
    // falla en `checkDebugAarMetadata` antes de compilar una línea de Dart.
    //
    // El propio Gradle avisa de que el máximo *recomendado* para AGP 9.0.1 es la 36.
    // Se acepta el aviso porque la alternativa es peor: bajar de versión el paquete
    // que guarda un secreto, o guardar el token en un sitio que no sea el Keystore.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.katanalabs.nexus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayLlaveDeRelease) {
            create("release") {
                storeFile = file(laLlave.getProperty("storeFile"))
                storePassword = laLlave.getProperty("storePassword")
                keyAlias = laLlave.getProperty("keyAlias")
                keyPassword = laLlave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (hayLlaveDeRelease) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
