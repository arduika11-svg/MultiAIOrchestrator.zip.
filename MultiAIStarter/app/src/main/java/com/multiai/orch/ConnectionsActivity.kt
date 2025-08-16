package com.multiai.orch

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.multiai.orch.storage.SecureStore

class ConnectionsActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_connections)

    val store = SecureStore(this)

    val etWorker = findViewById<EditText>(R.id.etWorker)
    val etOpenAI = findViewById<EditText>(R.id.etOpenAI)
    val etOpenAIUrl = findViewById<EditText>(R.id.etOpenAIUrl)
    val etGrok = findViewById<EditText>(R.id.etGrok)
    val etGrokUrl = findViewById<EditText>(R.id.etGrokUrl)
    val etGemini = findViewById<EditText>(R.id.etGemini)
    val etGeminiUrl = findViewById<EditText>(R.id.etGeminiUrl)

    // preload saved values
    etWorker.setText(store.getWorkerBase() ?: "")
    etOpenAI.setText(store.getApiKey("openai") ?: "")
    etOpenAIUrl.setText(store.getApiKey("openai_url") ?: "")
    etGrok.setText(store.getApiKey("grok") ?: "")
    etGrokUrl.setText(store.getApiKey("grok_url") ?: "")
    etGemini.setText(store.getApiKey("gemini") ?: "")
    etGeminiUrl.setText(store.getApiKey("gemini_url") ?: "")

    findViewById<Button>(R.id.btnSave).setOnClickListener {
      store.setWorkerBase(etWorker.text.toString().trim())
      store.setApiKey("openai", etOpenAI.text.toString().trim())
      store.setApiKey("openai_url", etOpenAIUrl.text.toString().trim())
      store.setApiKey("grok", etGrok.text.toString().trim())
      store.setApiKey("grok_url", etGrokUrl.text.toString().trim())
      store.setApiKey("gemini", etGemini.text.toString().trim())
      store.setApiKey("gemini_url", etGeminiUrl.text.toString().trim())
      Toast.makeText(this, "შენახულია", Toast.LENGTH_SHORT).show()
      finish()
    }

    findViewById<Button>(R.id.btnTest).setOnClickListener {
      // მინიმალური smoke test – უბრალოდ ვაჩვენოთ რომ მნიშვნელობები იკითხება
      val msg = buildString {
        append("Worker: ").append(store.getWorkerBase()).append(n)
        append("OpenAI key set: ").append(!store.getApiKey("openai").isNullOrBlank()).append(n)
        append("Grok key set: ").append(!store.getApiKey("grok").isNullOrBlank()).append(n)
        append("Gemini key set: ").append(!store.getApiKey("gemini").isNullOrBlank())
      }
      Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    }
  }
}
