import app from "./index.js";

const PORT = 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running locally on http://localhost:${PORT}`);
});

export default app;
