package todo.yeenlink

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Канал yeenlink/platform (lib/core/account/platform_bridge.dart):
/// модель телефона, «чувствительный» буфер обмена, сохранение файла.
class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<String, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yeenlink/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceModel" -> result.success(Build.MODEL)
                    "copySensitive" -> {
                        copySensitive(call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    "saveText" -> saveText(
                        call.argument<String>("name") ?: "yeenlink.txt",
                        call.argument<String>("text") ?: "",
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // Android 13+ не показывает превью «чувствительного» содержимого буфера.
    private fun copySensitive(text: String) {
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            } else {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
        }
        (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(clip)
    }

    private fun saveText(name: String, text: String, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("busy", "уже выбирается место сохранения", null)
            return
        }
        pendingSave = text to result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        startActivityForResult(intent, SAVE_REQUEST)
    }

    @Deprecated("Flutter v2 embedding всё ещё доставляет результат сюда")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST) return
        val (text, result) = pendingSave ?: return
        pendingSave = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(uri, "wt")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
            result.success(true)
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    private companion object {
        const val SAVE_REQUEST = 4207
    }
}
