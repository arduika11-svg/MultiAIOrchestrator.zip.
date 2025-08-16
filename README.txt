Android აპი (app/) + Cloudflare Worker (worker/).
1) Worker ატვირთე Cloudflare-ზე და ჩაწერე სეკრეტები: OPENAI_KEY, XAI_KEY, GEMINI_KEY.
2) აპში Connections გახსენი (Main-ზე status-ს გრძელი დაჭერა) და ჩაწერე შენი Worker URL.
3) GitHub Actions workflow გაგიქაჩავს app-debug.apk-ს (Artifacts-ში).
