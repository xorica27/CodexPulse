import Foundation

public enum RateLimitClientError: Error, LocalizedError {
    case codexBinaryMissing(String)
    case processLaunchFailed(String)
    case responseTimeout
    case malformedResponse
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .codexBinaryMissing(let path):
            "Codex binary not found at \(path)"
        case .processLaunchFailed(let message):
            "Could not start Codex app-server: \(message)"
        case .responseTimeout:
            "Timed out waiting for Codex app-server"
        case .malformedResponse:
            "Codex app-server returned an unreadable response"
        case .serverError(let message):
            message
        }
    }
}

public final class AppServerRateLimitClient: @unchecked Sendable {
    public let codexBinaryPath: String
    public let timeoutSeconds: TimeInterval

    public init(
        codexBinaryPath: String = "/Applications/Codex.app/Contents/Resources/codex",
        timeoutSeconds: TimeInterval = 10
    ) {
        self.codexBinaryPath = codexBinaryPath
        self.timeoutSeconds = timeoutSeconds
    }

    public func fetch() throws -> RateLimitData {
        guard FileManager.default.isExecutableFile(atPath: codexBinaryPath) else {
            throw RateLimitClientError.codexBinaryMissing(codexBinaryPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexBinaryPath)
        process.arguments = ["app-server", "--listen", "stdio://"]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()

        let collector = LineCollector()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                return
            }
            collector.append(data)
        }

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            throw RateLimitClientError.processLaunchFailed(error.localizedDescription)
        }

        defer {
            output.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
                if !process.waitUntilExit(timeout: 1) {
                    process.interrupt()
                }
            }
        }

        try send(initializeRequest, to: input.fileHandleForWriting)
        _ = try waitForResponse(id: 1, collector: collector)

        try send(rateLimitRequest, to: input.fileHandleForWriting)
        let response = try waitForResponse(id: 2, collector: collector)
        return try parseRateLimitResult(from: response)
    }

    private var initializeRequest: [String: Any] {
        [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "codexpulse",
                    "version": "0.3.3"
                ],
                "capabilities": [
                    "experimentalApi": true
                ]
            ]
        ]
    }

    private var rateLimitRequest: [String: Any?] {
        [
            "id": 2,
            "method": "account/rateLimits/read",
            "params": nil
        ]
    }

    private func send(_ object: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        handle.write(data)
        handle.write(Data([0x0A]))
    }

    private func send(_ object: [String: Any?], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        handle.write(data)
        handle.write(Data([0x0A]))
    }

    private func waitForResponse(id: Int, collector: LineCollector) throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let lines = collector.drainLines()
            for line in lines {
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                if object["id"] as? Int == id {
                    if let error = object["error"] {
                        throw RateLimitClientError.serverError(String(describing: error))
                    }
                    return object
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw RateLimitClientError.responseTimeout
    }

    private func parseRateLimitResult(from response: [String: Any]) throws -> RateLimitData {
        guard let result = response["result"] as? [String: Any] else {
            throw RateLimitClientError.malformedResponse
        }
        return try RateLimitPayloadParser.parse(result: result, source: .appServer)
    }
}

private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [String] = []

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)

        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[..<newline]
            buffer.removeSubrange(...newline)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
        }
    }

    func drainLines() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let current = lines
        lines.removeAll()
        return current
    }
}

private extension Process {
    func waitUntilExit(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return !isRunning
    }
}
