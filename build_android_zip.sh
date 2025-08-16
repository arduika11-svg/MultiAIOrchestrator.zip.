#!/data/data/com.termux/files/usr/bin/bash
set -e

# zip ინსტალაცია (თუ უკვე დგას, გამოტოვებს)
pkg install -y zip >/dev/null 2>&1 || true

PROJ="MultiAIOrchestrator"
rm -rf "$PROJ"
mkdir -p "$PROJ"/.github/workflows
mkdir -p "$PROJ"/app/src/main/java/com/orchestrator/starter
mkdir -p "$PROJ"/app/src/main/res/layout
mkdir -p "$PROJ"/worker

# ---------- settings.gradle.kts ----------
cat > "$PROJ/settings.gradle.kts" <<'EOF'
pluginManagement {
  repositories {
    gradlePluginPortal()
    google()
    mavenCentral()
  }
}
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
  }
}
rootProject.name = "MultiAIOrchestrator"
include(":app")
EOF

# ---------- root build.gradle.kts ----------
cat > "$PROJ/build.gradle.kts" <<'EOF'
plugins {
  id("com.android.application") version "8.5.0" apply false
  id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
EOF

# ---------- gradle.properties ----------
cat > "$PROJ/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
EOF

# ---------- app/build.gradle.kts ----------
cat > "$PROJ/app/build.gradle.kts" <<'EOF'
plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
}

android {
  namespace = "com.orchestrator.starter"
  compileSdk = 34

  defaultConfig {
    applicationId = "com.orchestrator.starter"
    minSdk = 26
    targetSdk = 34
    versionCode = 1
    versionName = "1.0"
  }

  buildTypes {
    release {
      isMinifyEnabled = false
      proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro"
      )
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions { jvmTarget = "17" }
}

dependencies {
  implementation("androidx.core:core-ktx:1.13.1")
  implementation("androidx.appcompat:appcompat:1.7.0")
  implementation("com.google.android.material:material:1.12.0")
  implementation("com.squareup.okhttp3:okhttp:4.12.0")
  implementation("org.json:json:20240303")
}
EOF

# ---------- AndroidManifest.xml ----------
cat > "$PROJ/app/src/main/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="Multi-AI Orchestrator"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar">
        <activity android:name=".ConnectionsActivity"/>
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# ---------- MainActivity.kt ----------
cat > "$PROJ/app/src/main/java/com/orchestrator/starter/MainActivity.kt" <<'EOF'
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
EOF

# ---------- ConnectionsActivity.kt ----------
cat > "$PROJ/app/src/main/java/com/orchestrator/starter/ConnectionsActivity.kt" <<'EOF'
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
EOF

# ---------- activity_main.xml ----------
cat > "$PROJ/app/src/main/res/layout/activity_main.xml" <<'EOF'
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
  <LinearLayout
      android:orientation="vertical" android:padding="16dp"
      android:layout_width="match_parent" android:layout_height="wrap_content">

    <EditText
        android:id="@+id/etPrompt"
        android:hint="რა დავალება გვაქვს?"
        android:layout_width="match_parent" android:layout_height="wrap_content"/>

    <LinearLayout
        android:orientation="horizontal"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginTop="8dp">
      <CheckBox android:id="@+id/tOpenAI" android:text="OpenAI" android:checked="true"/>
      <CheckBox android:id="@+id/tGrok"   android:text="Grok"   android:layout_marginStart="12dp" android:checked="true"/>
      <CheckBox android:id="@+id/tGemini" android:text="Gemini" android:layout_marginStart="12dp" android:checked="true"/>
    </LinearLayout>

    <LinearLayout
        android:orientation="horizontal"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginTop="8dp">
      <Switch
          android:id="@+id/switchCoop"
          android:text="Co-op (მრავალტურიანი)"
          android:layout_width="wrap_content" android:layout_height="wrap_content"/>
      <EditText
          android:id="@+id/etRounds"
          android:hint="Rounds (ციფრი; ცარიელი=1)"
          android:inputType="number"
          android:layout_marginStart="12dp"
          android:layout_width="0dp" android:layout_weight="1"
          android:layout_height="wrap_content"/>
    </LinearLayout>

    <LinearLayout
        android:orientation="horizontal"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginTop="8dp">
      <Button android:id="@+id/btnAskAll"     android:text="Ask All"/>
      <Button android:id="@+id/btnAskOpenAI"  android:text="OpenAI" android:layout_marginStart="8dp"/>
      <Button android:id="@+id/btnAskGrok"    android:text="Grok"    android:layout_marginStart="8dp"/>
      <Button android:id="@+id/btnAskGemini"  android:text="Gemini"  android:layout_marginStart="8dp"/>
    </LinearLayout>

    <TextView android:id="@+id/status"     android:text="მზადაა (გრძელი დაჭერა = Connections)"  android:layout_marginTop="12dp"/>
    <TextView android:id="@+id/rawOpenAI"  android:text="OpenAI: —" android:layout_marginTop="6dp"/>
    <TextView android:id="@+id/rawGrok"    android:text="Grok: —"   android:layout_marginTop="6dp"/>
    <TextView android:id="@+id/rawGemini"  android:text="Gemini: —" android:layout_marginTop="6dp"/>
    <TextView android:id="@+id/unified"    android:text="მოლოდინი…" android:layout_marginTop="10dp"/>
  </LinearLayout>
</ScrollView>
EOF

# ---------- activity_connections.xml ----------
cat > "$PROJ/app/src/main/res/layout/activity_connections.xml" <<'EOF'
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
  android:layout_width="match_parent" android:layout_height="match_parent">
  <LinearLayout android:orientation="vertical" android:padding="16dp"
    android:layout_width="match_parent" android:layout_height="wrap_content">

    <TextView android:text="Connections (API Keys & Endpoints)" android:textSize="18sp"/>

    <TextView android:text="Worker Base URL" android:paddingTop="8dp"/>
    <EditText android:id="@+id/etWorker" android:hint="https://your-worker.workers.dev"
      android:inputType="textUri" android:layout_width="match_parent" android:layout_height="wrap_content"/>

    <TextView android:text="OpenAI API Key" android:paddingTop="12dp"/>
    <EditText android:id="@+id/etOpenAI" android:hint="sk-..." android:inputType="textPassword"
      android:layout_width="match_parent" android:layout_height="wrap_content"/>
    <TextView android:text="OpenAI Endpoint (optional)"/>
    <EditText android:id="@+id/etOpenAIUrl" android:hint="https://api.openai.com/v1" android:inputType="textUri"
      android:layout_width="match_parent" android:layout_height="wrap_content"/>

    <TextView android:text="Grok (xAI) API Key" android:paddingTop="12dp"/>
    <EditText android:id="@+id/etGrok" android:hint="xai-..." android:inputType="textPassword"
      android:layout_width="match_parent" android:layout_height="wrap_content"/>
    <TextView android:text="Grok Endpoint (optional)"/>
    <EditText android:id="@+id/etGrokUrl" android:hint="https://api.x.ai/v1" android:inputType="textUri"
      android:layout_width="match_parent" android:layout_height="wrap_content"/>

    <TextView android:text="Gemini API Key" android:paddingTop="12dp"/>
    <EditText android:id="@+id/etGemini" android:hint="AIza..." android:inputType="textPassword"
      android:layout_width="match_parent" android:layout_height="wrap_content"/>
    <TextView android:text="Gemini Endpoint (optional)"/>
    <EditText android:id="@+id/etGeminiUrl" android:hint="https://generativelanguage.googleapis.com" android:inputType="textUri"
      android:layout_width="match_parent" android:layout_height="wrap_content"/>

    <LinearLayout android:orientation="horizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:paddingTop="16dp">
      <Button android:id="@+id/btnTest" android:text="Test"/>
      <Button android:id="@+id/btnSave" android:text="Save" android:layout_marginStart="12dp"/>
    </LinearLayout>
  </LinearLayout>
</ScrollView>
EOF

# ---------- proguard ----------
echo "# debug build-ში ცარიელი საკმარისია" > "$PROJ/app/proguard-rules.pro"

# ---------- GitHub Actions workflow ----------
cat > "$PROJ/.github/workflows/build.yml" <<'EOF'
name: Build Android (Debug APK)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3

      - name: Build Debug APK
        run: gradle assembleDebug --no-daemon

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-debug
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

# ---------- Cloudflare Worker ----------
cat > "$PROJ/worker/worker.js" <<'EOF'
// Cloudflare Worker - /ping და /ask
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/ping") return json({ ok: true });

    if (url.pathname === "/ask" && request.method === "POST") {
      const body = await request.json().catch(() => ({}));
      const prompt = (body.prompt ?? "").toString();
      const providers = Array.isArray(body.providers) ? body.providers : ["OpenAI","Grok","Gemini"];
      const coop = !!body.coop;
      const rounds = Math.max(1, Number(body.rounds) || 1);
      if (!prompt) return json({ error: "missing prompt" }, 400);

      const want = new Set(providers.map(String));
      const answers = {};
      let context = prompt;

      const runRound = async () => {
        const tasks = [];
        if (want.has("OpenAI") && env.OPENAI_KEY) tasks.push(
          askOpenAI(env, context).then(t => answers.openai = t).catch(e => answers.openai = "ERR: " + e.message)
        );
        if (want.has("Grok") && env.XAI_KEY) tasks.push(
          askGrok(env, context).then(t => answers.grok = t).catch(e => answers.grok = "ERR: " + e.message)
        );
        if (want.has("Gemini") && env.GEMINI_KEY) tasks.push(
          askGemini(env, context).then(t => answers.gemini = t).catch(e => answers.gemini = "ERR: " + e.message)
        );
        await Promise.all(tasks);
      };

      if (coop) {
        for (let i = 0; i < rounds; i++) {
          await runRound();
          const summary = summarize(answers);
          context =
            `${prompt}\n\n--- Round ${i + 1} responses ---\n` +
            `OpenAI: ${answers.openai || ""}\nGrok: ${answers.grok || ""}\nGemini: ${answers.gemini || ""}\n\n` +
            `Improve together. User goal: ${prompt}\nCurrent summary: ${summary}`;
        }
      } else {
        await runRound();
      }

      return json({ unified: summarize(answers), ...answers });
    }

    return new Response("Not found", { status: 404 });
  }
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status, headers: { "content-type": "application/json" }
  });
}

function summarize(a) {
  const parts = [a.openai, a.grok, a.gemini].filter(Boolean);
  return parts.length ? parts.join("\n---\n") : "No provider replied.";
}

async function askOpenAI(env, prompt) {
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${env.OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: prompt }], temperature: 0.5 })
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || r.statusText);
  return j.choices?.[0]?.message?.content?.toString()?.trim() ?? "";
}

async function askGrok(env, prompt) {
  const r = await fetch("https://api.x.ai/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${env.XAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "grok-beta", messages: [{ role: "user", content: prompt }], temperature: 0.5 })
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || r.statusText);
  return j.choices?.[0]?.message?.content?.toString()?.trim() ?? "";
}

async function askGemini(env, prompt) {
  const url = `https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=${env.GEMINI_KEY}`;
  const r = await fetch(url, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }] })
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || r.statusText);
  return j.candidates?.[0]?.content?.parts?.[0]?.text?.toString()?.trim() ?? "";
}
EOF

# ---------- README ----------
cat > "$PROJ/README.txt" <<'EOF'
Android აპი (app/) + Cloudflare Worker (worker/).
1) Worker ატვირთე Cloudflare-ზე და ჩაწერე სეკრეტები: OPENAI_KEY, XAI_KEY, GEMINI_KEY.
2) აპში Connections გახსენი (Main-ზე status-ს გრძელი დაჭერა) და ჩაწერე შენი Worker URL.
3) GitHub Actions workflow გაგიქაჩავს app-debug.apk-ს (Artifacts-ში).
EOF

# ---------- ZIP ----------
zip -rq "${PROJ}.zip" "$PROJ"
echo "DONE -> $(pwd)/${PROJ}.zip"
