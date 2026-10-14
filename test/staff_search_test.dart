import 'package:du_who/staff_model.dart';
import 'package:du_who/utils/staff_search.dart';
import 'package:flutter_test/flutter_test.dart';

Staff s(String name, {String dept = '', String title = '', String duty = ''}) =>
    Staff(
      userId: name,
      name: name,
      department: dept,
      title: title,
      tel: '',
      cellTel: '',
      location: '',
      email: '',
      chargeBusiness: duty,
    );

void main() {
  final all = [
    s('김민호', dept: '컴퓨터정보공학부'),
    s('김민수', dept: '학생지원팀', duty: '장학금'),
    s('박기민', dept: '총무팀', title: '팀장'),
    s('민호준', dept: '입학팀'),
    s('이장학', dept: '교무팀'),
  ];

  test('toChoseong / isChoseongQuery', () {
    expect(toChoseong('김민호'), 'ㄱㅁㅎ');
    expect(toChoseong('A김1'), 'Aㄱ1');
    expect(isChoseongQuery('ㄱㅁㅎ'), isTrue);
    expect(isChoseongQuery('ㄱ ㅁ'), isTrue);
    expect(isChoseongQuery('ㄱ'), isFalse);
    expect(isChoseongQuery('ㄱ민'), isFalse);
  });

  test('초성 검색: 일치 > 시작 > 포함', () {
    expect(searchLocal(all, 'ㄱㅁㅎ').map((e) => e.name), ['김민호']);
    expect(searchLocal(all, 'ㄱㅁ').map((e) => e.name), ['김민수', '김민호', '박기민']);
  });

  test('이름 일치 > 이름 시작 > 이름 포함 > 부서 > 업무', () {
    expect(searchLocal(all, '민호').map((e) => e.name), ['민호준', '김민호']);
    expect(searchLocal(all, '장학').map((e) => e.name), ['이장학', '김민수']);
  });

  test('여러 낱말은 모두 걸려야 한다', () {
    expect(searchLocal(all, '김민 학생').map((e) => e.name), ['김민수']);
    expect(searchLocal(all, '김민 총무'), isEmpty);
  });

  test('이름·부서만 / 학생은 직위로 못 찾음', () {
    expect(searchLocal(all, '장학', namesOnly: true).map((e) => e.name), ['이장학']);
    expect(searchLocal(all, '팀장').map((e) => e.name), ['박기민']);
    expect(searchLocal(all, '팀장', includeTitle: false), isEmpty);
  });

  test('matchRanges: 강조 구간', () {
    expect(matchRanges('김민호', '민호'), [(1, 3)]);
    expect(matchRanges('김민호', 'ㅁㅎ'), [(1, 3)]);
    expect(matchRanges('학생지원팀', '지원 학생'), [(0, 2), (2, 4)]);
    expect(matchRanges('김민호', '없음'), isEmpty);
  });

  test('전화번호 검색: 일치 > 끝자리 > 포함, 휴대폰은 교직원만', () {
    Staff p(String name, String tel, String cell) => Staff(
      userId: name,
      name: name,
      department: '',
      title: '',
      tel: tel,
      cellTel: cell,
      location: '',
      email: '',
      chargeBusiness: '',
    );
    final people = [
      p('갑', '053-850-0573', ''),
      p('을', '0573', ''),
      p('병', '053-850-1111', '010-1234-0573'),
      p('정', '0000', ''),
    ];
    expect(isPhoneQuery('0573'), isTrue);
    expect(isPhoneQuery('850-0573'), isTrue);
    expect(isPhoneQuery('05'), isFalse);
    expect(isPhoneQuery('a0573'), isFalse);
    expect(searchLocal(people, '0573').map((e) => e.name), ['을', '갑']);
    expect(searchLocal(people, '0573', includeCell: true).map((e) => e.name), [
      '을',
      '갑',
      '병',
    ]);
    expect(searchLocal(people, '000'), isEmpty);
    expect(matchRanges('053-850-0573', '8500573'), [(4, 12)]);
    expect(matchRanges('053-850-0573', '0573'), [(8, 12)]);
  });

  test('groupByDepartment: 부서 이름순, 빈 부서는 기타', () {
    final groups = groupByDepartment([...all, s('무소속')]);
    expect(groups.first.name, '교무팀');
    expect(groups.map((g) => g.name), contains('기타'));
    expect(groups.every((g) => g.members.isNotEmpty), isTrue);
  });
}
