import express from "express";
import OpenAI from "openai";
import * as functions from "firebase-functions";
import admin from "firebase-admin";
import nodemailer from "nodemailer";

// ============================================
// 🔧 Initialize Services
// ============================================
const app = express();
app.use(express.json());

// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
  admin.initializeApp();
}

// ============================================
// 📧 EMAIL CONFIGURATION
// ============================================
const EMAIL_USER = "JadeerGp2025@gmail.com";
const EMAIL_APP_PASSWORD = "yfmitnbrrqwxfhvu";

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_APP_PASSWORD,
  },
});

// ============================================
// 📧 EMAIL FUNCTIONS
// ============================================

/**
 * 1️⃣ Send OTP to Admin (Login)
 */
export const sendAdminOtp = functions.https.onCall(async (data, context) => {
  console.log("📥 Admin OTP - Full data:", data);

  const actualData = data.data || data;
  const email = actualData.email || actualData["email"] || "";
  const otp = actualData.otp || actualData["otp"] || "";

  console.log("📧 Email:", email);
  console.log("🔢 OTP:", otp);

  if (!email || !otp) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email and OTP are required"
    );
  }

  try {
    const userSnapshot = await admin
      .firestore()
      .collection("Users")
      .where("Email", "==", email)
      .where("UserType", "==", "Admin")
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "User not found or not an admin"
      );
    }

    const mailOptions = {
      from: `"Jadeer Admin" <${EMAIL_USER}>`,
      to: email,
      subject: "Verification Code - Jadeer Admin Panel",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4A5FBC; margin: 0; font-size: 28px;">🔐 Jadeer Admin</h1>
              <p style="color: #666; margin-top: 10px;">Smart Recruitment Management System</p>
            </div>
            <div style="text-align: center;">
              <h2 style="color: #333; font-size: 20px; margin-bottom: 20px;">Your Verification Code</h2>
              <div style="background: linear-gradient(135deg, #4A5FBC 0%, #FF7B7B 100%); padding: 20px; border-radius: 8px; margin: 30px 0;">
                <p style="color: white; font-size: 36px; font-weight: bold; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">${otp}</p>
              </div>
              <div style="background-color: #fff3cd; border: 1px solid #ffc107; border-radius: 5px; padding: 15px; margin: 20px 0;">
                <p style="color: #856404; margin: 0; font-size: 14px;">⏱️ This code is valid for <strong>2 minutes only</strong></p>
              </div>
              <p style="color: #666; font-size: 14px; line-height: 1.6;">If you didn't request this code, please ignore this message.<br>Do not share this code with anyone.</p>
            </div>
            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
              <p style="color: #999; font-size: 12px; margin: 5px 0;">© 2025 Jadeer - All Rights Reserved</p>
            </div>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ OTP sent to admin: ${email}`);

    return { success: true, message: "Verification code sent successfully" };
  } catch (error) {
    console.error("❌ Error sending admin OTP:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send email: " + error.message
    );
  }
});

/**
 * 2️⃣ Send OTP during Signup (Company & JobSeeker)
 */
export const sendSignupOtp = functions.https.onCall(async (data, context) => {
  console.log("📥 Signup OTP - Full data:", data);

  const actualData = data.data || data;
  const email = actualData.email || actualData["email"] || "";
  const otp = actualData.otp || actualData["otp"] || "";

  if (!email || !otp) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email and OTP are required"
    );
  }

  try {
    const mailOptions = {
      from: `"Jadeer Recruitment" <${EMAIL_USER}>`,
      to: email,
      subject: "Email Verification - Welcome to Jadeer!",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4A5FBC; margin: 0; font-size: 28px;">🎉 Welcome to Jadeer!</h1>
              <p style="color: #666; margin-top: 10px;">Smart Recruitment Management System</p>
            </div>
            <div style="text-align: center;">
              <h2 style="color: #333; font-size: 20px; margin-bottom: 20px;">Verify Your Email</h2>
              <p style="color: #666; font-size: 14px; margin-bottom: 20px;">Thank you for signing up! Please use the code below to verify your email address.</p>
              <div style="background: linear-gradient(135deg, #4A5FBC 0%, #FF7B7B 100%); padding: 20px; border-radius: 8px; margin: 30px 0;">
                <p style="color: white; font-size: 36px; font-weight: bold; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">${otp}</p>
              </div>
              <div style="background-color: #fff3cd; border: 1px solid #ffc107; border-radius: 5px; padding: 15px; margin: 20px 0;">
                <p style="color: #856404; margin: 0; font-size: 14px;">⏱️ This code is valid for <strong>2 minutes only</strong></p>
              </div>
              <p style="color: #666; font-size: 14px; line-height: 1.6;">If you didn't create an account, please ignore this message.<br>Do not share this code with anyone.</p>
            </div>
            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
              <p style="color: #999; font-size: 12px; margin: 5px 0;">© 2025 Jadeer - All Rights Reserved</p>
            </div>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Signup OTP sent to: ${email}`);

    return { success: true, message: "Verification code sent successfully" };
  } catch (error) {
    console.error("❌ Error sending signup OTP:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send email: " + error.message
    );
  }
});

/**
 * 3️⃣ Notify Admin about new Company registration
 */
export const notifyAdminNewCompany = functions.https.onCall(async (data, context) => {
  console.log("📥 Admin notification - Full data:", data);

  const actualData = data.data || data;
  const companyName = actualData.companyName || actualData["companyName"] || "";
  const companyEmail = actualData.companyEmail || actualData["companyEmail"] || "";

  if (!companyName || !companyEmail) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Company name and email are required"
    );
  }

  try {
    const mailOptions = {
      from: `"Jadeer System" <${EMAIL_USER}>`,
      to: EMAIL_USER,
      subject: "🚀 New Company Registration - Action Required",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <h2 style="color: #333; font-size: 20px;">New Company Registered!</h2>
            <p><strong>Company:</strong> ${companyName}</p>
            <p><strong>Email:</strong> ${companyEmail}</p>
            <p>Please review documents in the admin dashboard.</p>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Admin notified about: ${companyName}`);

    return { success: true, message: "Admin notification sent successfully" };
  } catch (error) {
    console.error("❌ Error sending admin notification:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send notification: " + error.message
    );
  }
});

/**
 * 4️⃣ Send Company Document Request Email
 */
export const sendCompanyDocumentRequest = functions.https.onCall(async (data, context) => {
  console.log("📥 Document request - Full data:", data);

  const actualData = data.data || data;
  const email = actualData.email || actualData["email"] || "";
  const companyName = actualData.companyName || actualData["companyName"] || "";

  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "Email is required");
  }

  try {
    const mailOptions = {
      from: `"Jadeer Recruitment" <${EMAIL_USER}>`,
      to: email,
      subject: "Action Required - Company Verification Documents",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px;">
            <p>Dear ${companyName || "Company Representative"},</p>
            <p>Please provide the following:</p>
            <ul>
              <li>Commercial Registration</li>
              <li>Tax Certificate</li>
              <li>Company License</li>
            </ul>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Document request sent to: ${email}`);

    return { success: true, message: "Document request email sent successfully" };
  } catch (error) {
    console.error("❌ Error sending document request:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send email: " + error.message
    );
  }
});

// ============================================
// 🤖 OPENAI API (SAFE FIXED VERSION)
// ============================================
export const generateJobPost = functions.https.onRequest(async (req, res) => {
  try {
    const { title } = req.body;

    // Initialize OpenAI with environment variable (Firebase injects secret automatically)
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

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
