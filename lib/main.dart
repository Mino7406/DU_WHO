import 'search_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DuWhoApp());
}

class DuWhoApp extends StatelessWidget {
  const DuWhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DU-WHO',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 60.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. 메인 로고 이미지
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain, // 이미지 비율을 유지하면서 영역 안에 맞춤
                  ),
                ),
                const SizedBox(height: 60),

                // 아이디(학번/사번) 입력 필드
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '학번/사번을 입력하세요',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // 비밀번호 입력 필드
                const TextField(
                  obscureText: true, // 입력한 문자를 숨김 처리
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '비밀번호를 입력하세요',
                    suffixIcon: Icon(Icons.visibility_off),
                  ),
                ),
                const SizedBox(height: 30),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                    onPressed: () {
                      // 화면 이동(Navigation) 코드
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    child: const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 50),

                // 하단 텍스트
                const Text(
                  'WITHOUT OUR SERVICE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
