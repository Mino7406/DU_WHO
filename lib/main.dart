import 'dart:io' show Platform, File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'auth.dart';
import 'db/database_helper.dart';
import 'home_screen.dart';
import 'state/favorites.dart';

const Color kPrimary = Color(0xFF1A6B3C);
const Color kPrimaryDark = Color(0xFF0D4F2C);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  await loadFavoritesFromDb();
  await _loadThemeMode();
  final autoLoggedIn = await AuthService.instance.restoreSession();
  await _saveDbPathToNative();
  if (autoLoggedIn) {
    await _saveUserRoleToNative(AuthService.instance.isStaff);
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

Future<void> _saveUserRoleToNative(bool isStaff) async {
  if (!Platform.isAndroid) return;
  const channel = MethodChannel('du_who/call_overlay');
  try {
    await channel.invokeMethod('saveUserRole', {'isStaff': isStaff});
  } catch (_) {}
}

ThemeData _buildLightTheme() {
  final cs = ColorScheme.fromSeed(
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
  final cs = ColorScheme.fromSeed(
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
          home: autoLoggedIn ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _idController.text.trim();
    final pw = _pwController.text;

    if (id.isEmpty || pw.isEmpty) {
      setState(() => _errorMessage = '학번/사번과 비밀번호를 입력하세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = AuthService.instance.login(id, pw);

    if (!mounted) return;

    if (success) {
      if (_rememberMe) await AuthService.instance.saveSession(id);
      await _saveUserRoleToNative(AuthService.instance.isStaff);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '학번/사번 또는 비밀번호가 올바르지 않습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 64),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'DU-WHO',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: kPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '대구대학교 교직원 안내 서비스',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 52),
                // 학번/사번 입력
                TextField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(fontSize: 15, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: '학번 / 사번',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    fillColor: cs.surface,
                  ),
                ),
                const SizedBox(height: 12),
                // 비밀번호 입력
                TextField(
                  controller: _pwController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  style: TextStyle(fontSize: 15, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    fillColor: cs.surface,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                // 오류 메시지
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // 로그인 상태 유지 체크박스
                InkWell(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            activeColor: kPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '로그인 상태 유지',
                          style: TextStyle(
                              fontSize: 14, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimary, Color(0xFF2E9E5E)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              '로그인',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                Text(
                  'WITHOUT OUR SERVICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.outlineVariant,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
