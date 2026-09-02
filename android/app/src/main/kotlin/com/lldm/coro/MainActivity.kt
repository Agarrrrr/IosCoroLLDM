package com.lldm.coro

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.lldm.coro/file_saver"
    private val createFileRequest = 4101
    private val chooseFolderRequest = 4102
    private var pendingResult: MethodChannel.Result? = null
    private var pendingFiles: List<SaveFile> = emptyList()
    private var audioDeviceCallback: AudioDeviceCallback? = null

    data class SaveFile(
        val path: String,
        val name: String,
        val mimeType: String,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val audioRouteChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.lldm.coro/audio_route",
        )
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioDeviceCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                notifyAudioRouteChanged(audioRouteChannel, audioManager)
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                notifyAudioRouteChanged(audioRouteChannel, audioManager)
            }
        }.also { audioManager.registerAudioDeviceCallback(it, null) }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveFiles") {
                startSave(call, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun notifyAudioRouteChanged(
        channel: MethodChannel,
        audioManager: AudioManager,
    ) {
        runOnUiThread {
            val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map {
                mapOf("name" to it.productName.toString(), "type" to it.type)
            }
            channel.invokeMethod("routeChanged", mapOf("outputs" to outputs))
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioDeviceCallback?.let {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.unregisterAudioDeviceCallback(it)
        }
        audioDeviceCallback = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun startSave(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Ya hay una operación de guardado activa.", null)
            return
        }

        val rawFiles = call.argument<List<Map<String, String>>>("files").orEmpty()
        val files = rawFiles.mapNotNull { item ->
            val path = item["path"] ?: return@mapNotNull null
            val name = item["name"] ?: return@mapNotNull null
            SaveFile(path, name, item["mimeType"] ?: "application/octet-stream")
        }.filter { File(it.path).isFile }

        if (files.isEmpty()) {
            result.error("missing_files", "No hay archivos para guardar.", null)
            return
        }

        pendingResult = result
        pendingFiles = files
        if (files.size == 1) {
            val file = files.first()
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = file.mimeType
                putExtra(Intent.EXTRA_TITLE, file.name)
            }
            startActivityForResult(intent, createFileRequest)
        } else {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                )
            }
            startActivityForResult(intent, chooseFolderRequest)
        }
    }

    @Deprecated("Deprecated in Android SDK, required for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createFileRequest && requestCode != chooseFolderRequest) return

        val result = pendingResult ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            clearPending()
            result.success(false)
            return
        }

        try {
            if (requestCode == createFileRequest) {
                copyToUri(pendingFiles.first(), uri)
            } else {
                val flags = data.flags and (
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                try {
                    contentResolver.takePersistableUriPermission(uri, flags)
                } catch (_: SecurityException) {
                    // Algunos proveedores permiten escribir sin permiso persistente.
                }
                val parentDocumentUri = DocumentsContract.buildDocumentUriUsingTree(
                    uri,
                    DocumentsContract.getTreeDocumentId(uri),
                )
                pendingFiles.forEach { file ->
                    val destination = DocumentsContract.createDocument(
                        contentResolver,
                        parentDocumentUri,
                        file.mimeType,
                        file.name,
                    ) ?: error("No se pudo crear ${file.name}")
                    copyToUri(file, destination)
                }
            }
            clearPending()
            result.success(true)
        } catch (error: Exception) {
            clearPending()
            result.error("save_failed", error.message, null)
        }
    }

    private fun copyToUri(file: SaveFile, destination: Uri) {
        FileInputStream(File(file.path)).use { input ->
            contentResolver.openOutputStream(destination, "w").use { output ->
                requireNotNull(output) { "No se pudo abrir el archivo de destino." }
                input.copyTo(output)
            }
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingFiles = emptyList()
    }
}
