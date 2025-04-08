import 'package:flutter/material.dart';
import 'package:busapp/screens/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> welcomeMessages = [
    {
      "title": "Bienvenido a BusApp",
      "subtitle": "Consulta la ubicación en vivo de los camiones cercanos",
    },
    {
      "title": "Evita esperas innecesarias",
      "subtitle": "Visualiza en tiempo real dónde está tu camión",
    },
    {
      "title": "Organiza tus trayectos",
      "subtitle": "Planea mejor tu ruta y ahorra tiempo",
    },
  ];

  void _nextPageOrNavigate() {
    if (_currentPage < welcomeMessages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              Image.asset(
                                "lib/assets/bienvenida.png",
                                width: constraints.maxWidth * 0.5,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'BusApp',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8A4DFF),
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                height: 120,
                                child: PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemCount: welcomeMessages.length,
                                  itemBuilder: (context, index) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          welcomeMessages[index]["title"]!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          welcomeMessages[index]["subtitle"]!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  welcomeMessages.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          _currentPage == index
                                              ? const Color(0xFF8A4DFF)
                                              : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPageOrNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A4DFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    "Continuar",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
}
