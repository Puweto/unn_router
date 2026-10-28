import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'screens/auth_screen.dart';
import 'screens/director_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/user_shell.dart';

const kGreen = Color(0xFF0B5D34);
const kGold = Color(0xFFF5C542);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await Session.load();
  runApp(const NavigatorApp());
}

class NavigatorApp extends StatelessWidget {
  const NavigatorApp({super.key});

  ThemeData _theme(Brightness b) {
    final baseScheme = ColorScheme.fromSeed(seedColor: kGreen, secondary: kGold, brightness: Brightness.light);
    final scheme = baseScheme.copyWith(
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Colors.white,
      surfaceContainerHigh: const Color(0xFFF8F9FA),
      surfaceContainerHighest: const Color(0xFFF1F3F5),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: scheme,
      canvasColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: kGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: kGreen),
        actionsIconTheme: IconThemeData(color: kGreen),
        titleTextStyle: TextStyle(
          color: kGreen,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: kGreen.withValues(alpha: 0.12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Route Navigator',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.light),
      home: const _Root(),
    );
  }
}

/// Activity diagram: Display Splash Screen -> is user information available?
///   no  -> Enter/Save User Information -> Home
///   yes -> Home
class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_splash) return const SplashScreen();
    return ValueListenableBuilder<int>(
      valueListenable: sessionVersion,
      builder: (context, _, __) {
        if (Session.token == null) return const AuthScreen();
        if (Session.role == 'director') return const DirectorScreen();
        return const UserShell();
      },
    );
  }
}
