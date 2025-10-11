// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:async';

class OTPVerificationScreen extends StatefulWidget {
  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 120;
    });

    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
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
      ),
    );
  }

  void _showSuccessDialog(String message, VoidCallback onOk) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onOk();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _resendOTP(String email, String userType) async {
    if (_resendCountdown > 0) {
      _showErrorDialog(
          'The current OTP is still valid. Please wait $_resendCountdown seconds.');
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      String newOtp = _generateOTP();

      // Determine which function to call based on userType
      String functionName =
          userType == 'Admin' ? 'sendAdminOtp' : 'sendSignupOtp';
      final callable = _functions.httpsCallable(functionName);

      final result = await callable.call({
        'email': email,
        'otp': newOtp,
        if (userType != 'Admin') 'userType': userType,
      });

      if (result.data['success'] == true) {
        await _firestore.collection('AdminOTPs').doc(email).set({
          'OTP': newOtp,
          'Email': email,
          'UserType': userType,
          'CreatedAt': FieldValue.serverTimestamp(),
          'ExpiresAt': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: 2)),
          ),
          'Used': false,
        });

        _showSuccessSnackBar('✅ A new verification code has been sent.');
        _startResendTimer();
        _otpController.clear();
      }
    } catch (e) {
      _showErrorDialog('Failed to send new OTP: ${e.toString()}');
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _sendCompanyEmails(
      String email, String companyName, String name) async {
    try {
      // 1. Send document request to company
      final docRequestCallable =
          _functions.httpsCallable('sendCompanyDocumentRequest');
      await docRequestCallable.call({
        'email': email,
        'companyName': companyName,
      });

      // 2. Notify admin about new company
      final adminNotifyCallable =
          _functions.httpsCallable('notifyAdminNewCompany');
      await adminNotifyCallable.call({
        'email': email,
        'companyName': companyName,
        'name': name,
      });

      print('✅ Company emails sent successfully');
    } catch (e) {
      print('⚠️ Error sending company emails: $e');
      // Don't block the flow if emails fail
    }
  }

  Future<void> _verifyOTP(String email, String userId, String userType) async {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('Please enter the verification code.');
      return;
    }

    if (_otpController.text.length != 6) {
      _showErrorDialog('The verification code must be 6 digits.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot otpDoc =
          await _firestore.collection('AdminOTPs').doc(email).get();

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
        _showErrorDialog('This code has already been used. Request a new one.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (DateTime.now().isAfter(expiresAt.toDate())) {
        _showErrorDialog(
            'The code has expired. Please click "Resend Code" to get a new one.');
        await _firestore.collection('AdminOTPs').doc(email).delete();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_otpController.text.trim() == savedOTP) {
        // Mark OTP as used
        await _firestore.collection('AdminOTPs').doc(email).update({
          'Used': true,
        });

        // Update IsEmailVerified
        await _firestore.collection('Users').doc(userId).update({
          'IsEmailVerified': true,
          'lastLoginTime': FieldValue.serverTimestamp(),
        });

        // Handle different user types
        if (userType == 'Admin') {
          _showSuccessSnackBar('✅ Verification successful!');
          await Future.delayed(Duration(milliseconds: 500));
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else if (userType == 'Company') {
          // Get company details for emails
          DocumentSnapshot userDoc =
              await _firestore.collection('Users').doc(userId).get();
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          String companyName = userData['CompanyName'] ?? '';
          String name = userData['Name'] ?? '';

          // Send emails to company and admin
          await _sendCompanyEmails(email, companyName, name);

          setState(() {
            _isLoading = false;
          });

          _showSuccessDialog(
            'Your email has been verified successfully!\n\nPlease check your email for instructions on submitting company verification documents.\n\nYour account is currently pending approval.',
            () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          );
        } else if (userType == 'JobSeeker') {
          _showSuccessSnackBar('✅ Verification successful!');
          await Future.delayed(Duration(milliseconds: 500));
          Navigator.pushReplacementNamed(context, '/jobseeker-home');
        }

        // Delete OTP document
        await _firestore.collection('AdminOTPs').doc(email).delete();
      } else {
        _showErrorDialog('Incorrect verification code. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String email = args['email'];
    final String userId = args['userId'];
    final String userType = args['userType'] ?? 'Admin';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF4A5FBC)),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            await _firestore.collection('AdminOTPs').doc(email).delete();

            // Delete user document if verification not completed
            await _firestore.collection('Users').doc(userId).delete();

            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 30),

              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5FBC),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'A 6-digit verification code has been sent to your email.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),

              // OTP Input Field
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(0xFF4A5FBC),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    color: Color(0xFF4A5FBC),
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.grey[300],
                      letterSpacing: 12,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_resendCountdown > 0)
                Text(
                  'You can resend the code in: ${_formatTime(_resendCountdown)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              SizedBox(height: 24),

              // Verify Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF4A5FBC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF4A5FBC).withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _verifyOTP(email, userId, userType),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 16),

              // Resend Button
              TextButton.icon(
                onPressed: (_isResending || _resendCountdown > 0)
                    ? null
                    : () => _resendOTP(email, userType),
                icon: _isResending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4A5FBC),
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        color: _resendCountdown > 0
                            ? Colors.grey
                            : Color(0xFF4A5FBC),
                      ),
                label: Text(
                  'Resend Code',
                  style: TextStyle(
                    color:
                        _resendCountdown > 0 ? Colors.grey : Color(0xFF4A5FBC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Info Box
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The verification code is valid for 2 minutes only.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
