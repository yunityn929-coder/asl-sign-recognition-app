package com.hiasl.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker.HandLandmarkerOptions
import com.google.mediapipe.framework.image.BitmapImageBuilder
import java.io.ByteArrayOutputStream

class HandLandmarkDetector(context: Context) {

    private val handLandmarker: HandLandmarker

    init {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task")
            .build()
        val options = HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setNumHands(1)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setRunningMode(RunningMode.IMAGE)
            .build()
        handLandmarker = HandLandmarker.createFromOptions(context, options)
    }

    /**
     * Process a YUV_420_888 camera frame and return 42 doubles (x,y for each of 21
     * landmarks), or null when no hand is detected.
     */
    fun processFrame(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
    ): List<Double>? {
        val bitmap = yuv420ToBitmap(yBytes, uBytes, vBytes, width, height, yRowStride, uvRowStride, uvPixelStride)
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = handLandmarker.detect(mpImage)
        if (result.landmarks().isEmpty()) return null
        // Take only the first detected hand; x and y are already normalised [0,1].
        return result.landmarks()[0].flatMap { lm ->
            listOf(lm.x().toDouble(), lm.y().toDouble())
        }
    }

    fun close() = handLandmarker.close()

    // YUV_420_888 planes → NV21 → JPEG → Bitmap (handles any row/pixel stride).
    private fun yuv420ToBitmap(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
    ): Bitmap {
        val frameSize = width * height
        val nv21 = ByteArray(frameSize + (width / 2) * (height / 2) * 2)

        // Copy Y plane row by row (strip any row-stride padding).
        for (row in 0 until height) {
            System.arraycopy(yBytes, row * yRowStride, nv21, row * width, width)
        }

        // Build NV21 interleaved UV (V then U for each chroma sample).
        var dst = frameSize
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val idx = row * uvRowStride + col * uvPixelStride
                if (dst + 1 < nv21.size && idx < vBytes.size && idx < uBytes.size) {
                    nv21[dst++] = vBytes[idx]
                    nv21[dst++] = uBytes[idx]
                }
            }
        }

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, out)
        val jpeg = out.toByteArray()
        return BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
    }
}
