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

  // Timer للعد التنازلي
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
      _resendCountdown = 120; // دقيقتين
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
        title: Text('خطأ', textDirection: TextDirection.rtl),
        content: Text(message, textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // توليد OTP جديد
  String _generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // إعادة إرسال OTP
  Future<void> _resendOTP(String email) async {
    if (_resendCountdown > 0) {
      _showErrorDialog(
          'الرمز الحالي لم تنتهِ صلاحيته بعد. انتظر $_resendCountdown ثانية');
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      String newOtp = _generateOTP();

      // إرسال OTP الجديد
      final callable = _functions.httpsCallable('sendAdminOtp');
      final result = await callable.call({
        'email': email,
        'otp': newOtp,
      });

      if (result.data['success'] == true) {
        // ✅ تحديث OTP في AdminOTPs collection
        await _firestore.collection('AdminOTPs').doc(email).set({
          'OTP': newOtp,
          'Email': email,
          'CreatedAt': FieldValue.serverTimestamp(),
          'ExpiresAt': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: 2)),
          ),
          'Used': false,
        });

        _showSuccessSnackBar('✅ تم إرسال رمز تحقق جديد');
        _startResendTimer();
        _otpController.clear();
      }
    } catch (e) {
      _showErrorDialog('فشل إرسال الرمز الجديد: ${e.toString()}');
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _verifyOTP(String email, String userId) async {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('الرجاء إدخال رمز التحقق');
      return;
    }

    if (_otpController.text.length != 6) {
      _showErrorDialog('رمز التحقق يجب أن يكون 6 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ نجيب الـ OTP من AdminOTPs collection
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
      String savedOTP = otpData['OTP'];
      Timestamp expiresAt = otpData['ExpiresAt'];
      bool used = otpData['Used'] ?? false;

      // نتحقق من أن الرمز لم يُستخدم من قبل
      if (used) {
        _showErrorDialog('هذا الرمز تم استخدامه مسبقاً. اطلب رمز جديد.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // نتحقق من صلاحية الوقت
      if (DateTime.now().isAfter(expiresAt.toDate())) {
        _showErrorDialog(
            'انتهت صلاحية الرمز. اضغط "إعادة الإرسال" للحصول على رمز جديد.');
        // ✅ مسح OTP المنتهي
        await _firestore.collection('AdminOTPs').doc(email).delete();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // نتحقق من الرمز
      if (_otpController.text.trim() == savedOTP) {
        // ✅ الرمز صحيح - نحدث حالة Used
        await _firestore.collection('AdminOTPs').doc(email).update({
          'Used': true,
        });

        await _firestore.collection('Users').doc(userId).update({
          'lastLoginTime': FieldValue.serverTimestamp(),
        });

        _showSuccessSnackBar('✅ تم التحقق بنجاح!');

        // انتظار قصير لعرض الرسالة
        await Future.delayed(Duration(milliseconds: 500));

        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      } else {
        _showErrorDialog('رمز التحقق غير صحيح. تأكد من الرمز وحاول مرة أخرى.');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF4A5FBC)),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            // ✅ حذف OTP عند الرجوع
            await _firestore.collection('AdminOTPs').doc(email).delete();
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
                Icons.mark_email_read,
                size: 80,
                color: Color(0xFF4A5FBC),
              ),
              SizedBox(height: 30),
              Text(
                'تحقق من بريدك الإلكتروني',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5FBC),
                ),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 16),
              Text(
                'تم إرسال رمز التحقق المكون من 6 أرقام إلى:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF4A5FBC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5FBC),
                  ),
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
                  'يمكنك إعادة الإرسال بعد: ${_formatTime(_resendCountdown)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textDirection: TextDirection.rtl,
                ),
              SizedBox(height: 24),
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
              SizedBox(height: 16),
              TextButton.icon(
                onPressed: (_isResending || _resendCountdown > 0)
                    ? null
                    : () => _resendOTP(email),
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
                  'إعادة إرسال الرمز',
                  style: TextStyle(
                    color:
                        _resendCountdown > 0 ? Colors.grey : Color(0xFF4A5FBC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 24),
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
                        'رمز التحقق صالح لمدة دقيقتين فقط',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                        textDirection: TextDirection.rtl,
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
