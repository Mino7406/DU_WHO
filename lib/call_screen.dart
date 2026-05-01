import 'package:flutter/material.dart';

class CallScreen extends StatelessWidget {
  final bool isStaff; // 학생(false) 또는 교직원(true) 여부 설정

  const CallScreen({Key? key, this.isStaff = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 상단: 발신자 정보 영역
            Padding(
              padding: const EdgeInsets.only(top: 60.0),
              child: Column(
                children: [
                  const Text(
                    '00:10',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '컴퓨터정보공학부',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    // 신분에 따른 정보 노출 차등 로직 적용 (UI상)
                    isStaff ? '컴퓨터정보공학부장 김지연' : '김지연 교수',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            
            // 하단: 제어 버튼 영역
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0, left: 40.0, right: 40.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(Icons.volume_up, 'Speaker'),
                      _buildControlButton(Icons.videocam, 'FaceTime'),
                      _buildControlButton(Icons.mic_off, 'Mute'),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(Icons.add, 'Add'),
                      _buildControlButton(Icons.dialpad, 'Keypad'),
                      // 통화 종료 버튼
                      Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                              onPressed: () {
                                // 현재 화면(통화 화면)을 닫고 이전 화면으로 돌아감
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('End', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 중복되는 버튼 코드를 줄이기 위한 헬퍼 메서드
  Widget _buildControlButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), // 반투명한 흰색 배경
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}