import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'unified_login_page.dart';

class SchoolCodePage extends StatefulWidget {
  const SchoolCodePage({super.key});

  @override
  State<SchoolCodePage> createState() => _SchoolCodePageState();
}

class _SchoolCodePageState extends State<SchoolCodePage> {
  final TextEditingController _schoolCodeController = TextEditingController();
  bool _isLoading = false;
  
  // API base URL - you'll need to replace this with your actual API URI
  static const String API_URI = 'https://your-api-domain.com';

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for student login
    if (prefs.getString('schoolCode') != null &&
        prefs.getString('school_student') != null &&
        prefs.getString('school_student_token') != null) {
      print("student login already exist");
      // Navigate to student dashboard
      // Navigator.pushReplacementNamed(context, '/student/dashboard');
      return;
    }
    
    // Check for teacher login
    if (prefs.getString('schoolCode') != null &&
        prefs.getString('school_teacher') != null &&
        prefs.getString('school_teacher_token') != null) {
      print("teacher login already exist");
      // Navigate to staff dashboard
      // Navigator.pushReplacementNamed(context, '/staff/dashboard');
      return;
    }
    
    // Check for admin login
    if (prefs.getString('schoolCode') != null &&
        prefs.getString('school_admin') != null &&
        prefs.getString('school_admin_token') != null) {
      print("school login already exist");
      final schoolCodeData = prefs.getString('schoolCode');
      if (schoolCodeData != null) {
        final schoolData = jsonDecode(schoolCodeData);
        // Navigate to school dashboard
        // Navigator.pushReplacementNamed(context, '/${schoolData['userId']}/school/dashboard');
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_schoolCodeController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter a school code",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$API_URI/api/school-admin/getbyuserid/${_schoolCodeController.text}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data['data']);
        final school = data['data'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('schoolCode', jsonEncode(school));

        Fluttertoast.showToast(
          msg: "School code verified successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to unified login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedLoginPage(schoolCode: _schoolCodeController.text),
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Invalid school code. Please try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to verify school code. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/campus_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main card
                  Container(
                    width: 380,
                    padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Logo - Custom Campus Connect logo
                        Container(
                          margin: const EdgeInsets.only(bottom: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Red-orange chevron arrows
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF6B35),
                                  borderRadius: BorderRadius.all(Radius.circular(4)),
                                ),
                                child: const Icon(
                                  Icons.keyboard_double_arrow_right,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Vertical line
                              Container(
                                width: 2,
                                height: 35,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 14),
                              // Campus Connect text
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Campus',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Text(
                                    'Connect',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF6B35),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Welcome text
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enter your school code to proceed.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // School code input
                        TextField(
                          controller: _schoolCodeController,
                          onChanged: (value) {
                            _schoolCodeController.text = value.toUpperCase();
                            _schoolCodeController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _schoolCodeController.text.length),
                            );
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter Your School Code',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: const BorderSide(color: Colors.grey, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoading 
                                  ? Colors.grey[300] 
                                  : const Color(0xFF2C3E50),
                              foregroundColor: _isLoading 
                                  ? Colors.grey[600] 
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('Submit'),
                                    ],
                                  )
                                : const Text('Submit'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Help text
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'Note: If you don\'t know the school code or need help getting started, please '),
                              TextSpan(
                                text: 'download the installation guide',
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' or contact us at '),
                              TextSpan(
                                text: 'contact@iqlexa.com',
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' or '),
                              TextSpan(
                                text: '9423423423423',
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' for assistance.'),
                            ],
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
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '© 2025 AppTestify Global Services Pvt. Ltd. | IQLEXA Technologies Private Limited',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'CampusConnect is a product of AppTestify Global Services Pvt. Ltd. | IQLEXA Technologies Private Limited',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white70,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _schoolCodeController.dispose();
    super.dispose();
  }
}
