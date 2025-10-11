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
 * Cloud Function to send OTP to Admin (Login only)
 */
exports.sendAdminOtp = functions.https.onCall(async (data, context) => {
  console.log('📥 Full data received:', data);
  console.log('📥 Data type:', typeof data);
  console.log('📥 Data keys:', data ? Object.keys(data) : 'no data');
  
  // ✅ البيانات موجودة في data.data وليس data مباشرة!
  const actualData = data.data || data;
  const email = actualData.email || actualData['email'] || '';
  const otp = actualData.otp || actualData['otp'] || '';

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

    // ✨ Email content - التصميم القديم الحلو
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

/**
 * ✅ NEW: Cloud Function to send OTP during Signup (Company & JobSeeker)
 */
exports.sendSignupOtp = functions.https.onCall(async (data, context) => {
  console.log('📥 Signup OTP - Full data received:', data);
  
  const actualData = data.data || data;
  const email = actualData.email || actualData['email'] || '';
  const otp = actualData.otp || actualData['otp'] || '';
  const userType = actualData.userType || actualData['userType'] || '';

  console.log('📧 Email:', email);
  console.log('🔢 OTP:', otp);
  console.log('👤 UserType:', userType);

  // Validate input
  if (!email || !otp) {
    console.error('❌ Validation failed!');
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email and OTP are required"
    );
  }

  try {
    // ✨ Email content for Signup
    const mailOptions = {
      from: `"Jadeer Recruitment" <${EMAIL_USER}>`,
      to: email,
      subject: "Email Verification - Welcome to Jadeer!",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <!-- Header -->
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4A5FBC; margin: 0; font-size: 28px;">🎉 Welcome to Jadeer!</h1>
              <p style="color: #666; margin-top: 10px;">Smart Recruitment Management System</p>
            </div>

            <!-- Content -->
            <div style="text-align: center;">
              <h2 style="color: #333; font-size: 20px; margin-bottom: 20px;">
                Verify Your Email
              </h2>
              
              <p style="color: #666; font-size: 14px; margin-bottom: 20px;">
                Thank you for signing up! Please use the code below to verify your email address.
              </p>

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
                If you didn't create an account, please ignore this message.<br>
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
    console.log(`✅ Signup OTP sent successfully to: ${email}`);
    
    return {
      success: true,
      message: "Verification code sent successfully",
    };
  } catch (error) {
    console.error("❌ Error sending Signup OTP:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send email: " + error.message
    );
  }
});

/**
 * ✅ NEW: Cloud Function to notify Admin about new Company registration
 */
exports.notifyAdminNewCompany = functions.https.onCall(async (data, context) => {
  console.log('📥 Admin notification - Full data received:', data);
  
  const actualData = data.data || data;
  const email = actualData.email || actualData['email'] || '';
  const companyName = actualData.companyName || actualData['companyName'] || '';
  const name = actualData.name || actualData['name'] || '';

  console.log('📧 Company Email:', email);
  console.log('🏢 Company Name:', companyName);

  const ADMIN_EMAIL = "walaasaif47@gmail.com";

  try {
    const mailOptions = {
      from: `"Jadeer System" <${EMAIL_USER}>`,
      to: ADMIN_EMAIL,
      subject: "🔔 New Company Registration - Action Required",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <!-- Header -->
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4A5FBC; margin: 0; font-size: 28px;">🔔 New Company Registration</h1>
              <p style="color: #666; margin-top: 10px;">Jadeer Admin Panel</p>
            </div>

            <!-- Content -->
            <div>
              <h2 style="color: #333; font-size: 20px; margin-bottom: 20px;">
                Company Details
              </h2>
              
              <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <p style="margin: 10px 0; color: #333;"><strong>Company Name:</strong> ${companyName}</p>
                <p style="margin: 10px 0; color: #333;"><strong>Representative Name:</strong> ${name}</p>
                <p style="margin: 10px 0; color: #333;"><strong>Email:</strong> ${email}</p>
                <p style="margin: 10px 0; color: #666; font-size: 12px;"><strong>Registration Date:</strong> ${new Date().toLocaleString()}</p>
              </div>

              <div style="background-color: #fff3cd; border: 1px solid #ffc107; 
                          border-radius: 5px; padding: 15px; margin: 20px 0;">
                <p style="color: #856404; margin: 0; font-size: 14px;">
                  ⚠️ <strong>Action Required:</strong> This company is awaiting document verification and approval.
                </p>
              </div>

              <p style="color: #666; font-size: 14px; line-height: 1.6;">
                Please review the company documents when they are submitted and approve or reject the registration from the admin dashboard.
              </p>
            </div>

            <!-- Footer -->
            <div style="margin-top: 40px; padding-top: 20px; 
                        border-top: 1px solid #eee; text-align: center;">
              <p style="color: #999; font-size: 12px; margin: 5px 0;">
                © 2025 Jadeer - All Rights Reserved
              </p>
              <p style="color: #999; font-size: 12px; margin: 5px 0;">
                This is an automated notification from Jadeer System
              </p>
            </div>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Admin notification sent successfully`);
    
    return {
      success: true,
      message: "Admin notification sent successfully",
    };
  } catch (error) {
    console.error("❌ Error sending admin notification:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send notification: " + error.message
    );
  }
});

/**
 * ✅ NEW: Cloud Function to send Company Document Request Email
 */
exports.sendCompanyDocumentRequest = functions.https.onCall(async (data, context) => {
  console.log('📥 Document request - Full data received:', data);
  
  const actualData = data.data || data;
  const email = actualData.email || actualData['email'] || '';
  const companyName = actualData.companyName || actualData['companyName'] || '';

  console.log('📧 Email:', email);
  console.log('🏢 Company:', companyName);

  // Validate input
  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email is required"
    );
  }

  try {
    const mailOptions = {
      from: `"Jadeer Recruitment" <${EMAIL_USER}>`,
      to: email,
      subject: "Action Required - Company Verification Documents",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
          <div style="background-color: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <!-- Header -->
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4A5FBC; margin: 0; font-size: 28px;">📄 Jadeer</h1>
              <p style="color: #666; margin-top: 10px;">Smart Recruitment Management System</p>
            </div>

            <!-- Content -->
            <div>
              <h2 style="color: #333; font-size: 20px; margin-bottom: 20px;">
                Verify Your Company Account
              </h2>
              
              <p style="color: #666; font-size: 14px; line-height: 1.6; margin-bottom: 15px;">
                Dear ${companyName || 'Company Representative'},
              </p>

              <p style="color: #666; font-size: 14px; line-height: 1.6; margin-bottom: 15px;">
                Thank you for registering with Jadeer! Your email has been successfully verified.
              </p>

              <p style="color: #666; font-size: 14px; line-height: 1.6; margin-bottom: 15px;">
                To complete your company registration, please reply to this email with an <strong>official company document</strong> that proves your employment or authorization to represent the company.
              </p>

              <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; 
                          padding: 15px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #1565C0; margin: 0; font-size: 14px; font-weight: bold;">
                  📋 Acceptable Documents:
                </p>
                <ul style="color: #1565C0; margin: 10px 0 0 20px; font-size: 14px;">
                  <li>Company Registration Certificate</li>
                  <li>Employment Letter with Company Stamp</li>
                  <li>Business License</li>
                  <li>Official Authorization Letter</li>
                </ul>
              </div>

              <p style="color: #666; font-size: 14px; line-height: 1.6; margin-bottom: 15px;">
                Once we receive and verify your documents, your account will be activated, and you'll be able to post job openings and access all company features.
              </p>

              <div style="background-color: #fff3cd; border: 1px solid #ffc107; 
                          border-radius: 5px; padding: 15px; margin: 20px 0;">
                <p style="color: #856404; margin: 0; font-size: 14px;">
                  ⚠️ <strong>Important:</strong> Your account is currently in <strong>Pending</strong> status and cannot be used until verification is complete.
                </p>
              </div>

              <p style="color: #666; font-size: 14px; line-height: 1.6;">
                If you have any questions, feel free to reply to this email.
              </p>

              <p style="color: #666; font-size: 14px; line-height: 1.6; margin-top: 20px;">
                Best regards,<br>
                <strong>The Jadeer Team</strong>
              </p>
            </div>

            <!-- Footer -->
            <div style="margin-top: 40px; padding-top: 20px; 
                        border-top: 1px solid #eee; text-align: center;">
              <p style="color: #999; font-size: 12px; margin: 5px 0;">
                © 2025 Jadeer - All Rights Reserved
              </p>
              <p style="color: #999; font-size: 12px; margin: 5px 0;">
                This is an automated email, please reply with your documents
              </p>
            </div>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Company document request sent to: ${email}`);
    
    return {
      success: true,
      message: "Document request email sent successfully",
    };
  } catch (error) {
    console.error("❌ Error sending document request:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send email: " + error.message
    );
  }
});