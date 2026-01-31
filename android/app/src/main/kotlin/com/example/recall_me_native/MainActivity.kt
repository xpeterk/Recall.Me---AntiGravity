package com.example.recall_me_native

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.recall_me.native/audio"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startService") {
                val intent = Intent(this, TranscriptionService::class.java)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                result.success(true)
            } else if (call.method == "stopService") {
                val intent = Intent(this, TranscriptionService::class.java)
                stopService(intent)
                result.success(true)
            } else if (call.method == "getVolume") {
                val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                val stream = call.argument<Int>("stream") ?: android.media.AudioManager.STREAM_NOTIFICATION
                val volume = audioManager.getStreamVolume(stream)
                result.success(volume)
            } else if (call.method == "setVolume") {
                val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                val stream = call.argument<Int>("stream") ?: android.media.AudioManager.STREAM_NOTIFICATION
                val volume = call.argument<Int>("volume") ?: 0
                val showUI = call.argument<Boolean>("showUI") ?: false
                val flags = if (showUI) android.media.AudioManager.FLAG_SHOW_UI else 0
                audioManager.setStreamVolume(stream, volume, flags)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
