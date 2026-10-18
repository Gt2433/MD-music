package com.mbd.music.md_music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.content.pm.PackageManager
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.view.Display
import android.view.KeyEvent
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.mbd.music/artwork"
    private val VOLUME_CHANNEL = "com.mbd.music/volume"
    private var volumeChannel: MethodChannel? = null
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var currentSessionId: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createHighImportanceNotificationChannel()
        setHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        setHighRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            setHighRefreshRate()
        }
    }

    private fun setHighRefreshRate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val modes = currentDisplay?.supportedModes
                if (modes != null && modes.isNotEmpty()) {
                    var bestMode: Display.Mode? = null
                    var maxRate = 60.0f
                    for (mode in modes) {
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                            bestMode = mode
                        }
                    }
                    if (bestMode != null) {
                        val params = window.attributes
                        params.preferredDisplayModeId = bestMode.modeId
                        window.attributes = params
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun createHighImportanceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            val channelId = "com.mbd.music.channel.audio"
            val channelName = "MD Music Playback"
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Playback controls, status bar, and Lock screen controls"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVolume" -> {
                        try {
                            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val ratio = if (max > 0) current.toDouble() / max.toDouble() else 0.0
                            result.success(ratio)
                        } catch (e: Exception) {
                            result.success(1.0)
                        }
                    }
                    "setVolume" -> {
                        try {
                            val vol = call.argument<Double>("volume") ?: 1.0
                            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val target = if (vol <= 0.001) 0 else ((vol * max).toInt()).coerceAtLeast(1).coerceAtMost(max)
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                action = "android.settings.APP_NOTIFICATION_SETTINGS"
                                putExtra("app_package", packageName)
                                putExtra("app_uid", applicationInfo.uid)
                            }
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "enableHighRefreshRate" -> {
                    setHighRefreshRate()
                    result.success(true)
                }
                "getEmbeddedArtwork" -> {
                    val path = call.argument<String>("path")
                    if (path != null && File(path).exists()) {
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            val art = retriever.embeddedPicture
                            try {
                                retriever.release()
                            } catch (ignored: Exception) {}
                            result.success(art)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                "setAsRingtone" -> {
                    val path = call.argument<String>("path")
                    if (path != null && (path.startsWith("content://") || File(path).exists())) {
                        setRingtone(path, result)
                    } else {
                        result.error("FILE_NOT_FOUND", "File not found: $path", null)
                    }
                }
                "trimAudio" -> {
                    val src = call.argument<String>("src")
                    val dst = call.argument<String>("dst")
                    val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                    val endMs = call.argument<Number>("endMs")?.toLong() ?: 0L
                    if (src != null && dst != null) {
                        Thread {
                            val ok = trimAudioFile(src, dst, startMs, endMs)
                            runOnUiThread {
                                result.success(ok)
                            }
                        }.start()
                    } else {
                        result.success(false)
                    }
                }
                "extractWaveform" -> {
                    val path = call.argument<String>("path")
                    val samples = call.argument<Int>("samples") ?: 100
                    if (path != null) {
                        Thread {
                            val waves = extractAudioWaveform(path, samples)
                            runOnUiThread {
                                result.success(waves)
                            }
                        }.start()
                    } else {
                        result.success(emptyList<Double>())
                    }
                }
                "deleteAudio" -> {
                    val path = call.argument<String>("path")
                    val id = call.argument<Number>("id")?.toLong() ?: -1L
                    if (path != null) {
                        deleteAudioFile(path, id, result)
                    } else {
                        result.success(false)
                    }
                }
                "getPackageInfo" -> {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val vName = pInfo.versionName ?: "1.0.0"
                        val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to vName,
                            "versionCode" to vCode,
                            "packageName" to packageName
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf("versionName" to "1.0.0", "versionCode" to 1L, "packageName" to packageName))
                    }
                }
                "attachEqualizer" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val bassStrength = call.argument<Int>("bassBoost") ?: 0
                    val bands = call.argument<List<Double>>("bands")
                    try {
                        if (equalizer != null && currentSessionId != sessionId) {
                            try { equalizer?.release() } catch (_: Exception) {}
                            try { bassBoost?.release() } catch (_: Exception) {}
                            equalizer = null
                            bassBoost = null
                        }
                        if (sessionId > 0 && equalizer == null) {
                            currentSessionId = sessionId
                            equalizer = Equalizer(0, sessionId)
                            bassBoost = BassBoost(0, sessionId)
                        }
                        equalizer?.enabled = enabled
                        if (bassBoost?.strengthSupported == true) {
                            bassBoost?.enabled = enabled && (bassStrength > 0)
                            bassBoost?.setStrength(bassStrength.toShort())
                        }
                        if (equalizer != null && bands != null) {
                            val minRange = equalizer?.bandLevelRange?.get(0) ?: -1200
                            val maxRange = equalizer?.bandLevelRange?.get(1) ?: 1200
                            val numBands = equalizer?.numberOfBands?.toInt() ?: 0
                            for (i in 0 until minOf(numBands, bands.size)) {
                                val mB = (bands[i] * 100).toInt().coerceIn(minRange.toInt(), maxRange.toInt()).toShort()
                                equalizer?.setBandLevel(i.toShort(), mB)
                            }
                        }
                        val numBands = equalizer?.numberOfBands?.toInt() ?: 5
                        val minDb = (equalizer?.bandLevelRange?.get(0)?.toInt() ?: -1200) / 100.0
                        val maxDb = (equalizer?.bandLevelRange?.get(1)?.toInt() ?: 1200) / 100.0
                        val freqs = mutableListOf<Int>()
                        for (i in 0 until numBands) {
                            freqs.add((equalizer?.getCenterFreq(i.toShort()) ?: 0) / 1000)
                        }
                        result.success(mapOf(
                            "supported" to true,
                            "numBands" to numBands,
                            "minDb" to minDb,
                            "maxDb" to maxDb,
                            "frequencies" to freqs,
                            "bassBoostSupported" to (bassBoost?.strengthSupported == true)
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf("supported" to false, "error" to e.localizedMessage))
                    }
                }
                "setEqualizerBands" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val bands = call.argument<List<Double>>("bands")
                    val bassStrength = call.argument<Int>("bassBoost") ?: 0
                    try {
                        equalizer?.enabled = enabled
                        if (equalizer != null && bands != null) {
                            val minRange = equalizer?.bandLevelRange?.get(0) ?: -1200
                            val maxRange = equalizer?.bandLevelRange?.get(1) ?: 1200
                            val numBands = equalizer?.numberOfBands?.toInt() ?: 0
                            for (i in 0 until minOf(numBands, bands.size)) {
                                val mB = (bands[i] * 100).toInt().coerceIn(minRange.toInt(), maxRange.toInt()).toShort()
                                equalizer?.setBandLevel(i.toShort(), mB)
                            }
                        }
                        if (bassBoost?.strengthSupported == true) {
                            bassBoost?.enabled = enabled && (bassStrength > 0)
                            bassBoost?.setStrength(bassStrength.toShort())
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setRingtone(filePath: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.System.canWrite(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success("need_permission")
                return
            }
        }

        Thread {
            try {
                val isContentUri = filePath.startsWith("content://")
                val srcFile = if (!isContentUri) File(filePath) else null

                if (!isContentUri && (srcFile == null || !srcFile.exists())) {
                    runOnUiThread { result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null) }
                    return@Thread
                }

                val fileName = srcFile?.name ?: "ringtone_${System.currentTimeMillis()}.mp3"
                val fileTitle = srcFile?.nameWithoutExtension ?: "MD Ringtone"
                val ext = if (fileName.contains('.')) fileName.substringAfterLast('.').lowercase(Locale.ROOT) else "mp3"
                val mimeType = when (ext) {
                    "mp3" -> "audio/mpeg"
                    "m4a", "mp4" -> "audio/mp4"
                    "ogg", "opus" -> "audio/ogg"
                    "wav" -> "audio/x-wav"
                    "flac" -> "audio/flac"
                    "aac" -> "audio/aac"
                    else -> "audio/*"
                }

                var ringtoneUri: Uri? = null

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val ringtoneSubdir = Environment.DIRECTORY_RINGTONES + "/MDMusic"

                    // Try removing any previous ringtone entry with the same name in MDMusic
                    try {
                        contentResolver.delete(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                            "${MediaStore.Audio.Media.DISPLAY_NAME} = ?",
                            arrayOf(fileName)
                        )
                    } catch (ignored: Exception) {}

                    val values = ContentValues().apply {
                        put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
                        put(MediaStore.Audio.Media.TITLE, fileTitle)
                        put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                        put(MediaStore.Audio.Media.IS_RINGTONE, 1)
                        put(MediaStore.Audio.Media.IS_NOTIFICATION, 0)
                        put(MediaStore.Audio.Media.IS_ALARM, 0)
                        put(MediaStore.Audio.Media.IS_MUSIC, 0)
                        put(MediaStore.Audio.Media.RELATIVE_PATH, ringtoneSubdir)
                        put(MediaStore.Audio.Media.IS_PENDING, 1)
                    }

                    val insertedUri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                    if (insertedUri != null) {
                        val inStream: InputStream? = if (isContentUri) {
                            contentResolver.openInputStream(Uri.parse(filePath))
                        } else {
                            FileInputStream(srcFile!!)
                        }

                        val outStream: OutputStream? = contentResolver.openOutputStream(insertedUri, "w")
                        if (inStream != null && outStream != null) {
                            inStream.use { input ->
                                outStream.use { output ->
                                    input.copyTo(output)
                                }
                            }
                            values.clear()
                            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
                            contentResolver.update(insertedUri, values, null, null)
                            ringtoneUri = insertedUri
                        }
                    }
                }

                // Fallback for Android 9 or if MediaStore insertion didn't produce a URI
                if (ringtoneUri == null) {
                    val ringtonesDir = File(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RINGTONES),
                        "MDMusic"
                    )
                    if (!ringtonesDir.exists()) ringtonesDir.mkdirs()
                    val destFile = File(ringtonesDir, fileName)

                    if (!isContentUri && srcFile != null && srcFile.absolutePath == destFile.absolutePath) {
                        // Already in target location
                    } else {
                        val inStream: InputStream? = if (isContentUri) {
                            contentResolver.openInputStream(Uri.parse(filePath))
                        } else {
                            FileInputStream(srcFile!!)
                        }
                        val outStream = FileOutputStream(destFile)
                        inStream?.use { input ->
                            outStream.use { output ->
                                input.copyTo(output)
                            }
                        }
                    }

                    val latch = CountDownLatch(1)
                    var scannedUri: Uri? = null
                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(destFile.absolutePath),
                        arrayOf(mimeType)
                    ) { _, uri ->
                        scannedUri = uri
                        latch.countDown()
                    }
                    latch.await(3, TimeUnit.SECONDS)
                    ringtoneUri = scannedUri ?: Uri.fromFile(destFile)
                }

                if (ringtoneUri != null) {
                    // 1. Standard Android RingtoneManager
                    RingtoneManager.setActualDefaultRingtoneUri(
                        applicationContext,
                        RingtoneManager.TYPE_RINGTONE,
                        ringtoneUri
                    )

                    // 2. Dual-SIM / Xiaomi / HyperOS / Samsung system settings keys
                    val uriStr = ringtoneUri.toString()
                    val keys = arrayOf(
                        Settings.System.RINGTONE,
                        "ringtone",
                        "ringtone2",
                        "ringtone_sound",
                        "ringtone_sound_slot_1",
                        "ringtone_sound_slot_2",
                        "key_ringtone_sound",
                        "key_ringtone_sound_2"
                    )
                    for (k in keys) {
                        try {
                            Settings.System.putString(contentResolver, k, uriStr)
                        } catch (ignored: Exception) {}
                    }

                    runOnUiThread {
                        result.success("success")
                    }
                } else {
                    runOnUiThread {
                        result.success("error: Could not create ringtone URI")
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.success("error: ${e.message}")
                }
            }
        }.start()
    }

    private fun trimAudioFile(srcPath: String, dstPath: String, startMs: Long, endMs: Long): Boolean {
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        try {
            extractor = MediaExtractor()
            if (srcPath.startsWith("content://")) {
                extractor.setDataSource(applicationContext, Uri.parse(srcPath), null)
            } else {
                extractor.setDataSource(srcPath)
            }
            val trackCount = extractor.trackCount
            var audioTrackIndex = -1
            var format: MediaFormat? = null

            for (i in 0 until trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }

            if (audioTrackIndex == -1 || format == null) return false
            extractor.selectTrack(audioTrackIndex)

            val startUs = startMs * 1000L
            val endUs = endMs * 1000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            val outFile = File(dstPath)
            if (outFile.exists()) outFile.delete()
            outFile.parentFile?.mkdirs()

            val outputFormat = if (srcPath.endsWith(".m4a", true) || srcPath.endsWith(".mp4", true)) {
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            } else {
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            }

            muxer = MediaMuxer(dstPath, outputFormat)
            val muxerTrackIndex = muxer.addTrack(format)
            muxer.start()

            val maxBufferSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                1024 * 1024
            }
            val buffer = ByteBuffer.allocate(maxBufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break

                val sampleTime = extractor.sampleTime
                if (sampleTime > endUs) break

                if (sampleTime >= startUs) {
                    bufferInfo.presentationTimeUs = sampleTime - startUs
                    bufferInfo.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                }
                extractor.advance()
            }

            muxer.stop()
            muxer.release()
            extractor.release()
            return true
        } catch (e: Exception) {
            try { muxer?.release() } catch (_: Exception) {}
            try { extractor?.release() } catch (_: Exception) {}
            return false
        }
    }

    private fun extractAudioWaveform(pathOrUri: String, samplesCount: Int = 100): List<Double> {
        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null
        val bucketCount = if (samplesCount in 20..300) samplesCount else 100
        val bucketAmplitudes = DoubleArray(bucketCount)

        try {
            extractor = MediaExtractor()
            if (pathOrUri.startsWith("content://")) {
                extractor.setDataSource(applicationContext, Uri.parse(pathOrUri), null)
            } else {
                val file = File(pathOrUri)
                if (!file.exists()) return emptyList()
                extractor.setDataSource(file.absolutePath)
            }

            var audioTrackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }

            if (audioTrackIndex == -1 || format == null) return emptyList()
            extractor.selectTrack(audioTrackIndex)

            val mime = format.getString(MediaFormat.KEY_MIME) ?: return emptyList()
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            var isEOS = false
            val startTimeMs = System.currentTimeMillis()
            val maxDurationMs = 2500L // 2.5 seconds safety cap

            while (!isEOS && (System.currentTimeMillis() - startTimeMs) < maxDurationMs) {
                val inIndex = codec.dequeueInputBuffer(4000L)
                if (inIndex >= 0) {
                    val inBuffer = codec.getInputBuffer(inIndex)
                    if (inBuffer != null) {
                        val sampleSize = extractor.readSampleData(inBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            isEOS = true
                        } else {
                            val sampleTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(inIndex, 0, sampleSize, sampleTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }

                var outIndex = codec.dequeueOutputBuffer(bufferInfo, 4000L)
                while (outIndex >= 0) {
                    val outBuffer = codec.getOutputBuffer(outIndex)
                    if (outBuffer != null && bufferInfo.size > 0) {
                        val pcmBytes = ByteArray(bufferInfo.size)
                        outBuffer.position(bufferInfo.offset)
                        outBuffer.get(pcmBytes)

                        val timeUs = bufferInfo.presentationTimeUs
                        val bucketIdx = if (durationUs > 0) {
                            ((timeUs.toDouble() / durationUs.toDouble()) * bucketCount).toInt().coerceIn(0, bucketCount - 1)
                        } else {
                            0
                        }

                        var sumSquares = 0.0
                        var count = 0
                        var i = 0
                        while (i < pcmBytes.size - 1) {
                            val sample = ((pcmBytes[i + 1].toInt() shl 8) or (pcmBytes[i].toInt() and 0xFF)).toShort()
                            val norm = sample.toDouble() / 32768.0
                            sumSquares += norm * norm
                            count++
                            i += 4 // Sub-sample for maximum speed
                        }

                        if (count > 0) {
                            val rms = Math.sqrt(sumSquares / count)
                            if (rms > bucketAmplitudes[bucketIdx]) {
                                bucketAmplitudes[bucketIdx] = rms
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isEOS = true
                        break
                    }
                    outIndex = codec.dequeueOutputBuffer(bufferInfo, 0L)
                }
            }
        } catch (_: Exception) {
            // Handled safely
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            try { codec?.release() } catch (_: Exception) {}
            try { extractor?.release() } catch (_: Exception) {}
        }

        var maxAmp = 0.0
        for (a in bucketAmplitudes) {
            if (a > maxAmp) maxAmp = a
        }

        val result = ArrayList<Double>(bucketCount)
        for (i in 0 until bucketCount) {
            val v = if (maxAmp > 0.0001) (bucketAmplitudes[i] / maxAmp).coerceIn(0.08, 1.0) else 0.2
            result.add(v)
        }
        return result
    }

    private var pendingDeleteResult: MethodChannel.Result? = null
    private val REQUEST_CODE_DELETE = 4041

    private fun deleteAudioFile(filePath: String, songId: Long, result: MethodChannel.Result) {
        val file = File(filePath)

        // 1. Direct file deletion (works if file created by app or MANAGE_EXTERNAL_STORAGE is granted)
        try {
            if (file.exists() && file.delete()) {
                try {
                    contentResolver.delete(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                        "${MediaStore.Audio.Media._ID} = ?",
                        arrayOf(songId.toString())
                    )
                } catch (_: Exception) {}
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(filePath),
                    null,
                    null
                )
                result.success(true)
                return
            }
        } catch (_: Exception) {}

        // 2. ContentResolver delete via MediaStore URI
        try {
            val contentUri = if (songId > 0) {
                ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
            } else {
                MediaStore.Audio.Media.getContentUriForPath(filePath)
            }

            if (contentUri != null) {
                val rows = contentResolver.delete(contentUri, null, null)
                if (rows > 0) {
                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(filePath),
                        null,
                        null
                    )
                    result.success(true)
                    return
                }
            }
        } catch (e: Exception) {
            // Android 10 RecoverableSecurityException
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && e is android.app.RecoverableSecurityException) {
                pendingDeleteResult = result
                try {
                    startIntentSenderForResult(
                        e.userAction.actionIntent.intentSender,
                        REQUEST_CODE_DELETE,
                        null, 0, 0, 0
                    )
                    return
                } catch (_: Exception) {}
            }
        }

        // 3. Android 11+ (API 30+) MediaStore.createDeleteRequest for Scoped Storage files
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && songId > 0) {
            try {
                val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
                val pi = MediaStore.createDeleteRequest(contentResolver, listOf(contentUri))
                pendingDeleteResult = result
                startIntentSenderForResult(pi.intentSender, REQUEST_CODE_DELETE, null, 0, 0, 0)
                return
            } catch (_: Exception) {}
        }

        // Check if file no longer exists
        if (!file.exists()) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_DELETE) {
            val success = (resultCode == RESULT_OK)
            pendingDeleteResult?.success(success)
            pendingDeleteResult = null
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val repeatCount = event?.repeatCount ?: 0
            val step = if (repeatCount > 0) 0.03 else 0.01
            runOnUiThread {
                volumeChannel?.invokeMethod("adjustVolume", mapOf("direction" to "down", "step" to step, "isRepeat" to (repeatCount > 0)))
            }
            return true
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            val repeatCount = event?.repeatCount ?: 0
            val step = if (repeatCount > 0) 0.03 else 0.01
            runOnUiThread {
                volumeChannel?.invokeMethod("adjustVolume", mapOf("direction" to "up", "step" to step, "isRepeat" to (repeatCount > 0)))
            }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }
}
