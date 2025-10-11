// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<bool> _sendOTPEmail(String email, String otp) async {
    try {
      print('🔵 Starting to send OTP...');
      print('🔵 Email: $email');
      print('🔵 OTP: $otp');

      // ✅ التعديل: حددت الـ region بوضوح
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendAdminOtp');

      print('🔵 Calling Cloud Function...');
      final result = await callable.call({
        'email': email,
        'otp': otp,
      });

      print('🔵 Cloud Function response: ${result.data}');

      await _firestore.collection('AdminOTPs').doc(email).set({
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: 2)),
        ),
        'used': false,
      });

      print('✅ SUCCESS! OTP saved to Firestore and email sent!');
      return true;
    } catch (e) {
      print('❌ FULL ERROR: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is FirebaseFunctionsException) {
        print('❌ Firebase Functions Error Code: ${e.code}');
        print('❌ Firebase Functions Error Message: ${e.message}');
        print('❌ Firebase Functions Error Details: ${e.details}');
      }
      return false;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String userId = userCredential.user!.uid;

      DocumentSnapshot userDoc =
          await _firestore.collection('Users').doc(userId).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        _showErrorDialog('User data not found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String userType = userData['UserType'] ?? userData['userType'] ?? '';

      print('🟢 User Type: $userType');

      if (userType == 'Admin') {
        print('🟢 Admin detected! Sending OTP...');
        String otp = _generateOTP();
        bool otpSent = await _sendOTPEmail(_emailController.text.trim(), otp);

        if (otpSent) {
          _showSuccessSnackBar('✅ Verification code sent to your email');

          Navigator.pushReplacementNamed(
            context,
            '/otp-verification',
            arguments: {
              'email': _emailController.text.trim(),
              'userId': userId,
            },
          );
        } else {
          await _auth.signOut();
          _showErrorDialog(
              'Failed to send verification code. Check console for details.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      bool isEmailVerified = userData['isEmailVerified'] ?? false;
      String accountStatus = userData['accountStatus'] ?? 'Pending';

      if (userType == 'JobSeeker') {
        if (isEmailVerified) {
          Navigator.pushReplacementNamed(context, '/jobseeker-home');
        } else {
          await _auth.signOut();
          _showErrorDialog('Please verify your email first. Check your inbox.');
        }
      } else if (userType == 'Company') {
        if (!isEmailVerified) {
          await _auth.signOut();
          _showErrorDialog('Please verify your email first. Check your inbox.');
        } else if (accountStatus == 'Verified') {
          Navigator.pushReplacementNamed(context, '/company-home');
        } else if (accountStatus == 'Pending') {
          await _auth.signOut();
          _showErrorDialog(
              'Your account is pending approval from admin. Please wait for confirmation.');
        } else if (accountStatus == 'Rejected') {
          await _auth.signOut();
          _showErrorDialog(
              'Your account has been rejected. Please contact support.');
        }
      } else {
        await _auth.signOut();
        _showErrorDialog('Unknown user type: "$userType"');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during login';

      if (e.code == 'user-not-found') {
        errorMessage = 'Email not registered';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password';
      }

      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('Unexpected error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                SizedBox(height: 20),
                Image.asset(
                  'assets/images/logo.jpg',
                  width: 200,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 60),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF7B7B),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFF4A5FBC),
                      width: 2,
                    ),
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
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF7B7B),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFF4A5FBC),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Color(0xFF4A5FBC),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
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
                    onPressed: _isLoading ? null : _handleLogin,
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
                            'Log In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
