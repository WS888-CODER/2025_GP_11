// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OTPVerificationScreen extends StatefulWidget {
  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
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

  Future<void> _verifyOTP(String email, String userId) async {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('الرجاء إدخال رمز التحقق');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // نجيب الـ OTP من Firestore
      DocumentSnapshot otpDoc =
          await _firestore.collection('AdminOTPs').doc(email).get();

      if (!otpDoc.exists) {
        _showErrorDialog('رمز التحقق غير موجود. حاول تسجيل الدخول مرة أخرى.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> otpData = otpDoc.data() as Map<String, dynamic>;
      String savedOTP = otpData['otp'];
      int expiresAt = otpData['expiresAt'];

      // نتحقق من صلاحية الوقت
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        _showErrorDialog('انتهت صلاحية الرمز. حاول تسجيل الدخول مرة أخرى.');
        await _firestore.collection('AdminOTPs').doc(email).delete();
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // نتحقق من الرمز
      if (_otpController.text.trim() == savedOTP) {
        // الرمز صحيح - نحذف OTP ونروح للداشبورد
        await _firestore.collection('AdminOTPs').doc(email).delete();

        // نحفظ وقت تسجيل الدخول
        await _firestore.collection('Users').doc(userId).update({
          'lastLoginTime': FieldValue.serverTimestamp(),
        });

        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      } else {
        _showErrorDialog('رمز التحقق غير صحيح');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String email = args['email'];
    final String userId = args['userId'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF4A5FBC)),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
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
              Icon(
                Icons.security,
                size: 80,
                color: Color(0xFF4A5FBC),
              ),
              SizedBox(height: 30),
              Text(
                'تحقق من هويتك',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5FBC),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'تم إرسال رمز التحقق إلى',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A5FBC),
                ),
              ),
              SizedBox(height: 40),
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(color: Colors.grey[300]),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              SizedBox(height: 40),
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
                  onPressed:
                      _isLoading ? null : () => _verifyOTP(email, userId),
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
                          'تحقق',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
