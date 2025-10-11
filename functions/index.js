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
      Write a detailed, professional job posting for the position "${title}" 
      at ${company}. Highlight required skills like ${skills}, company culture, 
      and reasons to apply.
    `;

    const response = await openai.responses.create({
      model: "gpt-4o-mini",
      input: prompt,
    });

    const text = response.output[0].content[0].text;
    res.status(200).json({ job_post: text });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

export default app;
