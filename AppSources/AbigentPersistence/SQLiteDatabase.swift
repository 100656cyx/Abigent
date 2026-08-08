import CSQLite
import Foundation

enum SQLiteDatabaseError: Error, Equatable {
    case open(String)
    case execute(String)
    case prepare(String)
    case bind(String)
    case step(String)
}

final class SQLiteDatabase: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let lock = NSLock()

    init(url: URL) throws {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(database)
            throw SQLiteDatabaseError.open(message)
        }
        handle = database
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
        try migrate()
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? lastError
            sqlite3_free(error)
            throw SQLiteDatabaseError.execute(message)
        }
    }

    func upsertTask(id: String, updatedAt: Double, payload: Data) throws {
        try withStatement("""
            INSERT INTO tasks(id, updated_at, payload) VALUES(?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET updated_at=excluded.updated_at, payload=excluded.payload
            WHERE excluded.updated_at >= tasks.updated_at
            """) { statement in
            try bind(id, at: 1, to: statement)
            guard sqlite3_bind_double(statement, 2, updatedAt) == SQLITE_OK else { throw bindError }
            try payload.withUnsafeBytes { bytes in
                guard sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT) == SQLITE_OK else {
                    throw bindError
                }
            }
            try stepDone(statement)
        }
    }

    func taskPayloads() throws -> [Data] {
        try withStatement("SELECT payload FROM tasks ORDER BY updated_at DESC") { statement in
            var values: [Data] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let bytes = sqlite3_column_blob(statement, 0) else { continue }
                values.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0))))
            }
            return values
        }
    }

    func insertReceipt(key: String) throws -> Bool {
        try withStatement("INSERT OR IGNORE INTO notification_receipts(receipt_key) VALUES(?)") { statement in
            try bind(key, at: 1, to: statement)
            try stepDone(statement)
            return sqlite3_changes(handle) == 1
        }
    }

    func clearAll() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("DELETE FROM notification_receipts")
            try execute("DELETE FROM results")
            try execute("DELETE FROM attention_requests")
            try execute("DELETE FROM tasks")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func migrate() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS tasks(
                id TEXT PRIMARY KEY,
                updated_at REAL NOT NULL,
                payload BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS attention_requests(
                task_id TEXT PRIMARY KEY REFERENCES tasks(id) ON DELETE CASCADE,
                payload BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS results(
                task_id TEXT PRIMARY KEY REFERENCES tasks(id) ON DELETE CASCADE,
                payload BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS notification_receipts(
                receipt_key TEXT PRIMARY KEY,
                created_at REAL NOT NULL DEFAULT (unixepoch())
            );
            PRAGMA user_version=1;
            """)
    }

    private func withStatement<T>(_ sql: String, body: (OpaquePointer) throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.prepare(lastError)
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func bind(_ value: String, at index: Int32, to statement: OpaquePointer) throws {
        guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else { throw bindError }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteDatabaseError.step(lastError) }
    }

    private var lastError: String { String(cString: sqlite3_errmsg(handle)) }
    private var bindError: SQLiteDatabaseError { .bind(lastError) }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
