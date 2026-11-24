package com.honda.telemetry.cl250

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/**
 * Routes the phone's audio to the rider's Bluetooth intercom (an HFP headset)
 * for Usta's voice (D-121 item 5). No dependency beyond the framework.
 *
 * API 31+: AudioManager.setCommunicationDevice(SCO device) with
 * MODE_IN_COMMUNICATION. Older: startBluetoothSco() and a wait for
 * SCO_AUDIO_STATE_CONNECTED with a timeout. [release] undoes both and restores
 * the audio mode. An HFP session pauses the intercom's group talk like a call.
 *
 * Speech while routed uses the framework TextToSpeech with
 * USAGE_VOICE_COMMUNICATION: flutter_tts cannot set these attributes, and a
 * media-usage stream would not follow the SCO route.
 *
 * Every public method must be called on the main thread; every callback runs
 * on the main thread.
 */
class IntercomAudio(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val main = Handler(Looper.getMainLooper())

    private var routed = false
    private var previousMode = AudioManager.MODE_NORMAL
    private var scoReceiver: BroadcastReceiver? = null
    private var scoTimeout: Runnable? = null

    private var tts: TextToSpeech? = null
    private var speakCallback: ((Boolean) -> Unit)? = null

    private fun hasBluetoothPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.checkPermission(
                Manifest.permission.BLUETOOTH_CONNECT,
                Process.myPid(),
                Process.myUid()
            ) == PackageManager.PERMISSION_GRANTED

    private fun scoDevice(): AudioDeviceInfo? {
        if (!hasBluetoothPermission()) return null
        return try {
            val devices: List<AudioDeviceInfo> =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    audio.availableCommunicationDevices
                } else {
                    audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
                }
            devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
        } catch (e: SecurityException) {
            null
        }
    }

    /** A Bluetooth headset is connected (HFP profile or an SCO device). */
    fun headsetConnected(): Boolean {
        if (!hasBluetoothPermission()) return false
        if (scoDevice() != null) return true
        return try {
            val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            manager?.adapter?.getProfileConnectionState(BluetoothProfile.HEADSET) ==
                BluetoothProfile.STATE_CONNECTED
        } catch (e: SecurityException) {
            false
        }
    }

    /** Routes audio to the headset; [done] gets false when that is not possible. */
    fun acquire(done: (Boolean) -> Unit) {
        if (routed) {
            done(true)
            return
        }
        if (!headsetConnected()) {
            done(false)
            return
        }
        previousMode = audio.mode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val device = scoDevice()
            if (device == null) {
                done(false)
                return
            }
            audio.mode = AudioManager.MODE_IN_COMMUNICATION
            if (audio.setCommunicationDevice(device)) {
                routed = true
                done(true)
            } else {
                audio.mode = previousMode
                done(false)
            }
        } else {
            acquireLegacySco(done)
        }
    }

    @Suppress("DEPRECATION")
    private fun acquireLegacySco(done: (Boolean) -> Unit) {
        var finished = false
        fun finish(ok: Boolean) {
            if (finished) return
            finished = true
            scoTimeout?.let { main.removeCallbacks(it) }
            scoTimeout = null
            if (ok) {
                routed = true
            } else {
                unregisterScoReceiver()
                audio.stopBluetoothSco()
                audio.isBluetoothScoOn = false
                audio.mode = previousMode
            }
            done(ok)
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                val state = intent?.getIntExtra(
                    AudioManager.EXTRA_SCO_AUDIO_STATE,
                    AudioManager.SCO_AUDIO_STATE_ERROR
                )
                // The broadcast is sticky: DISCONNECTED may be the stale state
                // from before startBluetoothSco(), so only CONNECTED decides
                // early; the timeout covers the rest.
                if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) finish(true)
                if (state == AudioManager.SCO_AUDIO_STATE_ERROR) finish(false)
            }
        }
        scoReceiver = receiver
        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        audio.startBluetoothSco()
        audio.isBluetoothScoOn = true
        val timeout = Runnable { finish(false) }
        scoTimeout = timeout
        main.postDelayed(timeout, SCO_TIMEOUT_MS)
    }

    private fun unregisterScoReceiver() {
        scoReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: IllegalArgumentException) {
                // Not registered any more.
            }
        }
        scoReceiver = null
    }

    /** Gives the route and the audio mode back. Safe to call at any time. */
    @Suppress("DEPRECATION")
    fun release() {
        stopSpeaking()
        if (!routed && scoReceiver == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audio.clearCommunicationDevice()
        } else {
            unregisterScoReceiver()
            audio.stopBluetoothSco()
            audio.isBluetoothScoOn = false
        }
        audio.mode = previousMode
        routed = false
    }

    /** Speaks with voice-communication attributes; [done] gets whether it spoke. */
    fun speak(text: String, languageTag: String, done: (Boolean) -> Unit) {
        stopSpeaking()
        speakCallback = done
        var engine: TextToSpeech? = null
        engine = TextToSpeech(context) { status ->
            main.post {
                val current = engine
                if (current == null || tts !== current || status != TextToSpeech.SUCCESS) {
                    if (tts === current) finishSpeaking(false)
                    return@post
                }
                current.language = Locale.forLanguageTag(languageTag)
                current.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                current.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) {
                        main.post { if (tts === current) finishSpeaking(true) }
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        main.post { if (tts === current) finishSpeaking(false) }
                    }
                })
                val result = current.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), UTTERANCE_ID)
                if (result != TextToSpeech.SUCCESS) finishSpeaking(false)
            }
        }
        tts = engine
    }

    fun stopSpeaking() {
        if (tts != null) finishSpeaking(true)
    }

    private fun finishSpeaking(ok: Boolean) {
        val engine = tts
        val callback = speakCallback
        tts = null
        speakCallback = null
        engine?.let {
            it.stop()
            it.shutdown()
        }
        callback?.invoke(ok)
    }

    fun dispose() {
        release()
    }

    companion object {
        private const val SCO_TIMEOUT_MS = 3000L
        private const val UTTERANCE_ID = "usta"
    }
}
