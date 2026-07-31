package com.hiasl.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val channelName = "com.hiasl.app/recognition"
    private var detector: HandLandmarkDetector? = null
    private val detectorLock = Any()

    companion object {
        // Survive Activity recreation. Set false once MediaPipe fails (x86_64 emulator has no .so).
        var mediaPipeAvailable = true
    }

    // Synchronized so a background warm-up and a processFrame call racing each
    // other reuse the same in-progress/created instance instead of building
    // two HandLandmarkDetectors (each with its own GPU-delegate HandLandmarker).
    private fun getOrCreateDetector(): HandLandmarkDetector {
        synchronized(detectorLock) {
            var d = detector
            if (d == null) {
                d = HandLandmarkDetector(this)
                detector = d
            }
            return d
        }
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
                            val yBytes = call.argument<ByteArray>("yBytes")!!
                            val uBytes = call.argument<ByteArray>("uBytes")!!
                            val vBytes = call.argument<ByteArray>("vBytes")!!
                            val width = call.argument<Int>("width")!!
                            val height = call.argument<Int>("height")!!
                            val yRowStride = call.argument<Int>("yRowStride")!!
                            val uvRowStride = call.argument<Int>("uvRowStride")!!
                            val uvPixelStride = call.argument<Int>("uvPixelStride")!!
                            val rotationDegrees = call.argument<Int>("rotationDegrees") ?: 0

                            val landmarks = getOrCreateDetector().processFrame(
                                yBytes, uBytes, vBytes,
                                width, height,
                                yRowStride, uvRowStride, uvPixelStride,
                                rotationDegrees,
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
                    "warmUpDetector" -> {
                        if (!mediaPipeAvailable) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        // Off the main thread: constructing HandLandmarker with
                        // Delegate.GPU compiles shaders and sets up a GPU context,
                        // which takes seconds and must not block the UI thread.
                        thread {
                            try {
                                getOrCreateDetector()
                            } catch (e: Throwable) {
                                mediaPipeAvailable = false
                                android.util.Log.w("Recognition", "MediaPipe unavailable: ${e.message}")
                            }
                            runOnUiThread { result.success(null) }
                        }
                    }
                    "stopSession" -> {
                        synchronized(detectorLock) {
                            detector?.close()
                            detector = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
