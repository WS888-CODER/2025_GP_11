import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _selectedTab = 0; // 0 = Company, 1 = Job Seeker
  final _formKey = GlobalKey<FormState>();

  // Controllers for Company
  final _companyNameController = TextEditingController();
  final _companyFullNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPasswordController = TextEditingController();

  // Controllers for Job Seeker
  final _seekerNameController = TextEditingController();
  final _seekerEmailController = TextEditingController();
  final _seekerPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyFullNameController.dispose();
    _companyEmailController.dispose();
    _companyPasswordController.dispose();
    _seekerNameController.dispose();
    _seekerEmailController.dispose();
    _seekerPasswordController.dispose();
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

  void _showSuccessDialog(String message) {
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

  // Validate name (no numbers or special characters)
  bool _isValidName(String name) {
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    return nameRegex.hasMatch(name);
  }

  // ✅ التعديل الجديد: فحص الإيميل من Firebase Auth مباشرة
  Future<bool> _isEmailUnique(String email) async {
    try {
      // نجرب نحصل على methods للإيميل
      final methods = await _auth.fetchSignInMethodsForEmail(email.trim());

      // إذا methods فاضية = الإيميل مش مسجل ✅
      // إذا methods فيها قيم = الإيميل مسجل ❌
      return methods.isEmpty;
    } catch (e) {
      print('❌ Error checking email: $e');
      // في حالة الـ error، نرجع false عشان نكون على الجانب الآمن
      return false;
    }
  }

  Future<bool> _sendOTPEmail(String email, String otp, String userType) async {
    try {
      print('📧 Sending OTP to: $email');
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('sendSignupOtp');

      final result = await callable.call({
        'email': email.trim(),
        'otp': otp.trim(),
        'userType': userType,
      });

      if (result.data != null && result.data['success'] == true) {
        await _firestore.collection('AdminOTPs').doc(email).set({
          'OTP': otp,
          'Email': email,
          'UserType': userType,
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

  Future<void> _handleCompanySignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate name
      if (!_isValidName(_companyFullNameController.text.trim())) {
        _showErrorDialog('Name cannot contain numbers or special characters');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check email uniqueness
      bool isUnique = await _isEmailUnique(_companyEmailController.text.trim());
      if (!isUnique) {
        _showErrorDialog('This email is already registered');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _companyEmailController.text.trim(),
        password: _companyPasswordController.text.trim(),
      );

      String userId = userCredential.user!.uid;

      // Create user document in Firestore
      await _firestore.collection('Users').doc(userId).set({
        'UserID': userId,
        'UserType': 'Company',
        'Email': _companyEmailController.text.trim(),
        'Name': _companyFullNameController.text.trim(),
        'CompanyName': _companyNameController.text.trim(),
        'DoB': null,
        'Nationality': null,
        'Phone': null,
        'PhotoURL': null,
        'CVURL': null,
        'IsProfileComplete': false,
        'CVKeywords': null,
        'ContactEmail': null,
        'Location': null,
        'Description': null,
        'AccountStatus': 'Pending',
        'IsEmailVerified': false,
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      // Generate and send OTP
      String otp = _generateOTP();
      bool otpSent = await _sendOTPEmail(
          _companyEmailController.text.trim(), otp, 'Company');

      if (otpSent) {
        // Navigate to OTP verification
        Navigator.pushReplacementNamed(
          context,
          '/otp-verification',
          arguments: {
            'email': _companyEmailController.text.trim(),
            'userId': userId,
            'userType': 'Company',
          },
        );
      } else {
        // Delete created user if OTP failed
        await userCredential.user!.delete();
        await _firestore.collection('Users').doc(userId).delete();
        _showErrorDialog('Failed to send verification code. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during signup';

      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
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

  Future<void> _handleJobSeekerSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate name
      if (!_isValidName(_seekerNameController.text.trim())) {
        _showErrorDialog('Name cannot contain numbers or special characters');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check email uniqueness
      bool isUnique = await _isEmailUnique(_seekerEmailController.text.trim());
      if (!isUnique) {
        _showErrorDialog('This email is already registered');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _seekerEmailController.text.trim(),
        password: _seekerPasswordController.text.trim(),
      );

      String userId = userCredential.user!.uid;

      // Create user document in Firestore
      await _firestore.collection('Users').doc(userId).set({
        'UserID': userId,
        'UserType': 'JobSeeker',
        'Email': _seekerEmailController.text.trim(),
        'Name': _seekerNameController.text.trim(),
        'DoB': null,
        'Nationality': null,
        'Phone': null,
        'PhotoURL': null,
        'CVURL': null,
        'IsProfileComplete': false,
        'CVKeywords': null,
        'ContactEmail': null,
        'Location': null,
        'Description': null,
        'AccountStatus': null,
        'IsEmailVerified': false,
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      // Generate and send OTP
      String otp = _generateOTP();
      bool otpSent = await _sendOTPEmail(
          _seekerEmailController.text.trim(), otp, 'JobSeeker');

      if (otpSent) {
        // Navigate to OTP verification
        Navigator.pushReplacementNamed(
          context,
          '/otp-verification',
          arguments: {
            'email': _seekerEmailController.text.trim(),
            'userId': userId,
            'userType': 'JobSeeker',
          },
        );
      } else {
        // Delete created user if OTP failed
        await userCredential.user!.delete();
        await _firestore.collection('Users').doc(userId).delete();
        _showErrorDialog('Failed to send verification code. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during signup';

      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
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

  Widget _buildCompanyForm() {
    return Column(
      children: [
        // Company Name Field
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Company Name',
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _companyNameController,
            decoration: InputDecoration(
              hintText: 'Enter company name',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter company name';
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 24),

        // Full Name Field
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Full Name',
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _companyFullNameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 24),

        // Email Field
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _companyEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

        // Password Field
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _companyPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobSeekerForm() {
    return Column(
      children: [
        // Name Field
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Full Name',
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _seekerNameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 24),

        // Email Field
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _seekerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

        // Password Field
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
            border: Border.all(color: Color(0xFF4A5FBC), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _seekerPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
        ),
      ],
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
          child: Column(
            children: [
              SizedBox(height: 20),
              // Logo
              Image.asset(
                'assets/images/logo.jpg',
                width: 200,
                height: 100,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 40),

              // Tab Selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? Color(0xFF4A5FBC)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Company',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 0
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Color(0xFF4A5FBC)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Job Seeker',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 1
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),

              // Form
              Form(
                key: _formKey,
                child: _selectedTab == 0
                    ? _buildCompanyForm()
                    : _buildJobSeekerForm(),
              ),
              SizedBox(height: 40),

              // Sign Up Button
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
                      : (_selectedTab == 0
                          ? _handleCompanySignup
                          : _handleJobSeekerSignup),
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
                          'Sign Up',
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
    );
  }
}
