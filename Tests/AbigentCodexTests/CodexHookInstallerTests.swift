import Foundation
import XCTest
@testable import AbigentCodex

final class CodexHookInstallerTests: XCTestCase {
    func testInstallPreservesThirdPartyHooksAndIsIdempotent() throws {
        let fixture = try Fixture(json: [
            "custom": "keep",
            "hooks": ["Stop": [["hooks": [[
                "type": "command", "command": "/Applications/Flux Island.app/flux-hooks", "timeout": 30
            ]]]]]
        ])
        try fixture.installer.install(relayURL: fixture.relay)
        try fixture.installer.install(relayURL: fixture.relay)

        let root = try fixture.root()
        XCTAssertEqual(root["custom"] as? String, "keep")
        let stop = try XCTUnwrap((root["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])
        let commands = stop.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
            .compactMap { $0["command"] as? String }
        XCTAssertEqual(commands.filter { $0.contains("Flux Island") }.count, 1)
        XCTAssertEqual(commands.filter { $0.contains(CodexHookInstaller.marker) }.count, 1)
    }

    func testUninstallRemovesOnlyOwnedEntries() throws {
        let fixture = try Fixture(json: ["hooks": ["Stop": [["hooks": [[
            "type": "command", "command": "flux-hooks"
        ]]]]]])
        try fixture.installer.install(relayURL: fixture.relay)
        try fixture.installer.uninstall()
        let data = try JSONSerialization.data(withJSONObject: fixture.root(), options: [.sortedKeys])
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("flux-hooks"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(CodexHookInstaller.marker))
    }

    func testMalformedConfigurationIsNeverOverwritten() throws {
        let fixture = try Fixture(raw: Data("not-json".utf8))
        XCTAssertThrowsError(try fixture.installer.install(relayURL: fixture.relay))
        XCTAssertEqual(try Data(contentsOf: fixture.configuration), Data("not-json".utf8))
    }

    private final class Fixture {
        let directory: URL
        let configuration: URL
        let relay = URL(fileURLWithPath: "/Applications/Abigent.app/Contents/Helpers/abigent-hook")
        let installer: CodexHookInstaller

        init(json: [String: Any]) throws {
            try self.init(raw: JSONSerialization.data(withJSONObject: json))
        }

        init(raw: Data) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = directory.appendingPathComponent("hooks.json")
            try raw.write(to: configuration)
            installer = CodexHookInstaller(
                configurationURL: configuration,
                backupURL: directory.appendingPathComponent("hooks.backup.json"),
                receiptURL: directory.appendingPathComponent("receipt.json")
            )
        }

        deinit { try? FileManager.default.removeItem(at: directory) }

        func root() throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configuration)) as? [String: Any])
        }
    }
}
