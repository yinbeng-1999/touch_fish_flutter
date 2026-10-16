package com.example.touch_fish_flutter

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import flutter.overlay.window.flutter_overlay_window.OverlayService

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "touch_fish_flutter/social",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openSocialApp") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val packageName = call.argument<String>("packageName")
            val url = call.argument<String>("url")
            if (packageName == null || url == null) {
                result.error("INVALID_ARGUMENT", "App package and URL are required", null)
                return@setMethodCallHandler
            }

            try {
                val appIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    setPackage(packageName)
                }
                try {
                    startActivity(appIntent)
                } catch (_: android.content.ActivityNotFoundException) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }
                result.success(true)
            } catch (error: Exception) {
                result.error("OPEN_APP_FAILED", error.message, null)
            }
        }
    }

    override fun onDestroy() {
        if (isFinishing) {
            stopService(Intent(this, OverlayService::class.java))
        }
        super.onDestroy()
    }
}
