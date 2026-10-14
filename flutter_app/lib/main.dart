import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService();
  await api.init();
  runApp(WAManagerApp(isLoggedIn: api.isAuthenticated));
}

class WAManagerApp extends StatelessWidget {
  final bool isLoggedIn;
  const WAManagerApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.montserratTextTheme(Theme.of(context).textTheme);

    return MaterialApp(
      title: 'TantoTango Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B2529), // Indigo 600 - Modern and vibrant
          primary: const Color(0xFF8B2529),
          secondary: const Color(0xFFB34646), // Sky 500
          surface: Colors.white,
          background: const Color(0xFFEBE5DA), // Slate 50
          onSurface: const Color(0xFF0F172A), // Slate 900
        ),
        scaffoldBackgroundColor: const Color(0xFFEBE5DA),
        textTheme: textTheme.copyWith(
          titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
          titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          bodyLarge: textTheme.bodyLarge?.copyWith(color: const Color(0xFF334155)),
          bodyMedium: textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          iconTheme: IconThemeData(color: Color(0xFF475569)),
          titleTextStyle: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            letterSpacing: -0.5,
            fontFamily: 'Montserrat',
            color: Color(0xFF0F172A),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF8B2529),
          unselectedLabelColor: Color(0xFF64748B),
          indicatorColor: Color(0xFF8B2529),
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Montserrat'),
        ),
        cardTheme: CardThemeData(
          elevation: 0, // Flat cards with border are very modern
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF8B2529),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            foregroundColor: const Color(0xFF8B2529),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEBE5DA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)), 
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF8B2529), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        dividerTheme: const DividerThemeData(
          space: 1,
          thickness: 1,
          color: Color(0xFFF1F5F9),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFEBE5DA)),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.hovered)) return const Color(0xFFF1F5F9);
            return Colors.white;
          }),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontFamily: 'Montserrat', fontSize: 13, letterSpacing: 0.5),
          dataTextStyle: const TextStyle(color: Color(0xFF334155), fontFamily: 'Montserrat', fontSize: 14),
          dividerThickness: 1,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
