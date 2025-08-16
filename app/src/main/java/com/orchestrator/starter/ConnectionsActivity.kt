package com.orchestrator.starter

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import okhttp3.OkHttpClient
import okhttp3.Request

class ConnectionsActivity : AppCompatActivity() {
    private val http = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_connections)

        val etWorker     = findViewById<EditText>(R.id.etWorker)
        val etOpenAI     = findViewById<EditText>(R.id.etOpenAI)
        val etOpenAIUrl  = findViewById<EditText>(R.id.etOpenAIUrl)
        val etGrok       = findViewById<EditText>(R.id.etGrok)
        val etGrokUrl    = findViewById<EditText>(R.id.etGrokUrl)
        val etGemini     = findViewById<EditText>(R.id.etGemini)
        val etGeminiUrl  = findViewById<EditText>(R.id.etGeminiUrl)
        val btnTest      = findViewById<Button>(R.id.btnTest)
        val btnSave      = findViewById<Button>(R.id.btnSave)

        val sp = getSharedPreferences("conn", MODE_PRIVATE)

        etWorker.setText(sp.getString("worker", "https://example.workers.dev"))
        etOpenAI.setText(sp.getString("openai_key", ""))
        etOpenAIUrl.setText(sp.getString("openai_url", "https://api.openai.com/v1"))
        etGrok.setText(sp.getString("grok_key", ""))
        etGrokUrl.setText(sp.getString("grok_url", "https://api.x.ai/v1"))
        etGemini.setText(sp.getString("gemini_key", ""))
        etGeminiUrl.setText(sp.getString("gemini_url", "https://generativelanguage.googleapis.com"))

        btnTest.setOnClickListener {
            val worker = (etWorker.text?.toString() ?: "").removeSuffix("/")
            if (worker.isEmpty()) {
                toast("ჩაწერე Worker URL")
                return@setOnClickListener
            }
            val req = Request.Builder().url("$worker/ping").get().build()
            http.newCall(req).enqueue(object : okhttp3.Callback {
                override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
                    runOnUiThread { toast("ვერ დაუკავშირდა: ${e.message}") }
                }
                override fun onResponse(call: okhttp3.Call, resp: okhttp3.Response) {
                    runOnUiThread {
                        toast(if (resp.isSuccessful) "OK" else "HTTP ${resp.code}")
                    }
                }
            })
        }

        btnSave.setOnClickListener {
            sp.edit()
                .putString("worker", etWorker.text?.toString()?.trim())
                .putString("openai_key", etOpenAI.text?.toString()?.trim())
                .putString("openai_url", etOpenAIUrl.text?.toString()?.trim())
                .putString("grok_key", etGrok.text?.toString()?.trim())
                .putString("grok_url", etGrokUrl.text?.toString()?.trim())
                .putString("gemini_key", etGemini.text?.toString()?.trim())
                .putString("gemini_url", etGeminiUrl.text?.toString()?.trim())
                .apply()
            toast("შენახულია")
            finish()
        }
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
