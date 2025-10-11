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
    const { title, company, skills } = req.body;

    const prompt = `
      Write a concise and professional job description (under 100 words)
      for the position "${title}" at ${company}.
      Focus only on:
      - The role's main tasks (2–3 short sentences)
      - The required skills (${skills})
      - One short, inviting closing line encouraging candidates to apply.
      Avoid all sections like About Us, Benefits, or Company Culture.
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
