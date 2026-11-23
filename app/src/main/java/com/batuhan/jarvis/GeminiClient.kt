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
                    .put("tools", JSONArray().put(JSONObject().put("google_search", JSONObject())))
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
