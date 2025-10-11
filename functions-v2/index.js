const functions = require("firebase-functions");
const nodemailer = require("nodemailer");
const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp();

// ✅ Email configuration
const EMAIL_USER = "JadeerGp2025@gmail.com";
const EMAIL_APP_PASSWORD = "yfmitnbrrqwxfhvu";

// Setup Nodemailer
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_APP_PASSWORD,
  },
});

/**
 * Cloud Function to send OTP to Admin
 */
exports.sendAdminOtp = functions.https.onCall(async (data, context) => {
  // ✅ DEBUG: طباعة كل شي للـ debugging
  console.log('📥 Full data received:', JSON.stringify(data));
  console.log('📥 Data type:', typeof data);
  console.log('📥 Data keys:', Object.keys(data));
  
  // ✅ محاولة استخراج البيانات بطرق متعددة
  const email = data.email || data['email'] || '';
  const otp = data.otp || data['otp'] || '';

  console.log('📧 Extracted email:', email);
  console.log('🔢 Extracted OTP:', otp);

  // Validate input
  if (!email || !otp) {
    console.error('❌ Validation failed!');
    console.error('❌ Email value:', email);
    console.error('❌ OTP value:', otp);
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email and OTP are required"
    );
  }

  // Verify user is admin
  try {
    const userSnapshot = await admin.firestore()
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

    // Email content (الـ HTML الكامل الحلو 🎨)
    const mailOptions = {
      from: `"Jadeer Admin" <${EMAIL_USER}>`,
      to: email,
      subject: "Verification Code - Jadeer Admin Panel",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <!-- Header -->
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4A5FBC; margin: 0; font-size: 28px;">🔐 Jadeer Admin</h1>
              <p style="color: #666; margin-top: 10px;">Smart Recruitment Management System</p>
            </div>

            <!-- Content -->
            <div style="text-align: center;">
              <h2 style="color: #333; font-size: 20px; margin-bottom: 20px;">
                Your Verification Code
              </h2>
              
              <div style="background: linear-gradient(135deg, #4A5FBC 0%, #FF7B7B 100%); 
                          padding: 20px; border-radius: 8px; margin: 30px 0;">
                <p style="color: white; font-size: 36px; font-weight: bold; 
                         letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">
                  ${otp}
                </p>
              </div>

              <div style="background-color: #fff3cd; border: 1px solid #ffc107; 
                          border-radius: 5px; padding: 15px; margin: 20px 0;">
                <p style="color: #856404; margin: 0; font-size: 14px;">
                  ⏱️ This code is valid for <strong>2 minutes only</strong>
                </p>
              </div>

              <p style="color: #666; font-size: 14px; line-height: 1.6;">
                If you didn't request this code, please ignore this message.<br>
                Do not share this code with anyone.
              </p>
            </div>

            <!-- Footer -->
            <div style="margin-top: 40px; padding-top: 20px; 
                        border-top: 1px solid #eee; text-align: center;">
              <p style="color: #999; font-size: 12px; margin: 5px 0;">
                © 2025 Jadeer - All Rights Reserved
              </p>
              <p style="color: #999; font-size: 12px; margin: 5px 0;">
                This is an automated email, please do not reply
              </p>
            </div>
          </div>
        </div>
      `,
    };

    // Send email
    await transporter.sendMail(mailOptions);
    console.log(`✅ OTP sent successfully to: ${email}`);
    
    return {
      success: true,
      message: "Verification code sent successfully",
    };
  } catch (error) {
    console.error("❌ Error sending OTP:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send email: " + error.message
    );
  }
});