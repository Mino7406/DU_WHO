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
import 'theme/app_theme.dart';

// 기본 강조색: DU DEEP GREEN. 색 정의는 theme/app_theme.dart 한 곳에서 관리한다
const Color kPrimary = AppColors.deepGreen;

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
  if (!Platform.isAndroid && !Platform.isIOS) return;
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'du_who.db');
  const channel = MethodChannel('du_who/call_overlay');
  try {
    await channel.invokeMethod('saveDbPath', {'path': dbPath});
  } catch (_) {}
}

Future<void> saveUserRoleToNative(bool isStaff) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  const channel = MethodChannel('du_who/call_overlay');
  try {
    await channel.invokeMethod('saveUserRole', {'isStaff': isStaff});
  } catch (_) {}
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
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: mode,
          home: !kLoginEnabled || autoLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}
