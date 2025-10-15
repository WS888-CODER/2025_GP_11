import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';
import 'dart:async';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _canResend = false;
  int _resendTimer = 120;
  Timer? _timer;

  // المراحل: 1 = إدخال إيميل، 2 = إدخال OTP، 3 = إدخال كلمة سر جديدة
  int _currentStep = 1;
  String _userEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isStrongPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  String _generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 120;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<bool> _sendOTPEmail(String email, String otp) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('sendPasswordResetOtp');

      final result = await callable.call({
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      });

      if (result.data != null && result.data['success'] == true) {
        await _firestore
            .collection('PasswordResetOTPs')
            .doc(email.toLowerCase())
            .set({
          'OTP': otp,
          'Email': email.toLowerCase(),
          'CreatedAt': FieldValue.serverTimestamp(),
          'ExpiresAt': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: 2)),
          ),
          'Used': false,
        });
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error sending OTP: $e');
      return false;
    }
  }

  // المرحلة 1: إرسال OTP
  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String email = _emailController.text.trim().toLowerCase();

      // التحقق من وجود الإيميل
      QuerySnapshot userSnapshot = await _firestore
          .collection('Users')
          .where('Email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        _showErrorDialog('Email not found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // إرسال OTP
      String otp = _generateOTP();
      bool otpSent = await _sendOTPEmail(email, otp);

      if (otpSent) {
        _showSuccessSnackBar('✅ Verification code sent to your email');
        _startResendTimer();

        setState(() {
          _userEmail = email;
          _currentStep = 2; // الانتقال لمرحلة إدخال OTP
        });
      } else {
        _showErrorDialog('Failed to send verification code. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Unexpected error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // المرحلة 2: التحقق من OTP
  Future<void> _handleVerifyOTP() async {
    if (_otpController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the verification code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot otpDoc = await _firestore
          .collection('PasswordResetOTPs')
          .doc(_userEmail)
          .get();

      if (!otpDoc.exists) {
        _showErrorDialog('Verification code not found. Please try again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> otpData = otpDoc.data() as Map<String, dynamic>;
      String savedOTP = otpData['OTP'];
      Timestamp expiresAt = otpData['ExpiresAt'];
      bool used = otpData['Used'] ?? false;

      if (used) {
        _showErrorDialog('This code has already been used.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (DateTime.now().isAfter(expiresAt.toDate())) {
        _showErrorDialog('The code has expired. Please request a new one.');
        await _firestore
            .collection('PasswordResetOTPs')
            .doc(_userEmail)
            .delete();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_otpController.text.trim() == savedOTP) {
        // تحديد OTP كـ Used
        await _firestore
            .collection('PasswordResetOTPs')
            .doc(_userEmail)
            .update({
          'Used': true,
        });

        _showSuccessSnackBar('✅ Code verified successfully!');

        setState(() {
          _currentStep = 3; // الانتقال لمرحلة إدخال كلمة السر
        });
      } else {
        _showErrorDialog('Invalid code. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // المرحلة 3: تغيير كلمة السر
  Future<void> _handleResetPassword() async {
    if (_newPasswordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      _showErrorDialog('Please fill all password fields');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match');
      return;
    }

    if (!_isStrongPassword(_newPasswordController.text)) {
      _showErrorDialog(
          'Password must be at least 8 characters with uppercase, lowercase, number, and special character');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // استدعاء Cloud Function لتغيير الباسورد
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('resetUserPassword');

      final result = await callable.call({
        'email': _userEmail,
        'newPassword': _newPasswordController.text.trim(),
      });

      if (result.data != null && result.data['success'] == true) {
        // حذف OTP بعد النجاح
        await _firestore
            .collection('PasswordResetOTPs')
            .doc(_userEmail)
            .delete();

        _showSuccessDialog(
          'Password reset successfully!\n\nYou can now login with your new password.',
        );
      } else {
        _showErrorDialog('Failed to reset password. Please try again.');
      }
    } catch (e) {
      print('❌ Error: $e');
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Error', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: TextStyle(color: Color(0xFF4A5FBC))),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.green)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // العودة لصفحة Login
            },
            child: Text('OK', style: TextStyle(color: Color(0xFF4A5FBC))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF4A5FBC)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 40),
                Icon(
                  _currentStep == 1
                      ? Icons.lock_reset
                      : _currentStep == 2
                          ? Icons.security
                          : Icons.vpn_key,
                  size: 100,
                  color: Color(0xFF4A5FBC),
                ),
                SizedBox(height: 30),
                Text(
                  _currentStep == 1
                      ? 'Forgot Password?'
                      : _currentStep == 2
                          ? 'Enter Verification Code'
                          : 'Create New Password',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A5FBC),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  _currentStep == 1
                      ? 'Enter your email address and we\'ll send you a verification code.'
                      : _currentStep == 2
                          ? 'We sent a 6-digit code to\n$_userEmail'
                          : 'Enter your new password twice to confirm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 40),

                // ========== المرحلة 1: إدخال الإيميل ==========
                if (_currentStep == 1) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7B7B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Color(0xFF4A5FBC), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Color(0xFF4A5FBC),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!_isValidEmail(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _handleSendOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4A5FBC),
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Send Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ],

                // ========== المرحلة 2: إدخال OTP ==========
                if (_currentStep == 2) ...[
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFF4A5FBC), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  if (!_canResend)
                    Text(
                      'Resend code in $_resendTimer seconds',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  if (_canResend)
                    GestureDetector(
                      onTap: () async {
                        String otp = _generateOTP();
                        bool otpSent = await _sendOTPEmail(_userEmail, otp);
                        if (otpSent) {
                          _showSuccessSnackBar('✅ New code sent!');
                          _startResendTimer();
                          _otpController.clear();
                        } else {
                          _showErrorDialog(
                              'Failed to resend code. Please try again.');
                        }
                      },
                      child: Text(
                        'Didn\'t receive code? Resend',
                        style: TextStyle(
                          color: Color(0xFF4A5FBC),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 40),
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _handleVerifyOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4A5FBC),
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ],

                // ========== المرحلة 3: إدخال كلمة السر الجديدة ==========
                if (_currentStep == 3) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7B7B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Color(0xFF4A5FBC), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            hintText: 'Enter new password',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Color(0xFF4A5FBC),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Must include: uppercase, lowercase, number, special character',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7B7B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Color(0xFF4A5FBC), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'Re-enter new password',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Color(0xFF4A5FBC),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _handleResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4A5FBC),
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ],

                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Remember your password? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: Color(0xFF4A5FBC),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
