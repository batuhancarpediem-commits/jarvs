package com.batuhan.jarvis

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.text.InputType
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale
import kotlin.math.sin

class MainActivity : AppCompatActivity(), TextToSpeech.OnInitListener {

    private lateinit var orb: OrbView
    private lateinit var status: TextView
    private lateinit var titleView: TextView
    private lateinit var btnSwitch: Button
    private lateinit var btnMic: Button
    private lateinit var btnSettings: Button
    private lateinit var rootView: android.view.View

    private lateinit var prefs: Prefs
    private lateinit var gemini: GeminiClient
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var recognizer: SpeechRecognizer? = null

    private var ultron = false
    private var speaking = false
    private var listening = false
    private var hotwordOn = false
    private val ui = Handler(Looper.getMainLooper())

    private val speakAnim = object : Runnable {
        override fun run() {
            if (speaking) {
                val t = System.currentTimeMillis() / 90.0
                val v = (0.45 + 0.35 * sin(t) + 0.2 * sin(t * 2.3)).toFloat()
                orb.setLevel(v)
                ui.postDelayed(this, 60)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        orb = findViewById(R.id.orb)
        status = findViewById(R.id.status)
        titleView = findViewById(R.id.title)
        btnSwitch = findViewById(R.id.btnSwitch)
        btnMic = findViewById(R.id.btnMic)
        btnSettings = findViewById(R.id.btnSettings)
        rootView = findViewById(R.id.root)

        prefs = Prefs(this)
        gemini = GeminiClient(prefs)
        gemini.loadHistory()
        ultron = prefs.ultron()
        hotwordOn = prefs.hotword()

        tts = TextToSpeech(this, this)
        applyMode()

        btnSwitch.setOnClickListener {
            ultron = !ultron
            prefs.saveUltron(ultron)
            applyMode()
            say(if (ultron) "Ultron devrede." else "Jarvis geri dondu efendim.")
        }
        btnMic.setOnClickListener { startListening() }
        btnSettings.setOnClickListener { showSettings() }

        ensurePermission()
    }

    override fun onInit(s: Int) {
        if (s == TextToSpeech.SUCCESS) {
            tts?.language = Locale("tr", "TR")
            ttsReady = true
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {
                    ui.post { speaking = true; ui.post(speakAnim) }
                }
                override fun onDone(id: String?) {
                    ui.post {
                        speaking = false
                        orb.setLevel(0f)
                        status.text = "Hazir"
                        if (hotwordOn) ui.postDelayed({ startListening() }, 400)
                    }
                }
                @Deprecated("x")
                override fun onError(id: String?) {
                    ui.post { speaking = false; orb.setLevel(0f) }
                }
            })
            applyVoice()
        }
    }

    private fun applyVoice() {
        if (!ttsReady) return
        if (ultron) {
            tts?.setPitch(0.55f)
            tts?.setSpeechRate(0.82f)
        } else {
            tts?.setPitch(1.1f)
            tts?.setSpeechRate(1.0f)
        }
    }

    private fun applyMode() {
        val c = if (ultron) Color.parseColor("#FF2A2A") else Color.parseColor("#2AB7FF")
        orb.ultron = ultron
        titleView.text = if (ultron) "U L T R O N" else "J.A.R.V.I.S."
        titleView.setTextColor(c)
        btnSwitch.text = if (ultron) "JARVIS" else "ULTRON"
        rootView.setBackgroundColor(if (ultron) Color.parseColor("#0F0505") else Color.parseColor("#05080F"))
        applyVoice()
    }

    private fun say(text: String) {
        status.text = text
        if (!ttsReady) return
        applyVoice()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "u" + System.currentTimeMillis())
    }

    private fun ensurePermission() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
        }
    }

    private fun startListening() {
        if (listening || speaking) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ensurePermission()
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            status.text = "Bu telefonda ses tanima yok."
            return
        }
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) { listening = true; status.text = "Dinliyorum..." }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rms: Float) {
                orb.setLevel(((rms + 2f) / 12f).coerceIn(0f, 1f))
            }
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() { listening = false; orb.setLevel(0f) }
            override fun onError(e: Int) {
                listening = false
                orb.setLevel(0f)
                if (hotwordOn && e == SpeechRecognizer.ERROR_NO_MATCH) {
                    ui.postDelayed({ startListening() }, 300)
                } else if (hotwordOn && e == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    ui.postDelayed({ startListening() }, 300)
                } else {
                    status.text = "Hazir"
                }
            }
            override fun onResults(r: Bundle?) {
                listening = false
                val list = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val said = list?.firstOrNull()?.trim() ?: ""
                if (said.isNotEmpty()) handleSpeech(said) else if (hotwordOn) startListening()
            }
            override fun onPartialResults(p: Bundle?) {}
            override fun onEvent(t: Int, p: Bundle?) {}
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "tr-TR")
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
        recognizer?.startListening(i)
    }

    private fun handleSpeech(said: String) {
        var text = said
        val low = said.lowercase()

        if (hotwordOn) {
            val wake = listOf("hey jarvis", "jarvis", "hey ultron", "ultron")
            val hit = wake.firstOrNull { low.startsWith(it) }
            if (hit == null) {
                startListening()
                return
            }
            if (hit.contains("ultron") && !ultron) { ultron = true; prefs.saveUltron(true); applyMode() }
            if (hit.contains("jarvis") && ultron) { ultron = false; prefs.saveUltron(false); applyMode() }
            text = said.substring(hit.length).trim()
            if (text.isEmpty()) {
                say(if (ultron) "Dinliyorum." else "Buyurun efendim.")
                return
            }
        }

        status.text = "Dusunuyorum..."
        Thread {
            val cmd = try { Commands.handle(this, text) } catch (e: Exception) { null }
            val reply = cmd ?: gemini.ask(text, ultron)
            ui.post { say(reply) }
        }.start()
    }

    private fun showSettings() {
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.setPadding(48, 24, 48, 0)

        val keyIn = EditText(this)
        keyIn.hint = "Gemini API anahtari"
        keyIn.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        keyIn.setText(prefs.apiKey())
        box.addView(keyIn)

        val modelIn = EditText(this)
        modelIn.hint = "Model adi"
        modelIn.setText(prefs.model())
        box.addView(modelIn)

        val hot = CheckBox(this)
        hot.text = "Hey Jarvis dinleme (uygulama acikken)"
        hot.isChecked = prefs.hotword()
        box.addView(hot)

        val clear = Button(this)
        clear.text = "Konusma gecmisini sil"
        clear.setOnClickListener {
            gemini.clearHistory()
            status.text = "Gecmis silindi."
        }
        box.addView(clear)

        AlertDialog.Builder(this)
            .setTitle("Ayarlar")
            .setView(box)
            .setPositiveButton("Kaydet") { _, _ ->
                prefs.saveApiKey(keyIn.text.toString())
                prefs.saveModel(modelIn.text.toString())
                hotwordOn = hot.isChecked
                prefs.saveHotword(hotwordOn)
                if (hotwordOn) startListening()
            }
            .setNegativeButton("Iptal", null)
            .show()
    }

    override fun onDestroy() {
        recognizer?.destroy()
        tts?.shutdown()
        super.onDestroy()
    }
}
