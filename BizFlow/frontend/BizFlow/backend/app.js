const express = require('express');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

const { Configuration, OpenAIApi } = require("openai");
const configuration = new Configuration({ apiKey: process.env.OPENAI_API_KEY });
const openai = new OpenAIApi(configuration);

const hfClient = axios.create({
  baseURL: 'https://api-inference.huggingface.co/models/',
  headers: { Authorization: `Bearer ${process.env.HUGGINGFACE_API_KEY}` }
});

// Route: Basic OpenAI interaction
app.post('/openai', async (req, res) => {
  const { prompt } = req.body;
  try {
    const response = await openai.createCompletion({
      model: "text-davinci-003",
      prompt: prompt,
      max_tokens: 150,
    });
    res.json({ text: response.data.choices[0].text });
  } catch (error) {
    res.status(500).json({ error: 'Error interacting with OpenAI', details: error });
  }
});

// Route: Hugging Face interaction
app.post('/huggingface', async (req, res) => {
  const { text } = req.body;
  try {
    const response = await hfClient.post('model_name', { inputs: text });
    res.json({ result: response.data });
  } catch (error) {
    res.status(500).json({ error: 'Error interacting with Hugging Face', details: error });
  }
});

const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});
