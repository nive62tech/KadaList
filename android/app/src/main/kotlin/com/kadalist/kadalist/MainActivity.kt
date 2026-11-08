package com.kadalist.kadalist

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private var speech: OfflineSpeech? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speech = OfflineSpeech(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kadalist/offline_speech"))
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OfflineSpeech.PICK_MODEL) speech?.modelResult(if (resultCode == RESULT_OK) data?.data else null)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == OfflineSpeech.MIC_PERMISSION) speech?.permissionResult(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }
    override fun onStop() {
        speech?.cancel()
        super.onStop()
    }
    override fun onDestroy() {
        speech?.close()
        super.onDestroy()
    }
}
