package com.hiasl.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.hiasl.app/recognition"
    private var detector: HandLandmarkDetector? = null

    companion object {
        // Survive Activity recreation. Set false once MediaPipe fails (x86_64 emulator has no .so).
        var mediaPipeAvailable = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processFrame" -> {
                        if (!mediaPipeAvailable) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            if (detector == null) {
                                detector = HandLandmarkDetector(this)
                            }
                            val yBytes = call.argument<ByteArray>("yBytes")!!
                            val uBytes = call.argument<ByteArray>("uBytes")!!
                            val vBytes = call.argument<ByteArray>("vBytes")!!
                            val width = call.argument<Int>("width")!!
                            val height = call.argument<Int>("height")!!
                            val yRowStride = call.argument<Int>("yRowStride")!!
                            val uvRowStride = call.argument<Int>("uvRowStride")!!
                            val uvPixelStride = call.argument<Int>("uvPixelStride")!!

                            val landmarks = detector!!.processFrame(
                                yBytes, uBytes, vBytes,
                                width, height,
                                yRowStride, uvRowStride, uvPixelStride,
                            )
                            result.success(landmarks)
                        } catch (e: Throwable) {
                            // UnsatisfiedLinkError (extends Error, not Exception) fires on
                            // x86_64 emulators because tasks-vision ships no x86_64 .so.
                            mediaPipeAvailable = false
                            android.util.Log.w("Recognition", "MediaPipe unavailable: ${e.message}")
                            result.success(null)
                        }
                    }
                    "stopSession" -> {
                        detector?.close()
                        detector = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
