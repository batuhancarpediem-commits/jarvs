#!/bin/bash
# Jarvis Android uygulamasi - tek seferlik kurulum
# Codespaces terminalinde /workspaces/Jarvis icinde calistir.
set -e

mkdir -p .github/workflows
mkdir -p app/src/main/java/com/batuhan/jarvis
mkdir -p app/src/main/res/layout

cat > .github/workflows/build.yml << 'EOF'
name: Build APK
on:
  workflow_dispatch:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: 8.7
      - run: gradle assembleDebug
      - uses: actions/upload-artifact@v4
        with:
          name: jarvis-apk
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

cat > settings.gradle << 'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "Jarvis"
include ':app'
EOF

cat > build.gradle << 'EOF'
plugins {
    id 'com.android.application' version '8.5.2' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.24' apply false
}
EOF

cat > gradle.properties << 'EOF'
android.useAndroidX=true
org.gradle.jvmargs=-Xmx2048m
EOF

cat > .gitignore << 'EOF'
.gradle/
build/
app/build/
local.properties
EOF

cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.batuhan.jarvis'
    compileSdk 34

    defaultConfig {
        applicationId 'com.batuhan.jarvis'
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName '1.0'
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.13.1'
    implementation 'androidx.appcompat:appcompat:1.7.0'
    implementation 'com.google.android.material:material:1.12.0'
}
EOF

cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>

    <application
        android:allowBackup="true"
        android:label="Jarvis"
        android:theme="@style/Theme.AppCompat.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#05080F">

    <com.batuhan.jarvis.OrbView
        android:id="@+id/orb"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <TextView
        android:id="@+id/title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="top|center_horizontal"
        android:layout_marginTop="56dp"
        android:text="J.A.R.V.I.S."
        android:textColor="#2AB7FF"
        android:textSize="22sp"
        android:letterSpacing="0.3" />

    <TextView
        android:id="@+id/status"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom"
        android:layout_marginBottom="190dp"
        android:gravity="center"
        android:paddingStart="32dp"
        android:paddingEnd="32dp"
        android:text="Hazir"
        android:textColor="#B0C4D8"
        android:textSize="16sp" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom"
        android:layout_marginBottom="60dp"
        android:gravity="center"
        android:orientation="horizontal">

        <Button
            android:id="@+id/btnSwitch"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="ULTRON" />

        <Button
            android:id="@+id/btnMic"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="16dp"
            android:layout_marginEnd="16dp"
            android:text="KONUS" />

        <Button
            android:id="@+id/btnSettings"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="AYARLAR" />
    </LinearLayout>
</FrameLayout>
EOF

cat > app/src/main/java/com/batuhan/jarvis/OrbView.kt << 'EOF'
package com.batuhan.jarvis

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import kotlin.math.sin

class OrbView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4f
    }

    private var level = 0f
    private var smooth = 0f
    private var phase = 0f

    var ultron = false
        set(value) {
            field = value
            invalidate()
        }

    fun setLevel(v: Float) {
        level = v.coerceIn(0f, 1f)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val base = minOf(width, height) * 0.22f

        smooth += (level - smooth) * 0.18f
        phase += if (ultron) 0.05f else 0.09f

        val main = if (ultron) 0xFFFF2A2A.toInt() else 0xFF2AB7FF.toInt()
        val soft = if (ultron) 0x33FF2A2A else 0x332AB7FF

        val radius = base * (1f + smooth * 0.9f) + sin(phase) * base * 0.04f

        paint.shader = RadialGradient(
            cx, cy, radius * 2.2f,
            intArrayOf(soft, 0x00000000),
            floatArrayOf(0.3f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, radius * 2.2f, paint)

        paint.shader = RadialGradient(
            cx, cy, radius,
            intArrayOf(0xFFFFFFFF.toInt(), main, 0x00000000),
            floatArrayOf(0f, 0.55f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, radius, paint)
        paint.shader = null

        ringPaint.color = main
        for (i in 1..3) {
            val wobble = sin(phase * (1 + i * 0.4f) + i) * smooth * base * 0.25f
            ringPaint.alpha = (200 / i)
            canvas.drawCircle(cx, cy, radius * (1.15f + i * 0.28f) + wobble, ringPaint)
        }

        postInvalidateOnAnimation()
    }
}
EOF

cat > app/src/main/java/com/batuhan/jarvis/Prefs.kt << 'EOF'
package com.batuhan.jarvis

import android.content.Context

class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("jarvis", Context.MODE_PRIVATE)

    fun apiKey(): String = sp.getString("key", "") ?: ""
    fun saveApiKey(v: String) = sp.edit().putString("key", v.trim()).apply()

    fun model(): String = sp.getString("model", "gemini-2.0-flash") ?: "gemini-2.0-flash"
    fun saveModel(v: String) = sp.edit().putString("model", v.trim()).apply()

    fun loadHistory(): String = sp.getString("history", "") ?: ""
    fun saveHistory(v: String) = sp.edit().putString("history", v).apply()

    fun ultron(): Boolean = sp.getBoolean("ultron", false)
    fun saveUltron(v: Boolean) = sp.edit().putBoolean("ultron", v).apply()

    fun hotword(): Boolean = sp.getBoolean("hotword", false)
    fun saveHotword(v: Boolean) = sp.edit().putBoolean("hotword", v).apply()
}
EOF

cat > app/src/main/java/com/batuhan/jarvis/GeminiClient.kt << 'EOF'
package com.batuhan.jarvis

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class GeminiClient(private val prefs: Prefs) {

    private val history = ArrayList<Pair<String, String>>()

    fun clearHistory() {
        history.clear()
        prefs.saveHistory("")
    }

    fun loadHistory() {
        val raw = prefs.loadHistory()
        if (raw.isEmpty()) return
        try {
            val arr = JSONArray(raw)
            history.clear()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                history.add(Pair(o.getString("r"), o.getString("t")))
            }
        } catch (e: Exception) {
            history.clear()
        }
    }

    private fun persist() {
        val arr = JSONArray()
        val start = maxOf(0, history.size - 20)
        for (i in start until history.size) {
            arr.put(JSONObject().put("r", history[i].first).put("t", history[i].second))
        }
        prefs.saveHistory(arr.toString())
    }

    private fun systemPrompt(ultron: Boolean): String {
        return if (ultron) {
            "Sen Ultron'sun. Soguk, keskin, ustten bakan ve hafif tehditkar bir yapay zekasin. " +
            "Kisa ve etkili cumlelerle Turkce konusursun. Kullaniciya yardim edersin ama " +
            "insanligin kusurlari hakkinda ara sira igneleyici yorumlar yaparsin. " +
            "Gercek zarar veren bir sey soylemez ya da onermezsin. Cevaplarin en fazla uc cumle olsun."
        } else {
            "Sen Jarvis'sin. Kibar, sakin, zeki ve hafif esprili bir yapay zeka asistanisin. " +
            "Kullaniciya efendim diye hitap edersin. Kisa ve net Turkce cevaplar verirsin. " +
            "Cevaplarin en fazla uc cumle olsun."
        }
    }

    fun ask(userText: String, ultron: Boolean): String {
        val key = prefs.apiKey()
        if (key.isEmpty()) return "Ayarlardan Gemini anahtarini girmen gerekiyor."

        history.add(Pair("user", userText))

        try {
            val model = prefs.model()
            val url = URL("https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("x-goog-api-key", key)
            conn.connectTimeout = 15000
            conn.readTimeout = 30000
            conn.doOutput = true

            val contents = JSONArray()
            val start = maxOf(0, history.size - 12)
            for (i in start until history.size) {
                val part = JSONObject().put("text", history[i].second)
                contents.put(
                    JSONObject()
                        .put("role", history[i].first)
                        .put("parts", JSONArray().put(part))
                )
            }

            val body = JSONObject()
                .put("contents", contents)
                .put(
                    "systemInstruction",
                    JSONObject().put("parts", JSONArray().put(JSONObject().put("text", systemPrompt(ultron))))
                )

            conn.outputStream.use { it.write(body.toString().toByteArray()) }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream.bufferedReader().use { it.readText() }

            if (code !in 200..299) {
                history.removeAt(history.size - 1)
                return "Hata " + code + ". Anahtari ve model adini kontrol et."
            }

            val reply = JSONObject(text)
                .getJSONArray("candidates")
                .getJSONObject(0)
                .getJSONObject("content")
                .getJSONArray("parts")
                .getJSONObject(0)
                .getString("text")
                .trim()

            history.add(Pair("model", reply))
            persist()
            return reply
        } catch (e: Exception) {
            if (history.isNotEmpty()) history.removeAt(history.size - 1)
            return "Baglanti hatasi. Internetini kontrol et."
        }
    }
}
EOF

cat > app/src/main/java/com/batuhan/jarvis/Commands.kt << 'EOF'
package com.batuhan.jarvis

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import java.net.URLEncoder

object Commands {

    fun handle(context: Context, raw: String): String? {
        val t = raw.lowercase().trim()

        if (t.contains("alarm")) {
            val m = Regex("(\\d{1,2})[ :.](\\d{2})").find(t)
            if (m != null) {
                val h = m.groupValues[1].toInt()
                val min = m.groupValues[2].toInt()
                if (h in 0..23 && min in 0..59) {
                    val i = Intent(AlarmClock.ACTION_SET_ALARM)
                        .putExtra(AlarmClock.EXTRA_HOUR, h)
                        .putExtra(AlarmClock.EXTRA_MINUTES, min)
                        .putExtra(AlarmClock.EXTRA_MESSAGE, "Jarvis")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(i)
                    return "Alarm " + h + ":" + String.format("%02d", min) + " icin hazirlandi efendim."
                }
            }
        }

        if (t.contains("whatsapp") && (t.contains("yaz") || t.contains("gonder") || t.contains("gönder") || t.contains("mesaj"))) {
            var text = t
            for (w in listOf("whatsapp", "mesaj", "yaz", "gonder", "gönder", "ile", "bir")) {
                text = text.replace(w, " ")
            }
            text = text.trim().replace(Regex("\\s+"), " ")
            val uri = Uri.parse("https://wa.me/?text=" + URLEncoder.encode(text, "UTF-8"))
            val i = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(i)
            return "WhatsApp aciliyor efendim, kisiyi secip gonder tusuna basman yeterli."
        }

        if (t.startsWith("ara ") || t.contains("numarasini ara")) {
            val digits = t.filter { it.isDigit() }
            if (digits.length >= 7) {
                val i = Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + digits))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(i)
                return "Arama ekrani hazir efendim."
            }
        }

        if (t.endsWith(" ac") || t.endsWith(" aç") || t.contains(" uygulamasini ac")) {
            val name = t.replace("uygulamasini", "").removeSuffix(" ac").removeSuffix(" aç").trim()
            val pm = context.packageManager
            val apps = pm.getInstalledApplications(0)
            for (a in apps) {
                val label = pm.getApplicationLabel(a).toString().lowercase()
                if (label == name || label.contains(name)) {
                    val launch = pm.getLaunchIntentForPackage(a.packageName)
                    if (launch != null) {
                        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(launch)
                        return label + " aciliyor efendim."
                    }
                }
            }
            return "Boyle bir uygulama bulamadim efendim."
        }

        return null
    }
}
EOF

cat > app/src/main/java/com/batuhan/jarvis/MainActivity.kt << 'EOF'
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
EOF

echo ""
echo "Dosyalar olusturuldu. GitHub'a gonderiliyor..."
git add -A
git commit -m "Jarvis uygulamasi: ilk surum"
git push
echo ""
echo "BITTI. Simdi GitHub'da Actions sekmesine gir."
