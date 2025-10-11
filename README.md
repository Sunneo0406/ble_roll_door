重要事項關於BLE連線問題



重要兩個檔案  build.gradle.kts及AndroidManifest.xml 這兩個搞不定可以搞你一整天





1\.C:\\flutter\_controler\\android\\app\\build.gradle.kts



plugins {

&nbsp;   id("com.android.application")

&nbsp;   id("kotlin-android")

&nbsp;   // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.

&nbsp;   id("dev.flutter.flutter-gradle-plugin")

}



android {

&nbsp;   namespace = "com.example.flutter\_controler"

&nbsp;   compileSdk = flutter.compileSdkVersion

&nbsp;   ndkVersion = flutter.ndkVersion



&nbsp;   compileOptions {

&nbsp;       sourceCompatibility = JavaVersion.VERSION\_11

&nbsp;       targetCompatibility = JavaVersion.VERSION\_11

&nbsp;   }



&nbsp;   kotlinOptions {

&nbsp;       jvmTarget = JavaVersion.VERSION\_11.toString()

&nbsp;   }



&nbsp;   defaultConfig {

&nbsp;       // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).

&nbsp;       applicationId = "com.example.flutter\_controler"

&nbsp;       // You can update the following values to match your application needs.

&nbsp;       // For more information, see: https://flutter.dev/to/review-gradle-config.

&nbsp;       minSdk = flutter.minSdkVersion

&nbsp;       // \*\*\* 關鍵修正：強制設定 targetSdk 為 33 (Android 13) \*\*\*=====================================================================================================這裡修正

&nbsp;       targetSdk = 33 

&nbsp;       versionCode = flutter.versionCode

&nbsp;       versionName = flutter.versionName

&nbsp;   }



&nbsp;   buildTypes {

&nbsp;       release {

&nbsp;           // TODO: Add your own signing config for the release build.

&nbsp;           // Signing with the debug keys for now, so `flutter run --release` works.

&nbsp;           signingConfig = signingConfigs.getByName("debug")

&nbsp;       }

&nbsp;   }

}



flutter {

&nbsp;   source = "../.."

}



----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

2.C:\\flutter\_controler\\android\\app\\src\\main\\AndroidManifest.xml



<manifest xmlns:android="http://schemas.android.com/apk/res/android">



&nbsp;   <uses-permission android:name="android.permission.BLUETOOTH\_SCAN" android:usesPermissionFlags="neverForLocation" />

&nbsp;   <uses-permission android:name="android.permission.BLUETOOTH\_CONNECT" />

&nbsp;   <uses-permission android:name="android.permission.BLUETOOTH\_ADVERTISE" />



&nbsp;   <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />

&nbsp;   <uses-permission android:name="android.permission.BLUETOOTH\_ADMIN" android:maxSdkVersion="30" />

&nbsp;   

&nbsp;   <uses-permission android:name="android.permission.ACCESS\_FINE\_LOCATION" />

&nbsp;   <uses-permission android:name="android.permission.ACCESS\_COARSE\_LOCATION" />                                          /\*以上權限修改\*/\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*





&nbsp;   <application

&nbsp;       android:label="造粒廠鐵門控制器"

&nbsp;       android:name="${applicationName}"

&nbsp;       android:icon="@mipmap/ic\_launcher">

&nbsp;       <activity

&nbsp;           android:name=".MainActivity"

&nbsp;           android:exported="true"

&nbsp;           android:launchMode="singleTop"

&nbsp;           android:theme="@style/LaunchTheme"

&nbsp;           android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"

&nbsp;           android:hardwareAccelerated="true"

&nbsp;           android:windowSoftInputMode="adjustResize">

&nbsp;           <meta-data

&nbsp;             android:name="io.flutter.embedding.android.NormalTheme"

&nbsp;             android:resource="@style/NormalTheme"

&nbsp;             />

&nbsp;           <intent-filter>

&nbsp;               <action android:name="android.intent.action.MAIN"/>

&nbsp;               <category android:name="android.intent.category.LAUNCHER"/>

&nbsp;           </intent-filter>

&nbsp;       </activity>

&nbsp;       <meta-data

&nbsp;           android:name="flutterEmbedding"

&nbsp;           android:value="2" />

&nbsp;   </application>

</manifest>



