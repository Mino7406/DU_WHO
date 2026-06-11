import Foundation
import SQLite3

/// 발신자 교직원 정보 (Android CallOverlayService.StaffInfo 대응)
struct StaffInfo {
    let name: String
    let department: String
    let title: String
    let location: String
}

/// SQLite 교직원 DB 조회 (Android CallOverlayService.queryStaff 이식)
class StaffDatabase {

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
    static func queryStaff(phoneNumber: String, databasePath: String, isStaffUser: Bool) -> StaffInfo? {
        let cleaned = normalizePhoneNumber(phoneNumber)
        if cleaned.count < 4 { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        let sql: String
        if isStaffUser {
            sql = """
                SELECT name, department, title, location FROM staff
                WHERE REPLACE(REPLACE(tel,     '-',''),' ','') = ?
                   OR REPLACE(REPLACE(cell_tel,'-',''),' ','') = ?
                   OR (
                       LENGTH(REPLACE(REPLACE(tel,'-',''),' ','')) >= 4
                       AND REPLACE(REPLACE(tel,'-',''),' ','') NOT IN ('','0000')
                       AND ? LIKE '%' || REPLACE(REPLACE(tel,'-',''),' ','')
                   )
                LIMIT 1
                """
        } else {
            sql = """
                SELECT name, department, title, location FROM staff
                WHERE REPLACE(REPLACE(tel,'-',''),' ','') = ?
                   OR (
                       LENGTH(REPLACE(REPLACE(tel,'-',''),' ','')) >= 4
                       AND REPLACE(REPLACE(tel,'-',''),' ','') NOT IN ('','0000')
                       AND ? LIKE '%' || REPLACE(REPLACE(tel,'-',''),' ','')
                   )
                LIMIT 1
                """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let paramCount = isStaffUser ? 3 : 2
        for i in 1...paramCount {
            sqlite3_bind_text(stmt, Int32(i), cleaned, -1, transient)
        }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        func column(_ index: Int32) -> String {
            guard let cString = sqlite3_column_text(stmt, index) else { return "" }
            return String(cString: cString)
        }

        let name = column(0)
        if name.isEmpty { return nil }
        return StaffInfo(
            name: name,
            department: column(1),
            title: column(2),
            location: column(3)
        )
    }
}
