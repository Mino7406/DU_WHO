import Foundation
import SQLite3

/// 발신자 교직원 정보 (Android CallOverlayService.StaffInfo 대응)
struct StaffInfo {
    let name: String
    let department: String
    let title: String
    let location: String
    /// 같은 번호를 쓰는 사람 수와 이름 일부(공용 번호 표시용)
    var sharedCount: Int = 1
    var sharedNames: [String] = []
}

/// SQLite 교직원 DB 조회 (Android CallOverlayService.queryStaff 이식)
class StaffDatabase {

    /// 발신 번호 → 교직원 매칭. ?1 = 숫자만 남긴 수신 번호, ?2 = 교직원 계정이면 1.
    /// 전체 번호가 정확히 같을 때만 매칭한다. 끝자리만 비교하면 4자리 내선번호(105건) 때문에
    /// 관계없는 번호의 약 1%가 교직원으로 잘못 감지됐다.
    /// 4자리 내선은 학교 국번(053-850, 053-650)이 붙은 번호로 걸려올 때만 매칭한다.
    /// 학생: 교내전화만, 교직원: 휴대전화도 매칭. Android CallOverlayService.MATCH_SQL 과 같은 SQL.
    private static let matchSQL = """
        SELECT name, department, title, location,
               CASE WHEN ?2 = 1 AND c = ?1 THEN 0 WHEN t = ?1 THEN 1 ELSE 2 END AS rank
        FROM (
            SELECT name, department, title, location,
                   REPLACE(REPLACE(tel,     '-', ''), ' ', '') AS t,
                   REPLACE(REPLACE(cell_tel,'-', ''), ' ', '') AS c
            FROM staff
        )
        WHERE (?2 = 1 AND c = ?1)
           OR t = ?1
           OR (LENGTH(t) = 4 AND t <> '0000' AND ?1 IN ('053850' || t, '053650' || t))
        ORDER BY rank
        LIMIT 20
        """

    /// 전화번호 정규화: +82 → 0 치환, 숫자 외 문자 제거
    static func normalizePhoneNumber(_ raw: String) -> String {
        var normalized = raw
        if normalized.hasPrefix("+82") {
            normalized = "0" + normalized.dropFirst(3)
        }
        return normalized.filter { $0.isNumber }
    }

    /// 발신 번호로 교직원 조회.
    /// - 학생(isStaffUser=false): 교내전화(tel)만 매칭
    /// - 교직원(isStaffUser=true): 교내전화 + 휴대전화(cell_tel) 모두 매칭
    /// - 여러 명이 같은 번호를 쓰면 sharedCount/sharedNames 를 채워서 돌려준다
    static func queryStaff(phoneNumber: String, databasePath: String, isStaffUser: Bool) -> StaffInfo? {
        let cleaned = normalizePhoneNumber(phoneNumber)
        if cleaned.count < 4 { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, matchSQL, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, cleaned, -1, transient)
        sqlite3_bind_int(stmt, 2, isStaffUser ? 1 : 0)

        func column(_ index: Int32) -> String {
            guard let cString = sqlite3_column_text(stmt, index) else { return "" }
            return String(cString: cString)
        }

        var matches: [StaffInfo] = []
        var bestRank: Int32 = -1
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rank = sqlite3_column_int(stmt, 4)
            // 가장 정확한 순위의 결과만 사용 (휴대폰 일치 > 교내전화 일치 > 내선)
            if bestRank == -1 { bestRank = rank }
            if rank != bestRank { break }
            let name = column(0)
            if name.isEmpty { continue }
            matches.append(StaffInfo(
                name: name,
                department: column(1),
                title: column(2),
                location: column(3)
            ))
        }

        guard var first = matches.first else { return nil }
        if matches.count > 1 {
            first.sharedCount = matches.count
            first.sharedNames = matches.prefix(3).map { $0.name }
        }
        return first
    }
}
