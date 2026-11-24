package com.honda.telemetry.cl250

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `vehicle_mobile/intercom_audio` channel (D-121 item 5): audio
 * routing to the rider's Bluetooth intercom and the intercom's voice-command
 * button (`android.intent.action.VOICE_COMMAND`).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var intercom: IntercomAudio? = null

    /** The app was started by the voice-command intent and Dart has not read it yet. */
    private var pendingVoiceCommand = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingVoiceCommand = isVoiceCommand(intent)
        consume(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isVoiceCommand(intent)) {
            consume(intent)
            channel?.invokeMethod("voiceCommand", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val audio = IntercomAudio(applicationContext)
        intercom = audio
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(audio.headsetConnected())
                "acquire" -> audio.acquire { ok -> result.success(ok) }
                "release" -> {
                    audio.release()
                    result.success(null)
                }
                "speak" -> {
                    val text = call.argument<String>("text")
                    val language = call.argument<String>("language") ?: "tr-TR"
                    if (text.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        audio.speak(text, language) { ok -> result.success(ok) }
                    }
                }
                "stopSpeaking" -> {
                    audio.stopSpeaking()
                    result.success(null)
                }
                "consumeVoiceCommand" -> {
                    val pending = pendingVoiceCommand
                    pendingVoiceCommand = false
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        intercom?.dispose()
        intercom = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isVoiceCommand(intent: Intent?): Boolean =
        intent?.action == Intent.ACTION_VOICE_COMMAND

    /** Clears the action so a recreated activity does not replay the command. */
    private fun consume(intent: Intent?) {
        if (isVoiceCommand(intent)) intent?.action = Intent.ACTION_MAIN
    }

    companion object {
        private const val CHANNEL = "vehicle_mobile/intercom_audio"
    }
}
