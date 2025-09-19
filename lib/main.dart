import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin/users_screen.dart';
import 'screens/admin/chemicals_screen.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase for supported platforms
  try {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('Firebase initialized successfully');
    } else {
      // For Windows/Desktop, we'll use Firebase Web SDK
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      debugPrint('Firebase initialized with Web SDK for desktop');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue without Firebase - app will handle this gracefully
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NattyGas Lab LIMS',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF0072BC), // Primary Blue
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFF0072BC),
              secondary: const Color(0xFF66A23F), // Primary Green
              tertiary: const Color(0xFF00BCD4), // Accent Cyan
              surface: const Color(0xFFF8FAFC), // Background Light
            ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0072BC),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF0072BC),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF0072BC),
              secondary: const Color(0xFF66A23F),
              tertiary: const Color(0xFF00BCD4),
              surface: const Color(0xFF121212), // Background Dark
            ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      // Use AuthWrapper as home to handle authentication state
      home: const AuthWrapper(),
      
      // Routes
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/users': (context) => const UsersScreen(),
        '/chemicals': (context) => const ChemicalsScreen(),
        '/samples': (context) =>
            const PlaceholderScreen(title: 'Samples Management'),
        '/cylinders': (context) =>
            const PlaceholderScreen(title: 'Cylinders Management'),
        '/reports': (context) =>
            const PlaceholderScreen(title: 'Reports Management'),
        '/invoices': (context) =>
            const PlaceholderScreen(title: 'Invoices Management'),
        '/settings': (context) =>
            const PlaceholderScreen(title: 'System Settings'),
      },
    );
  }
}

// Placeholder
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}