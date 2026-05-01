import 'package:flutter/material.dart';
import 'call_screen.dart'; // 통화 수신 화면 파일 임포트

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('교직원 검색'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. 검색 조건 선택 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Radio<int>(
                  value: 0,
                  groupValue: 0,
                  onChanged: (value) {},
                ),
                const Text('전체'),
                Radio<int>(
                  value: 1,
                  groupValue: 0,
                  onChanged: (value) {},
                ),
                const Text('이름(부서)'),
              ],
            ),
            const SizedBox(height: 10),
            
            // 2. 검색어 입력창
            TextField(
              decoration: InputDecoration(
                hintText: '김지연',
                suffixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
            const SizedBox(height: 20),
            
            // 3. 검색 결과 목록 헤더 (테이블 스타일)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: const Border(
                  top: BorderSide(color: Colors.grey),
                  bottom: BorderSide(color: Colors.grey),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Center(child: Text('이름(부서)', style: TextStyle(fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text('교내전화', style: TextStyle(fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text('사무실위치', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            
            // 4. 검색 결과 리스트 (터치 이벤트 추가)
            Expanded(
              child: ListView.builder(
                itemCount: 2,
                itemBuilder: (context, index) {
                  // InkWell로 감싸서 터치 가능하게 만듦
                  return InkWell(
                    onTap: () {
                      // 항목 터치 시 통화 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CallScreen(isStaff: true), // 임시로 교직원(true) 설정 전달
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                Text('김지연', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('컴퓨터정보공학부', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(child: Text('053-850-6571')),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(child: Text('IT·공과대학\n(D17) 000호', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}