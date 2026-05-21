import * as functions from "firebase-functions";
import OpenAI from "openai";
const cors = require("cors");

const corsHandler = cors({ origin: true });

export const analyzeImage = functions.https.onRequest(
  { secrets: ["OPENAI_API_KEY"] },
  async (req: any, res: any) => {
    corsHandler(req, res, async () => {
      const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY! });
      try {
        const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
        const { imageUrl } = body;
        if (!imageUrl) return res.status(400).json({ error: "No image provided" });

        const response = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          messages: [{
            role: "user",
            content: [
              { type: "text", text: `حلل الصورة وارجع JSON فقط بدون أي كلام إضافي:\n{\n  "itemType": "",\n  "color": "",\n  "brand": "",\n  "description": ""\n}\nالقواعد:\n- itemType: نوع الغرض (مثال: جوال، حقيبة، نظارة)\n- color: اللون الأساسي\n- brand: الماركة (إذا غير معروف خله فاضي)\n- description: وصف مختصر` },
              { type: "image_url", image_url: { url: imageUrl } },
            ],
          }],
        });
        return res.json({ raw: response.choices?.[0]?.message?.content || "" });
      } catch (error: any) {
        console.error("ANALYZE_IMAGE_ERROR:", error);
        return res.status(500).json({ error: "Failed to analyze image", details: error?.message || String(error) });
      }
    });
  }
);

export const analyzeMatch = functions.https.onRequest(
  { secrets: ["OPENAI_API_KEY"] },
  async (req: any, res: any) => {
    corsHandler(req, res, async () => {
      const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY! });
      try {
        const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
        const { lost, found } = body;
        if (!lost || !found) return res.status(400).json({ error: "Missing lost or found data" });

        const prompt = `
You are a lost and found matching system for a metro station.
Compare these two item reports and return a JSON analysis.

Lost item report:
- Type: ${lost.item_type || ""}
- Color: ${lost.color || ""}
- Brand: ${lost.brand || "not specified"}
- Description: ${lost.description || ""}

Found item report:
- Type: ${found.itemType || ""}
- Color: ${found.color || ""}
- Brand: ${found.brand || "not specified"}
- Description: ${found.description || ""}

Instructions:
- Understand Arabic dialects and typos (e.g. "شنطة" = "حقيبة", "سودا" = "سوداء")
- Normalize Arabic/English brand names (e.g. "سامسونج" = "Samsung")
- Return ONLY valid JSON, no extra text

Return this exact JSON structure:
{
  "type_match": <0-100>,
  "color_match": <0-100>,
  "brand_match": <0-100 or null if either brand is missing>,
  "semantic_similarity": <0-100>,
  "image_similarity": null,
  "normalized_type": "<unified item type in Arabic>",
  "normalized_color": "<unified color in Arabic>",
  "normalized_brand": "<unified brand name or null>",
  "reasoning": "<brief explanation in English>"
}`;

        const messages: any[] = [{ role: "user", content: prompt }];

        if (lost.photo_url && found.imageUrl && !lost.photo_url.startsWith("data:") && !found.imageUrl.startsWith("data:")) {
          try {
            const imgResponse = await openai.chat.completions.create({
              model: "gpt-4o", temperature: 0,
              messages: [{ role: "user", content: [
                { type: "image_url", image_url: { url: lost.photo_url } },
                { type: "image_url", image_url: { url: found.imageUrl } },
                { type: "text", text: `Compare these two images. Return ONLY: { "image_similarity": <0-100> }` },
              ]}],
            });
            const imgClean = (imgResponse.choices[0]?.message?.content || "").replace(/```json|```/g, "").trim();
            const imgResult = JSON.parse(imgClean);
            messages[0].content += `\n\nImage comparison result: image_similarity = ${imgResult.image_similarity}. Update the image_similarity field accordingly.`;
          } catch (imgErr) {
            console.warn("Image comparison failed, skipping:", imgErr);
          }
        }

        const response = await openai.chat.completions.create({ model: "gpt-4o-mini", temperature: 0, messages });
        const clean = (response.choices?.[0]?.message?.content || "").replace(/```json|```/g, "").trim();
        return res.json({ raw: clean });
      } catch (error: any) {
        console.error("ANALYZE_MATCH_ERROR:", error);
        return res.status(500).json({ error: "Failed to analyze match", details: error?.message || String(error) });
      }
    });
  }
);

/* ══════════════════════════════════════════
   generateAlerts — توليد تنبيهات ذكية
   ══════════════════════════════════════════ */
export const generateAlerts = functions.https.onRequest(
  { secrets: ["OPENAI_API_KEY"] },
  async (req: any, res: any) => {
    corsHandler(req, res, async () => {
      const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY! });
      try {
        const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
        const { mode, context } = body;

        if (!mode || !context) {
          return res.status(400).json({ error: "Missing mode or context" });
        }

        const systemPrompt = mode === "general"
          ? `أنت نظام تنبيهات ذكي لمترو الرياض. مهمتك تحليل بيانات الازدحام الحقيقية وتوليد تنبيهات فقط عند وجود مشكلة فعلية.
قواعد صارمة:
- ولّد تنبيه فقط لو crowd_level = "High" أو "Extreme" أو load_ratio > 0.75
- لو كل المحطات طبيعية اجعل المصفوفة فارغة []
- لا تخترع مشاكل غير موجودة في البيانات
- أرجع JSON فقط بدون أي نص إضافي`
          : `أنت نظام تنبيهات ذكي لمحطة مترو محددة. حلل البيانات الحقيقية وولّد تنبيهات منطقية.
قواعد:
- ولّد تنبيه ازدحام فقط لو load_ratio > 0.60
- لو الوضع طبيعي اجعل المصفوفة فارغة []
- أرجع JSON فقط بدون أي نص إضافي`;

        const userPrompt = `${context}

أرجع JSON فقط بهذا الشكل:
[
  {
    "type": "critical|warning|info",
    "title": "عنوان قصير",
    "message": "تفاصيل موجزة",
    "badge": "تحذير|حرج|معلومة"
  }
]`;

        const response = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          temperature: 0,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
        });

        const text = response.choices?.[0]?.message?.content || "[]";
        const clean = text.replace(/```json|```/g, "").trim();

        return res.json({ raw: clean });
      } catch (error: any) {
        console.error("GENERATE_ALERTS_ERROR:", error);
        return res.status(500).json({ error: "Failed to generate alerts", details: error?.message || String(error) });
      }
    });
  }
);