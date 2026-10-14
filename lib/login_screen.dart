import 'package:flutter/material.dart';

import 'auth.dart';
import 'home_screen.dart';
import 'main.dart';
import 'theme/app_theme.dart';

// 로그인 화면. 지금은 kLoginEnabled = false 라 어디서도 띄우지 않는다.
// 실제 인증을 붙일 때 다시 연결하기 위해 코드만 보존한다.
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
      await saveUserRoleToNative(AuthService.instance.isStaff);
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
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
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
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '로그인 상태 유지',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
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
                        colors: [kPrimary, AppColors.green],
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                color: Colors.white,
                              ),
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
