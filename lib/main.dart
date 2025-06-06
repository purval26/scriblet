import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Add this import
import 'screens/home_screen.dart';

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Dark icons on light background
    systemNavigationBarColor: Color(0xFF2F31C5), // Match your app's background
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {    return MaterialApp(
      title: 'Scriblet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        
        fontFamily: 'Ezydraw',
        scaffoldBackgroundColor: const Color(0xFFFFF1E0),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18, color: Colors.black),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
