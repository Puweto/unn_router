import 'package:flutter/material.dart';
import 'api.dart';
import 'screens/auth_screen.dart';
import 'screens/director_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/user_shell.dart';

const kGreen = Color(0xFF0B5D34);
const kGold = Color(0xFFF5C542);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  runApp(const NavigatorApp());
}

class NavigatorApp extends StatelessWidget {
  const NavigatorApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen, secondary: kGold, brightness: b),
        appBarTheme: const AppBarTheme(backgroundColor: kGreen, foregroundColor: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kGreen, foregroundColor: Colors.white),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNN Route Navigator',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
