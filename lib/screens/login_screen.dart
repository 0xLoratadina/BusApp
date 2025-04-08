import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;
      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacementNamed(context, '/success');
      } else {
        _showError('Usuario o contraseña incorrectos');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.06,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.02),
                          Column(
                            children: [
                              SizedBox(height: constraints.maxHeight * 0.05),
                              Text(
                                'Inicia sesión o regístrate',
                                style: GoogleFonts.poppins(
                                  fontSize: constraints.maxWidth * 0.045,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.03),
                              Container(
                                height: constraints.maxHeight * 0.06,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'lib/assets/google.png',
                                    width: constraints.maxWidth * 0.06,
                                    height: constraints.maxHeight * 0.03,
                                  ),
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.01),
                              Text(
                                '¿Eres operador\nInicia sesión con correo',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: constraints.maxWidth * 0.03,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.02),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Email',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: constraints.maxWidth * 0.035,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.005),
                              TextFormField(
                                controller: _emailController,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingrese su correo electrónico';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'xxxxxxxxx@xxxxx.com',
                                  filled: true,
                                  fillColor: const Color(0xFFF6F8FE),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: constraints.maxHeight * 0.017,
                                    horizontal: constraints.maxWidth * 0.04,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6E39B5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6E39B5),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.02),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Contraseña',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: constraints.maxWidth * 0.035,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.005),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.length < 6) {
                                    return 'Ingrese mínimo 6 caracteres';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'xxxxxxxxxxxxxxxxxxxxx',
                                  filled: true,
                                  fillColor: const Color(0xFFF6F8FE),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: constraints.maxHeight * 0.017,
                                    horizontal: constraints.maxWidth * 0.04,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6E39B5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6E39B5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              SizedBox(height: constraints.maxHeight * 0.03),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6E39B5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: constraints.maxHeight * 0.02,
                                    ),
                                  ),
                                  child:
                                      _isLoading
                                          ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                          : Text(
                                            'Iniciar Sesión',
                                            style: GoogleFonts.poppins(
                                              fontSize:
                                                  constraints.maxWidth * 0.04,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.02),
                              Text(
                                'Acepto los términos y condiciones al registrarme por primera vez',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: constraints.maxWidth * 0.027,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.02),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
