package com.orchestrator.starter

import android.content.Intent
import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class MainActivity : AppCompatActivity() {

    private lateinit var etPrompt: EditText
    private lateinit var tOpenAI: CheckBox
    private lateinit var tGrok: CheckBox
    private lateinit var tGemini: CheckBox
    private lateinit var switchCoop: Switch
    private lateinit var etRounds: EditText
    private lateinit var btnAskAll: Button
    private lateinit var btnAskOpenAI: Button
    private lateinit var btnAskGrok: Button
    private lateinit var btnAskGemini: Button
    private lateinit var status: TextView
    private lateinit var rawOpenAI: TextView
    private lateinit var rawGrok: TextView
    private lateinit var rawGemini: TextView
    private lateinit var unified: TextView

    private val http = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        etPrompt = findViewById(R.id.etPrompt)
        tOpenAI = findViewById(R.id.tOpenAI)
        tGrok = findViewById(R.id.tGrok)
        tGemini = findViewById(R.id.tGemini)
        switchCoop = findViewById(R.id.switchCoop)
        etRounds = findViewById(R.id.etRounds)
        btnAskAll = findViewById(R.id.btnAskAll)
        btnAskOpenAI = findViewById(R.id.btnAskOpenAI)
        btnAskGrok = findViewById(R.id.btnAskGrok)
        btnAskGemini = findViewById(R.id.btnAskGemini)
        status = findViewById(R.id.status)
        rawOpenAI = findViewById(R.id.rawOpenAI)
        rawGrok = findViewById(R.id.rawGrok)
        rawGemini = findViewById(R.id.rawGemini)
        unified = findViewById(R.id.unified)

        // მალსახმობი: status-ზე გრძელი დაჭერა გახსნის Connections-ს
        status.setOnLongClickListener {
            startActivity(Intent(this, ConnectionsActivity::class.java))
            true
        }

        btnAskAll.setOnClickListener { ask(listOf("OpenAI","Grok","Gemini")) }
        btnAskOpenAI.setOnClickListener { ask(listOf("OpenAI")) }
        btnAskGrok.setOnClickListener { ask(listOf("Grok")) }
        btnAskGemini.setOnClickListener { ask(listOf("Gemini")) }
    }

    private fun ask(targets: List<String>) {
        val active = mutableListOf<String>()
        if (tOpenAI.isChecked && "OpenAI" in targets) active += "OpenAI"
        if (tGrok.isChecked && "Grok" in targets) active += "Grok"
        if (tGemini.isChecked && "Gemini" in targets) active += "Gemini"
        if (active.isEmpty()) { toast("აირჩიე მინ. ერთი პროვაიდერი"); return }

        val prompt = etPrompt.text.toString().trim()
        if (prompt.isEmpty()) { toast("ჩაწერე კითხვაც :)"); return }

        val sp = getSharedPreferences("conn", MODE_PRIVATE)
        val endpoint = sp.getString("worker", "https://example.workers.dev") ?: "https://example.workers.dev"

        val coop = switchCoop.isChecked
        val roundsText = etRounds.text.toString().trim()
        val rounds = if (roundsText.isEmpty()) 1 else (roundsText.toIntOrNull() ?: 1)

        status.text = "იგზავნება..."
        rawOpenAI.text = "OpenAI: —"
        rawGrok.text   = "Grok: —"
        rawGemini.text = "Gemini: —"
        unified.text   = "მოლოდინი…"

        val bodyJson = JSONObject().apply {
            put("prompt", prompt)
            put("providers", active)
            put("coop", coop)
            put("rounds", rounds) // აპში ულიმიტოა — რაც ჩაწერე, ის წავა
        }

        val media = "application/json; charset=utf-8".toMediaType()
        val req = Request.Builder()
            .url("${endpoint.removeSuffix("/")}/ask")
            .post(bodyJson.toString().toRequestBody(media))
            .build()

        http.newCall(req).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
                runOnUiThread {
                    status.text = "შეცდომა: ${e.message}"
                    toast("ვერ გაიგზავნა")
                }
            }

            override fun onResponse(call: okhttp3.Call, resp: okhttp3.Response) {
                resp.use {
                    val txt = it.body?.string().orEmpty()
                    runOnUiThread {
                        if (!it.isSuccessful) {
                            status.text = "HTTP ${it.code}"
                            toast("სერვერის შეცდომა")
                            unified.text = txt
                            return@runOnUiThread
                        }
                        status.text = "მზადაა"
                        val r = try { JSONObject(txt) } catch (_: Exception) { null }
                        if (r == null) {
                            unified.text = txt
                        } else {
                            rawOpenAI.text = "OpenAI: " + (r.opt("openai")?.toString() ?: "—")
                            rawGrok.text   = "Grok: "   + (r.opt("grok")?.toString()   ?: "—")
                            rawGemini.text = "Gemini: " + (r.opt("gemini")?.toString() ?: "—")
                            unified.text   = r.opt("unified")?.toString() ?: "—"
                        }
                    }
                }
            }
        })
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
