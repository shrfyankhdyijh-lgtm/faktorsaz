package com.factorsaze.faktorsaz

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val invoiceExportChannel = "com.factorsaze.faktorsaz/invoice_export"
    private val createDocumentRequest = 24051
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, invoiceExportChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveInvoiceFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType")
                val isImage = call.argument<Boolean>("isImage") ?: false
                if (bytes == null || fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
                    result.error("invalid_invoice_file", "اطلاعات فایل معتبر نیست.", null)
                    return@setMethodCallHandler
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveToMediaStore(bytes, fileName, mimeType, isImage, result)
                } else {
                    saveWithDocumentPicker(bytes, fileName, mimeType, result)
                }
            }
    }

    private fun saveToMediaStore(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        isImage: Boolean,
        result: MethodChannel.Result,
    ) {
        val collection: Uri = if (isImage) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val relativePath = if (isImage) {
            "${Environment.DIRECTORY_PICTURES}/Faktorsaz"
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/Faktorsaz"
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = contentResolver.insert(collection, values)
        if (uri == null) {
            result.error("invoice_file_insert_failed", "ساخت فایل در حافظه ناموفق بود.", null)
            return
        }

        try {
            contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                ?: throw IllegalStateException("امکان نوشتن فایل وجود ندارد.")
            contentResolver.update(uri, ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }, null, null)
            result.success("$relativePath/$fileName")
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            result.error("invoice_file_write_failed", error.message, null)
        }
    }

    private fun saveWithDocumentPicker(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        if (pendingSaveResult != null) {
            result.error("invoice_file_save_busy", "ذخیره فایل دیگری در حال انجام است.", null)
            return
        }
        pendingSaveResult = result
        pendingSaveBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, createDocumentRequest)
        } catch (error: Exception) {
            clearPendingSave()
            result.error("invoice_file_picker_failed", error.message, null)
        }
    }

    @Deprecated("Deprecated by Android, retained for compatibility with the SAF result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createDocumentRequest) return

        val result = pendingSaveResult ?: return
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null)
            clearPendingSave()
            return
        }

        try {
            val bytes = pendingSaveBytes ?: throw IllegalStateException("فایل آماده نیست.")
            contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                ?: throw IllegalStateException("امکان نوشتن فایل وجود ندارد.")
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("invoice_file_write_failed", error.message, null)
        } finally {
            clearPendingSave()
        }
    }

    private fun clearPendingSave() {
        pendingSaveResult = null
        pendingSaveBytes = null
    }
}
