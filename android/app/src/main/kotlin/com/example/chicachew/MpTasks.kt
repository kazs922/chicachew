// android/app/src/main/kotlin/com/example/chicachew/MpTasks.kt
package com.example.chicachew

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

class MpTasks(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val method = MethodChannel(messenger, "mp_tasks")
    private val events = EventChannel(messenger, "mp_tasks/events")
    private var sink: EventChannel.EventSink? = null

    private var face: FaceLandmarker? = null
    private var hand: HandLandmarker? = null

    // main-thread post (EventSink는 UI 스레드에서만 호출해야 함)
    private val mainHandler = Handler(Looper.getMainLooper())
    private fun postEvent(map: Map<String, Any?>) {
        mainHandler.post { sink?.success(map) }
    }
    private fun postError(code: String, msg: String) {
        mainHandler.post { sink?.error(code, msg, null) }
    }

    // Flutter asset 키
    private val loader = FlutterInjector.instance().flutterLoader()
    private val faceModelKey = loader.getLookupKeyForAsset("assets/mp/face_landmarker.task")
    private val handModelKey = loader.getLookupKeyForAsset("assets/mp/hand_landmarker.task")

    init {
        method.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val useFace = call.argument<Boolean>("face") == true
                val useHands = call.argument<Boolean>("hands") == true
                start(useFace, useHands)
                result.success(true)
            }
            // Flutter(Camera) → NV21/기타 단일 버퍼 경로
            "processBytes" -> {
                try {
                    processBytes(call)
                    result.success(null)
                } catch (t: Throwable) {
                    postError("mp_process", t.toString())
                    result.error("mp_process", t.toString(), null)
                }
            }
            // Flutter(Camera) → YUV420 3-plane 경로(호환)
            "processYuv420Planes" -> {
                try {
                    processYuv420Planes(call)
                    result.success(null)
                } catch (t: Throwable) {
                    postError("mp_process", t.toString())
                    result.error("mp_process", t.toString(), null)
                }
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    private fun start(useFace: Boolean, useHands: Boolean) {
        stop()

        if (useFace) {
            val base = BaseOptions.builder().setModelAssetPath(faceModelKey).build()
            val opts = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(base)
                .setNumFaces(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { res: FaceLandmarkerResult, _: MPImage ->
                    val faces = res.faceLandmarks()
                    val first = if (faces.isNotEmpty()) toTriples(faces[0]) else emptyList()
                    postEvent(mapOf("type" to "face", "landmarks" to first))
                }
                .setErrorListener { e -> postError("mp_face", e?.toString() ?: "unknown") }
                .build()
            face = FaceLandmarker.createFromOptions(context, opts)
        }

        if (useHands) {
            val base = BaseOptions.builder().setModelAssetPath(handModelKey).build()
            val opts = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(base)
                .setNumHands(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { res: HandLandmarkerResult, _: MPImage ->
                    val lmsList = res.landmarks()
                    val handednesses = res.handednesses()
                    val handed = if (handednesses.isNotEmpty() && handednesses[0].isNotEmpty())
                        handednesses[0][0].categoryName() else "Unknown"
                    val first = if (lmsList.isNotEmpty()) toTriples(lmsList[0]) else emptyList()
                    postEvent(mapOf(
                        "type" to "hand",
                        "handedness" to handed,
                        "landmarks" to first
                    ))
                }
                .setErrorListener { e -> postError("mp_hand", e?.toString() ?: "unknown") }
                .build()
            hand = HandLandmarker.createFromOptions(context, opts)
        }
    }

    private fun stop() {
        try { face?.close() } catch (_: Throwable) {}
        try { hand?.close() } catch (_: Throwable) {}
        face = null
        hand = null
    }

    /**
     * (A) Flutter에서 NV21 등 단일 버퍼로 온 프레임 처리
     * Method: "processBytes"
     * args: bytes, width, height, rotationDegrees, timestampMs, pixelFormat("nv21" 권장)
     */
    private fun processBytes(call: MethodCall) {
        val bytes = call.argument<ByteArray>("bytes") ?: return
        val width = call.argument<Int>("width") ?: return
        val height = call.argument<Int>("height") ?: return
        val rotationDeg = call.argument<Int>("rotationDegrees")
            ?: call.argument<Int>("rotationDeg") ?: 0
        val timestampMs = (call.argument<Number>("timestampMs") ?: 0L).toLong()
        val pixelFormat = (call.argument<String>("pixelFormat") ?: "nv21").lowercase()

        val argb: IntArray = when (pixelFormat) {
            "nv21" -> nv21ToArgb(bytes, width, height)
            else -> throw IllegalArgumentException("Unsupported pixelFormat=$pixelFormat")
        }

        var bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bmp.setPixels(argb, 0, width, 0, 0, width, height)

        if (rotationDeg != 0) {
            val m = Matrix().apply { postRotate(rotationDeg.toFloat()) }
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }

        val mpImage = BitmapImageBuilder(bmp).build()
        face?.detectAsync(mpImage, timestampMs)
        hand?.detectAsync(mpImage, timestampMs)
    }

    /**
     * (B) Flutter(CameraX)에서 보내는 YUV420 3-plane 처리 (기존 호환)
     */
    private fun processYuv420Planes(call: MethodCall) {
        val y = call.argument<ByteArray>("y") ?: return
        val u = call.argument<ByteArray>("u") ?: return
        val v = call.argument<ByteArray>("v") ?: return
        val width = call.argument<Int>("width") ?: return
        val height = call.argument<Int>("height") ?: return
        val yRowStride = call.argument<Int>("yRowStride") ?: return
        val uRowStride = call.argument<Int>("uRowStride") ?: return
        val vRowStride = call.argument<Int>("vRowStride") ?: return
        val uPixStride = call.argument<Int>("uPixelStride") ?: 1
        val vPixStride = call.argument<Int>("vPixelStride") ?: 1
        val rotationDeg = call.argument<Int>("rotationDeg") ?: 0
        val timestampMs = (call.argument<Number>("timestampMs") ?: 0L).toLong()

        val argb = IntArray(width * height)
        for (j in 0 until height) {
            val pY = yRowStride * j
            val pU = uRowStride * (j / 2)
            val pV = vRowStride * (j / 2)
            for (i in 0 until width) {
                val Y = (y[pY + i].toInt() and 0xFF)
                val U = (u[pU + (i / 2) * uPixStride].toInt() and 0xFF)
                val V = (v[pV + (i / 2) * vPixStride].toInt() and 0xFF)

                var c = Y - 16; if (c < 0) c = 0
                val d = U - 128
                val e = V - 128

                var r = (1.164f * c + 1.596f * e).toInt()
                var g = (1.164f * c - 0.392f * d - 0.813f * e).toInt()
                var b = (1.164f * c + 2.017f * d).toInt()

                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255

                argb[j * width + i] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }

        var bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bmp.setPixels(argb, 0, width, 0, 0, width, height)

        if (rotationDeg != 0) {
            val m = Matrix().apply { postRotate(rotationDeg.toFloat()) }
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }

        val mpImage = BitmapImageBuilder(bmp).build()
        face?.detectAsync(mpImage, timestampMs)
        hand?.detectAsync(mpImage, timestampMs)
    }

    // NV21(VU interleaved) → ARGB8888
    private fun nv21ToArgb(nv21: ByteArray, width: Int, height: Int): IntArray {
        val frameSize = width * height
        val out = IntArray(frameSize)
        var yp = 0
        for (j in 0 until height) {
            val uvRow = frameSize + (j shr 1) * width
            for (i in 0 until width) {
                val y = (nv21[yp].toInt() and 0xFF) - 16
                val c = if (y < 0) 0 else y
                val uvIndex = uvRow + (i and -2) // VU 페어 시작 위치
                val v = (nv21[uvIndex].toInt() and 0xFF) - 128
                val u = (nv21[uvIndex + 1].toInt() and 0xFF) - 128

                var r = (1.164f * c + 1.596f * v).toInt()
                var g = (1.164f * c - 0.813f * v - 0.392f * u).toInt()
                var b = (1.164f * c + 2.017f * u).toInt()

                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255

                out[yp] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
                yp++
            }
        }
        return out
    }

    private fun toTriples(list: List<NormalizedLandmark>): List<List<Double>> =
        list.map { lm -> listOf(lm.x().toDouble(), lm.y().toDouble(), lm.z().toDouble()) }
}
