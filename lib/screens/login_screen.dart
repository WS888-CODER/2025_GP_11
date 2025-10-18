import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Error', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4A5FBC))),
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

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<bool> _sendOTPEmail(String email, String otp) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('sendAdminOtp');

      final result = await callable.call({
        'email': email.trim(),
        'otp': otp.trim(),
      });

      if (result.data != null && result.data['success'] == true) {
        await _firestore.collection('AdminOTPs').doc(email).set({
          'OTP': otp,
          'Email': email,
          'CreatedAt': FieldValue.serverTimestamp(),
          'ExpiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 2)),
          ),
          'Used': false,
        });
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;

      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        _showErrorDialog('User data not found');
        setState(() => _isLoading = false);
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final userType = data['UserType'] ?? data['userType'] ?? '';

      final isEmailVerified =
          data['IsEmailVerified'] ?? data['isEmailVerified'] ?? false;
      final accountStatus =
          data['AccountStatus'] ?? data['accountStatus'] ?? 'Pending';

      // Admin → OTP
      if (userType == 'Admin') {
        final otp = _generateOTP();
        final ok = await _sendOTPEmail(_emailController.text.trim(), otp);
        if (ok) {
          _showSuccessSnackBar('✅ Verification code sent to your email');
          Navigator.pushReplacementNamed(
            context,
            '/otp-verification',
            arguments: {'email': _emailController.text.trim(), 'userId': userId},
          );
        } else {
          await _auth.signOut();
          _showErrorDialog(
              'Failed to send verification code. Please try again later.');
        }
        setState(() => _isLoading = false);
        return;
      }

      // JobSeeker
      if (userType == 'JobSeeker') {
        if (isEmailVerified) {
          Navigator.pushReplacementNamed(
            context,
            '/jobseeker-home',
            arguments: {'userId': userId},
          );
        } else {
          await _auth.signOut();
          _showErrorDialog('Please verify your email first. Check your inbox.');
        }
        setState(() => _isLoading = false);
        return;
      }

      // Company
      if (userType == 'Company') {
        if (!isEmailVerified) {
          await _auth.signOut();
          _showErrorDialog('Please verify your email first. Check your inbox.');
        } else if (accountStatus == 'Verified') {
          Navigator.pushReplacementNamed(
            context,
            '/company-home',
            arguments: {'companyId': userId},
          );
        } else if (accountStatus == 'Pending') {
          await _auth.signOut();
          _showErrorDialog(
              'Your account is pending approval from admin. Please wait.');
        } else if (accountStatus == 'Rejected') {
          await _auth.signOut();
          _showErrorDialog('Your account has been rejected. Contact support.');
        }
        setState(() => _isLoading = false);
        return;
      }

      // Unknown
      await _auth.signOut();
      _showErrorDialog('Unknown user type: "$userType"');
    } on FirebaseAuthException catch (e) {
      var msg = 'An error occurred during login';
      if (e.code == 'user-not-found') msg = 'Email not registered';
      else if (e.code == 'wrong-password') msg = 'Incorrect password';
      else if (e.code == 'invalid-email') msg = 'Invalid email format';
      else if (e.code == 'user-disabled') msg = 'This account has been disabled';
      else if (e.code == 'invalid-credential') msg = 'Invalid email or password';
      _showErrorDialog(msg);
    } catch (e) {
      _showErrorDialog('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5FBC)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Image.asset('assets/images/logo.jpg',
                    height: 120, width: 120, fit: BoxFit.contain),
                const SizedBox(height: 30),
                const Text('Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A5FBC),
                    )),
                const SizedBox(height: 8),
                Text('Login to continue',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 40),

                // Email
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Email',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7B7B))),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF4A5FBC), width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Password
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Password',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7B7B))),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF4A5FBC), width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF4A5FBC),
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('Forgot Password?',
                        style: TextStyle(
                            color: Color(0xFF4A5FBC),
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ),

                const SizedBox(height: 40),

                // Login Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5FBC),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A5FBC).withOpacity(.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Log In',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 20),

                // Go to Signup
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Don\'t have an account? ',
                        style: TextStyle(color: Colors.grey[600])),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/signup'),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: Color(0xFF4A5FBC),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
