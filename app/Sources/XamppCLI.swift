import Foundation

struct CLIResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

final class XamppCLI {
    static let cliPath: String = {
        if let envPath = ProcessInfo.processInfo.environment["XAMPPLOCAL_CLI"],
           FileManager.default.isExecutableFile(atPath: envPath) {
            return envPath
        }
        // Highest priority: Bundled CLI inside XamppControl.app/Contents/Resources/stack/bin/xamppctl
        if let bundledCli = Bundle.main.resourceURL?.appendingPathComponent("stack/bin/xamppctl").path,
           FileManager.default.isExecutableFile(atPath: bundledCli) {
            return bundledCli
        }
        // Development mode: walk up parent directories from bundle location
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<5 {
            let candidate = dir.appendingPathComponent("bin/xamppctl").path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        let desktopCli = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/Xampp/bin/xamppctl")
        if FileManager.default.isExecutableFile(atPath: desktopCli) {
            return desktopCli
        }
        return desktopCli
    }()
    private let queue = DispatchQueue(label: "local.xampp.cli", qos: .userInitiated)
    private var watchers: [Int32: DispatchSourceProcess] = [:]

    func run(_ args: [String], completion: @escaping (CLIResult) -> Void) {
        queue.async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["python3", Self.cliPath] + args

            var env = ProcessInfo.processInfo.environment
            let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            if !existingPath.contains("/opt/homebrew/bin") {
                env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + existingPath
            }
            proc.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = errPipe

            do {
                try proc.run()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                let result = CLIResult(
                    exitCode: proc.terminationStatus,
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? ""
                )
                DispatchQueue.main.async { completion(result) }
            } catch {
                let result = CLIResult(exitCode: 1, stdout: "", stderr: error.localizedDescription)
                DispatchQueue.main.async { completion(result) }
            }
        }
    }

    func runStreaming(_ args: [String], onLine: @escaping (String) -> Void, completion: @escaping (Int32) -> Void) {
        queue.async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["python3", Self.cliPath] + args

            var env = ProcessInfo.processInfo.environment
            let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            if !existingPath.contains("/opt/homebrew/bin") {
                env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + existingPath
            }
            proc.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = errPipe

            var buffer = Data()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                buffer.append(chunk)
                while let newlineRange = buffer.range(of: Data([0x0A])) {
                    let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                    buffer.removeSubrange(0..<newlineRange.upperBound)
                    if let line = String(data: lineData, encoding: .utf8), !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        DispatchQueue.main.async { onLine(line) }
                    }
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
                outPipe.fileHandleForReading.readabilityHandler = nil
                if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8), !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    DispatchQueue.main.async { onLine(line) }
                }
                let status = proc.terminationStatus
                DispatchQueue.main.async { completion(status) }
            } catch {
                outPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { completion(1) }
            }
        }
    }

    func fetchStatus(includeMemory: Bool = false, completion: @escaping (Result<StackStatus, Error>) -> Void) {
        var args = ["status", "--json"]
        if includeMemory { args.append("--memory") }
        run(args) { res in
            guard res.exitCode == 0, let data = res.stdout.data(using: .utf8) else {
                let msg = res.stderr.isEmpty ? "xamppctl exited with code \(res.exitCode)" : res.stderr
                completion(.failure(NSError(domain: "XamppCLI", code: Int(res.exitCode), userInfo: [NSLocalizedDescriptionKey: msg])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(StackStatus.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Zero-polling kernel kqueue exit watchers for running server PIDs.
    func watchProcesses(pids: [Int32], onExit: @escaping () -> Void) {
        let wanted = Set(pids.filter { $0 > 1 })
        for (pid, src) in watchers where !wanted.contains(pid) {
            src.cancel()
            watchers.removeValue(forKey: pid)
        }
        for pid in wanted where watchers[pid] == nil {
            let src = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
            src.setEventHandler { [weak self] in
                self?.watchers[pid]?.cancel()
                self?.watchers.removeValue(forKey: pid)
                onExit()
            }
            watchers[pid] = src
            src.resume()
        }
    }

    func cancelAllWatchers() {
        for (_, src) in watchers { src.cancel() }
        watchers.removeAll()
    }
}
