package com.example.bida_score

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "bida_score/pip"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipSupported()) {
                        val num = call.argument<Int>("aspectNumerator") ?: 4
                        val den = call.argument<Int>("aspectDenominator") ?: 3
                        val ok = enterPipSafely(num, den)
                        result.success(ok)
                    } else {
                        result.success(false)
                    }
                }
                "isPipSupported" -> {
                    result.success(isPipSupported())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun enterPipSafely(num: Int, den: Int): Boolean {
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(num.coerceAtLeast(1), den.coerceAtLeast(1)))
                .build()
            enterPictureInPictureMode(params)
        } catch (t: Throwable) {
            false
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
    }
}
