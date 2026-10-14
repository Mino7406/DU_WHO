import 'dart:io' show Platform, File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'auth.dart';
import 'db/database_helper.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'state/favorites.dart';

const Color kPrimary = Color(0xFF1A6B3C);
const Color kPrimaryDark = Color(0xFF0D4F2C);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  await loadFavoritesFromDb();
  await _loadThemeMode();
  // 로그인이 꺼져 있으면 남아 있는 session.json 은 무시하고 기본 역할(교직원)로 시작한다
  final autoLoggedIn =
      kLoginEnabled && await AuthService.instance.restoreSession();
  await _saveDbPathToNative();
  if (!kLoginEnabled || autoLoggedIn) {
    await saveUserRoleToNative(AuthService.instance.isStaff);
  }
  runApp(DuWhoApp(autoLoggedIn: autoLoggedIn));
}

Future<void> _loadThemeMode() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'theme_mode.txt'));
    if (!await file.exists()) return;
    final val = int.tryParse((await file.readAsString()).trim()) ?? 0;
    if (val >= 0 && val < ThemeMode.values.length) {
      themeNotifier.value = ThemeMode.values[val];
    }
  } catch (_) {}
}

Future<void> saveThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'theme_mode.txt'));
    await file.writeAsString(mode.index.toString());
  } catch (_) {}
}

Future<void> _saveDbPathToNative() async {
  if (!Platform.isAndroid) return;
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'du_who.db');
  const channel = MethodChannel('du_who/call_overlay');
  try {
    await channel.invokeMethod('saveDbPath', {'path': dbPath});
  } catch (_) {}
}

Future<void> saveUserRoleToNative(bool isStaff) async {
  if (!Platform.isAndroid) return;
  const channel = MethodChannel('du_who/call_overlay');
  try {
    await channel.invokeMethod('saveUserRole', {'isStaff': isStaff});
  } catch (_) {}
}

ThemeData _buildLightTheme() {
  final cs =
      ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.light,
      ).copyWith(
        surface: const Color(0xFFF7F8FA),
        surfaceContainerLowest: Colors.white,
        onSurface: const Color(0xFF111827),
        onSurfaceVariant: const Color(0xFF6B7280),
        outlineVariant: const Color(0xFFE5E7EB),
        primaryContainer: const Color(0xFFE8F5EE),
        onPrimaryContainer: kPrimary,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF111827),
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x18000000),
      titleTextStyle: TextStyle(
        color: Color(0xFF111827),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Color(0xFF6B7280)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0xFFE5E7EB)),
      ),
    ),
    dividerColor: const Color(0xFFE5E7EB),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final cs =
      ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF0F172A),
        surfaceContainerLowest: const Color(0xFF1E293B),
        onSurface: const Color(0xFFF1F5F9),
        onSurfaceVariant: const Color(0xFF94A3B8),
        outlineVariant: const Color(0xFF334155),
        primaryContainer: const Color(0xFF14532D),
        onPrimaryContainer: const Color(0xFF86EFAC),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E293B),
      foregroundColor: Color(0xFFF1F5F9),
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x40000000),
      titleTextStyle: TextStyle(
        color: Color(0xFFF1F5F9),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Color(0xFF94A3B8)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
    ),
    dividerColor: const Color(0xFF334155),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
  );
}

class DuWhoApp extends StatelessWidget {
  final bool autoLoggedIn;
  const DuWhoApp({super.key, this.autoLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'DU-WHO',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: mode,
          home: !kLoginEnabled || autoLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}
