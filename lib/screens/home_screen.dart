import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadUsername();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('username') ?? '';
  }

  Future<void> saveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color.fromARGB(255, 162, 0, 255),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent, // <-- Add this line
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Image.asset(
                          'assets/images/pencil.png',
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Center(
                        child: Text(
                          'Welcome to    Scriblet!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 255, 255, 255),
                            letterSpacing: 1.5,
                            // fontFamily: 'Fredoka', // Optional: match your UI
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Username',
                          filled: true,
                          fillColor: const Color.fromARGB(255, 230, 186, 255),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 16,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 30),
                            child: Text(
                              "@",
                              style: TextStyle(
                                fontSize: 32,
                                color: Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          // fontFamily: 'Fredoka',
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          if (_nameController.text.trim().isEmpty) return;
                          saveUsername();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JoinRoomScreen(
                                username: _nameController.text.trim(),
                              ),
                            ),
                          );
                        },
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF316BFF),
                              elevation: 8, // 3D effect
                              shadowColor: const Color(0xFF002366),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ).copyWith(
                              elevation:
                                  WidgetStateProperty.resolveWith<double>(
                                    (states) =>
                                        states.contains(WidgetState.pressed)
                                        ? 2
                                        : 8, // pressed effect
                                  ),
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                    (states) =>
                                        states.contains(WidgetState.pressed)
                                        ? const Color(0xFF274B8C)
                                        : const Color(0xFF316BFF),
                                  ),
                            ),
                        child: const Text(
                          'JOIN',
                          
                          style: TextStyle(
                            fontSize: 30,
                            color: Colors.white,
                            // fontFamily: 'Fredoka',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_nameController.text.trim().isEmpty) return;
                          saveUsername();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateRoomScreen(
                                username: _nameController.text.trim(),
                              ),
                            ),
                          );
                        },
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D1A0),
                              elevation: 8, // 3D effect
                              shadowColor: const Color(0xFF008C6E),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ).copyWith(
                              elevation:
                                  WidgetStateProperty.resolveWith<double>(
                                    (states) =>
                                        states.contains(WidgetState.pressed)
                                        ? 2
                                        : 8, // pressed effect
                                  ),
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                    (states) =>
                                        states.contains(WidgetState.pressed)
                                        ? const Color(0xFF008C6E)
                                        : const Color(0xFF00D1A0),
                                  ),
                            ),
                        child: const Text(
                          'CREATE',
                          style: TextStyle(
                            fontSize: 30,
                            color: Colors.white,
                            // fontFamily: 'Fredoka',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(), // pushes everything up if there's space
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
