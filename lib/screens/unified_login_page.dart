import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

class UnifiedLoginPage extends StatefulWidget {
  final String schoolCode;
  
  const UnifiedLoginPage({
    super.key,
    required this.schoolCode,
  });

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPassword = false;
  bool _forgotPassword = false;
  bool _otpSent = false;
  bool _mobileValidated = false;
  bool _showUserTypeDropdown = false;
  bool _showLoginMethodDropdown = false;
  bool _showStudentModal = false;
  bool _showPWAHelp = false;
  
  String _authStep = "login"; // login, forgotOtp, resetPassword, otpLogin, otpVerify
  String _userType = "student"; // student, staff, admin
  String _loginMethod = "otp"; // password, otp
  
  int _otpResendTimer = 0;
  int? _attemptsRemaining;
  String _loginError = "";
  
  Map<String, dynamic>? _schoolInfo;
  List<dynamic> _studentOptions = [];
  dynamic _matchedStudent;
  
  // API base URL - you'll need to replace this with your actual API URI
  static const String API_URI = 'https://your-api-domain.com';

  @override
  void initState() {
    super.initState();
    _getSchool();
    _startOtpTimer();
  }

  void _startOtpTimer() {
    if (_otpResendTimer > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _otpResendTimer--;
          });
          _startOtpTimer();
        }
      });
    }
  }

  Future<void> _getSchool() async {
    try {
      final response = await http.get(
        Uri.parse('$API_URI/api/school-admin/getbyuserid/${widget.schoolCode}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('schoolCode', jsonEncode(data['data']));
        setState(() {
          _schoolInfo = data['data'];
        });
      } else {
        Fluttertoast.showToast(
          msg: "Invalid URL.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to verify URL. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _handleUserTypeChange(String type) {
    setState(() {
      _userType = type;
      _userIdController.clear();
      _passwordController.clear();
      _otpController.clear();
      _forgotPassword = false;
      _otpSent = false;
      _authStep = "login";
      _loginMethod = type == "student" ? "otp" : "password";
      _mobileValidated = false;
      _otpResendTimer = 0;
      _showUserTypeDropdown = false;
      _showLoginMethodDropdown = false;
      _loginError = "";
    });
  }

  void _handleLoginMethodChange(String method) {
    setState(() {
      _loginMethod = method;
      _passwordController.clear();
      _otpController.clear();
      _authStep = "login";
      _mobileValidated = false;
      _otpResendTimer = 0;
      _showLoginMethodDropdown = false;
      _loginError = "";
    });
  }

  bool _validateMobile(String mobile) {
    final mobileRegex = RegExp(r'^[6-9]\d{9}$');
    return mobileRegex.hasMatch(mobile);
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$');
    return emailRegex.hasMatch(email);
  }

  bool _validateUserId(String userId) {
    if (userId.trim().isEmpty) return false;
    
    if (_userType == "student" && _loginMethod == "otp") {
      return _validateMobile(userId);
    }
    
    return true;
  }

  bool _validatePassword(String password) {
    return password.trim().isNotEmpty && password.length >= 6;
  }

  bool _validateOTP(String otp) {
    final otpRegex = RegExp(r'^\d{6}$');
    return otpRegex.hasMatch(otp);
  }

  Future<void> _handleSendOtp() async {
    final userId = _userIdController.text;
    
    if (!_validateMobile(userId)) {
      Fluttertoast.showToast(
        msg: "Please enter a valid 10-digit mobile number starting with 6-9.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String endpoint;
      Map<String, dynamic> payload;

      switch (_userType) {
        case "student":
          endpoint = "/api/student/OTPLogin";
          payload = {
            "schoolCode": widget.schoolCode,
            "mobile": userId,
          };
          break;
        default:
          throw Exception("OTP login currently only supported for students");
      }

      final response = await http.post(
        Uri.parse('$API_URI$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Fluttertoast.showToast(
          msg: data['message'] ?? "OTP sent successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        
        if (data['attemptsRemaining'] != null) {
          setState(() {
            _attemptsRemaining = data['attemptsRemaining'];
          });
          Fluttertoast.showToast(
            msg: "Attempts remaining: ${data['attemptsRemaining']}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
        
        setState(() {
          _mobileValidated = true;
          _otpResendTimer = 60;
          _authStep = "otpVerify";
        });
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? "Failed to send OTP";
        
        if (response.statusCode == 429) {
          Fluttertoast.showToast(
            msg: errorMessage,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        } else if (response.statusCode == 404) {
          Fluttertoast.showToast(
            msg: "Mobile number not found in our records. Please contact your school administrator.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        } else {
          Fluttertoast.showToast(
            msg: errorMessage,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to send OTP",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleSubmit() async {
    final userId = _userIdController.text;
    final password = _passwordController.text;
    final otp = _otpController.text;
    
    if (userId.isEmpty) {
      Fluttertoast.showToast(
        msg: "User ID is required.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    
    if (_loginMethod == "password") {
      if (password.isEmpty) {
        Fluttertoast.showToast(
          msg: "Password is required.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
    } else {
      if (otp.isEmpty) {
        Fluttertoast.showToast(
          msg: "OTP is required.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      http.Response response;
      String endpoint;
      String localStorageKey;
      String tokenKey;
      String redirectPath;
      Map<String, dynamic> payload;

      if (_loginMethod == "password") {
        // Password-based login
        switch (_userType) {
          case "admin":
            endpoint = "/api/school-admin/login";
            localStorageKey = "school_admin";
            tokenKey = "school_admin_token";
            redirectPath = "/school-admin/dashboard";
            payload = {
              "userId": userId,
              "password": password,
            };
            break;

          case "staff":
            endpoint = "/api/teacher/login";
            localStorageKey = "school_teacher";
            tokenKey = "school_teacher_token";
            redirectPath = "/staff/dashboard";
            payload = {
              "userId": userId,
              "password": password,
            };
            break;

          case "student":
            endpoint = "/api/student/login";
            localStorageKey = "school_student";
            tokenKey = "school_student_token";
            redirectPath = "/student/dashboard";
            payload = {
              "schoolCode": widget.schoolCode,
              "userId": userId,
              "password": password,
            };
            break;

          default:
            throw Exception("Invalid user type");
        }
      } else {
        // OTP-based login (only available for students currently)
        switch (_userType) {
          case "student":
            endpoint = "/api/student/verify-mobile-otp";
            localStorageKey = "school_student";
            tokenKey = "school_student_token";
            redirectPath = "/student/dashboard";
            payload = {
              "schoolCode": widget.schoolCode,
              "mobile": userId,
              "otp": otp,
            };
            break;

          default:
            throw Exception("OTP login currently only supported for students");
        }
      }

      response = await http.post(
        Uri.parse('$API_URI$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['data'];
        
        // Handle multiple students case for student login
        if (_userType == "student" && userData['studentsInCurrentSession'] != null) {
          setState(() {
            _studentOptions = userData['studentsInCurrentSession'];
            _matchedStudent = userData['matchedStudentId'];
            _showStudentModal = true;
            _isLoading = false;
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(localStorageKey, jsonEncode(userData));
        await prefs.setString(tokenKey, userData['tokens']['accessToken']);
        await prefs.setString("login_time", DateTime.now().millisecondsSinceEpoch.toString());
        
        // Navigate to appropriate dashboard
        // Navigator.pushReplacementNamed(context, redirectPath);
        Fluttertoast.showToast(
          msg: "Login successful!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? "Error in sign in";
        setState(() {
          _loginError = errorMessage;
        });
        Fluttertoast.showToast(
          msg: errorMessage,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (error) {
      setState(() {
        _loginError = "Login failed";
      });
      Fluttertoast.showToast(
        msg: "Login failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleStudentSelection(dynamic student) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse('$API_URI/api/student/loginFromMultiple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userId": student['_id']}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("school_student", jsonEncode(data['data']));
        await prefs.setString("school_student_token", data['data']['tokens']['accessToken']);
        await prefs.setString("login_time", DateTime.now().millisecondsSinceEpoch.toString());
        
        setState(() {
          _showStudentModal = false;
          _isLoading = false;
        });
        
        // Navigate to student dashboard
        // Navigator.pushReplacementNamed(context, '/student/dashboard');
        Fluttertoast.showToast(
          msg: "Login successful!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Error in sign in",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Login failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  void _handleWhatsAppSupport() {
    final message = 'Hi! I need help with CampusConnect login for school code: ${widget.schoolCode}';
    final whatsappUrl = 'https://wa.me/919561222438?text=${Uri.encodeComponent(message)}';
    // You can use url_launcher package to open external URLs
    // launchUrl(Uri.parse(whatsappUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          ),
        ),
        child: Row(
          children: [
            // Left Side - Desktop Only
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/campus_background.jpg'),
                    fit: BoxFit.cover,
                    opacity: 0.2,
                  ),
                ),
                child: Container(
                  color: Colors.blue.withOpacity(0.8),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Title
                                const Text(
                                  'CampusConnect',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'The most advanced AI-powered ERP solution for schools, colleges, universities, coaching centers & preschools.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                
                                // School Code
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'School Code',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.schoolCode,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Security Info
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Security & Compliance',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSecurityItem('🛡️ SSL Encrypted:', '256-bit encryption'),
                                      _buildSecurityItem('🔒 GDPR Compliant:', 'Data protection certified'),
                                      _buildSecurityItem('✅ ISO 27001:', 'Information security'),
                                      _buildSecurityItem('🛡️ SOC 2 Type II:', 'Security audited'),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Trusted & Secure Platform',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Footer
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '© 2025 AppTestify Global Services Pvt. Ltd. | IQLEXA Technologies Private Limited',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'CampusConnect is a product of AppTestify Global Services Pvt. Ltd. | IQLEXA Technologies Private Limited',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Visit our website: campusconnecthub.com',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const Text(
                              'Support: +91-9561222438',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Right Side - Login Form
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: SizedBox(
                      width: 400,
                      child: Column(
                        children: [
                          // School Information
                          if (_schoolInfo != null) ...[
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: _schoolInfo!['applogo'] != null ||
                                      _schoolInfo!['adminlogo'] != null ||
                                      _schoolInfo!['adminsmalllogo'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: Image.network(
                                        _schoolInfo!['applogo'] ??
                                            _schoolInfo!['adminlogo'] ??
                                            _schoolInfo!['adminsmalllogo'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              _schoolInfo!['schoolName']?.substring(0, 1).toUpperCase() ?? 'S',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _schoolInfo!['schoolName']?.substring(0, 1).toUpperCase() ?? 'S',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _schoolInfo!['schoolName'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                          ],
                          
                          // Login Form
                          _buildLoginForm(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Log in to your account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Welcome back! Please log in to your account.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        
        // Install App Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Handle PWA install
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Install App'),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showPWAHelp = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              child: const Text('Guide'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // User Type Selection
        _buildUserTypeDropdown(),
        const SizedBox(height: 16),
        
        // Login Method Selection (for students only)
        if (_userType == "student") ...[
          _buildLoginMethodDropdown(),
          const SizedBox(height: 16),
        ],
        
        // User ID/Mobile Input
        _buildUserIdInput(),
        const SizedBox(height: 16),
        
        // Password/OTP Input
        if (_loginMethod == "password")
          _buildPasswordInput()
        else
          _buildOtpInput(),
        const SizedBox(height: 16),
        
        // Action Buttons
        _buildActionButtons(),
        
        // Login Error
        if (_loginError.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loginError,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Forgot Password Link
        if (!_forgotPassword && !_otpSent && _loginMethod == "password") ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _forgotPassword = true;
                });
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ),
        ],
        
        // WhatsApp Support
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _handleWhatsAppSupport,
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Need Help? Chat with Support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeDropdown() {
    final userRoleOptions = [
      {
        'value': 'student',
        'label': 'Student',
        'icon': Icons.school,
        'color': Colors.green,
        'description': 'Access student portal'
      },
      {
        'value': 'staff',
        'label': 'Staff',
        'icon': Icons.person,
        'color': Colors.orange,
        'description': 'Access staff portal'
      },
      {
        'value': 'admin',
        'label': 'Admin',
        'icon': Icons.admin_panel_settings,
        'color': Colors.blue,
        'description': 'Access admin portal'
      }
    ];

    final selectedOption = userRoleOptions.firstWhere(
      (option) => option['value'] == _userType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select User Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            setState(() {
              _showUserTypeDropdown = !_showUserTypeDropdown;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorFromString(selectedOption['color']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    selectedOption['icon'] as IconData,
                    color: _getColorFromString(selectedOption['color']),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedOption['label'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        selectedOption['description'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showUserTypeDropdown ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (_showUserTypeDropdown) ...[
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: userRoleOptions.map((option) {
                return InkWell(
                  onTap: () {
                    _handleUserTypeChange(option['value'] as String);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getColorFromString(option['color']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            option['icon'] as IconData,
                            color: _getColorFromString(option['color']),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['label'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                option['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_userType == option['value'])
                          const Icon(Icons.check, color: Colors.green, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginMethodDropdown() {
    final loginMethodOptions = [
      {
        'value': 'password',
        'label': 'Password Login',
        'icon': Icons.lock,
        'description': 'Login with username and password'
      },
      {
        'value': 'otp',
        'label': 'OTP Login',
        'icon': Icons.phone,
        'description': 'Login with mobile number and OTP'
      }
    ];

    final selectedOption = loginMethodOptions.firstWhere(
      (option) => option['value'] == _loginMethod,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Login Method',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            setState(() {
              _showLoginMethodDropdown = !_showLoginMethodDropdown;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    selectedOption['icon'] as IconData,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedOption['label'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        selectedOption['description'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showLoginMethodDropdown ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (_showLoginMethodDropdown) ...[
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: loginMethodOptions.map((option) {
                return InkWell(
                  onTap: () {
                    _handleLoginMethodChange(option['value'] as String);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            option['icon'] as IconData,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['label'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                option['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_loginMethod == option['value'])
                          const Icon(Icons.check, color: Colors.green, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUserIdInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (_userType == "student" && _loginMethod == "otp") ? "Mobile Number" : "User ID",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _userIdController,
          keyboardType: (_userType == "student" && _loginMethod == "otp") ? TextInputType.phone : TextInputType.text,
          decoration: InputDecoration(
            hintText: (_userType == "student" && _loginMethod == "otp") 
                ? "Enter your 10-digit mobile number" 
                : "Enter your user ID",
            prefixIcon: Icon(
              (_userType == "student" && _loginMethod == "otp") ? Icons.phone : Icons.person,
              color: Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            hintText: "Enter your password",
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[400],
              ),
              onPressed: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OTP Code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Enter 6-digit OTP",
            prefixIcon: const Icon(Icons.security, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_loginMethod == "otp") {
      if (!_mobileValidated) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || !_validateUserId(_userIdController.text) 
                ? null 
                : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, size: 20),
                      SizedBox(width: 8),
                      Text('Send OTP'),
                    ],
                  ),
          ),
        );
      } else {
        return Column(
          children: [
            if (_attemptsRemaining != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Attempts remaining: $_attemptsRemaining',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || !_validateOTP(_otpController.text) 
                    ? null 
                    : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 20),
                          SizedBox(width: 8),
                          Text('Verify OTP & Login'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _otpResendTimer > 0 ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _otpResendTimer > 0 ? 'Resend in ${_otpResendTimer}s' : 'Resend OTP',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mobileValidated = false;
                        _authStep = "login";
                        _otpResendTimer = 0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Change Mobile'),
                  ),
                ),
              ],
            ),
          ],
        );
      }
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading || 
              !_validateUserId(_userIdController.text) || 
              !_validatePassword(_passwordController.text) 
              ? null 
              : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 20),
                    const SizedBox(width: 8),
                    Text('Login as ${_userType.toUpperCase()}'),
                  ],
                ),
        ),
      );
    }
  }

  Color _getColorFromString(dynamic color) {
    if (color == 'green') return Colors.green;
    if (color == 'orange') return Colors.orange;
    if (color == 'blue') return Colors.blue;
    return Colors.grey;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
