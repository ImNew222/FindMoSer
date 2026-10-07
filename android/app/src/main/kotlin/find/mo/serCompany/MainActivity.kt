package find.mo.serCompany

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "findmoser/device_id")
            .setMethodCallHandler { call, result ->
                if (call.method != "getAndroidId") {
                    result.notImplemented()
                } else {
                    try {
                        val id = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        if (id.isNullOrBlank()) {
                            result.error("UNAVAILABLE", "Android ID is unavailable", null)
                        } else {
                            result.success(id)
                        }
                    } catch (_: Exception) {
                        result.error("UNAVAILABLE", "Unable to read Android ID", null)
                    }
                }
            }
    }
}
