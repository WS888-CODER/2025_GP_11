import 'dotenv/config';
import express from "express";
import OpenAI from "openai";

const app = express();
app.use(express.json());

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

app.post("/generateJobPost", async (req, res) => {
  try {
    const { title } = req.body;

    const prompt = `
      Write a concise and professional job description (under 100 words)
      for the position: "${title}".
      Focus on:
      - The role's main responsibilities (2–3 short sentences)
      - One short, inviting closing line encouraging candidates to apply.
      Provide only the description text, no headers or sections.
    `;

    const response = await openai.responses.create({
      model: "gpt-4o-mini",
      input: prompt,
    });

    const text = response.output[0].content[0].text.trim();
    res.status(200).json({ job_post: text });

  } catch (error) {
    console.error("❌ Error generating job post:", error);
    res.status(500).json({ error: error.message });
  }
});

export default app;
