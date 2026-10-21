import AppKit
import Observation

// What Passport looks at and what it runs. The work is done by the shell scripts in the app's Resources, the same
// ones a person runs from a checkout; this reads the files they leave behind to say how far along things are.
@MainActor @Observable final class Passport {
    enum State { case ok, warning, missing }

    struct Check: Identifiable {
        let id: String
        let title: String
        let detail: String
        let state: State
    }

    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let support = home.appending(path: "Library/Application Support/Passport")
    private static let steamSupport = home.appending(path: "Library/Application Support/Steam")
    private static let steamApp = URL(filePath: "/Applications/Steam.app")
    private static let hookPath = steamApp.appending(path: "Contents/MacOS/passport.dylib").path

    private(set) var checks: [Check] = []
    private(set) var installed = false
    private(set) var blocked: String?
    private(set) var steamRunning = false
    private(set) var busy = false
    private(set) var log = ""
    private(set) var result: String?

    init() {
        refresh()
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.refresh()
            }
        }
    }

    func refresh() {
        steamRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.valvesoftware.steam").isEmpty

        let mac = Self.macSteamBuild()
        let hook = Self.hookState()
        let engine = Self.engineVersion()
        let linked = try? String(contentsOf: Self.support.appending(path: "steam/version"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tool = FileManager.default.fileExists(
            atPath: Self.steamSupport.appending(path: "compatibilitytools.d/passport/run").path)

        var steam = Check(id: "steam", title: "Steam", detail: "Not found in /Applications", state: .missing)
        if FileManager.default.fileExists(atPath: Self.steamApp.path) {
            steam = Check(id: "steam", title: "Steam",
                          detail: mac.map { "Build \($0)" } ?? "Found, not signed in yet", state: .ok)
        }

        var engineCheck = Check(id: "engine", title: "Linux engine",
                                detail: "Not installed, downloads 430 MB", state: .missing)
        if let engine { engineCheck = Check(id: "engine", title: "Linux engine", detail: "Voile \(engine)", state: .ok) }

        var link = Check(id: "link", title: "Steam link", detail: "Not set up", state: .missing)
        if let linked, !linked.isEmpty {
            link = linked == mac
                ? Check(id: "link", title: "Steam link", detail: "Matches Steam build \(linked)", state: .ok)
                : Check(id: "link", title: "Steam link",
                        detail: "Needs an update for build \(mac ?? "unknown")",
                        state: .warning)
        }

        var hookCheck = Check(id: "hook", title: "Steam hook", detail: "Not installed", state: .missing)
        blocked = nil
        switch hook {
        case .ours: hookCheck = Check(id: "hook", title: "Steam hook", detail: "Installed", state: .ok)
        case .other(let name):
            hookCheck = Check(id: "hook", title: "Steam hook", detail: "\(name) is loaded instead", state: .warning)
            blocked = "Steam already loads \(name). Remove it first, since Passport's hook does the same job."
        case .none: break
        }

        checks = [steam, engineCheck, link, hookCheck]
        if steam.state == .missing { blocked = "Steam isn't in /Applications." }
        installed = engine != nil && hook == .ours && tool && linked == mac
    }

    func install() { run("install.sh", doing: "Installing") }
    func uninstall() { run("uninstall.sh", doing: "Removing") }

    func quitSteam() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.valvesoftware.steam")
            .forEach { $0.terminate() }
    }

    func reveal(_ name: String) {
        let url = Self.support.appending(path: name)
        if name.isEmpty || !FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(Self.support)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func run(_ script: String, doing: String) {
        guard !busy, let scripts = Bundle.main.resourceURL?.appending(path: "passport") else { return }
        busy = true
        result = nil
        log = "\(doing)...\n"

        let process = Process()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = [script]
        process.currentDirectoryURL = scripts

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.log += text }
        }
        process.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                guard let self else { return }
                self.busy = false
                self.result = finished.terminationStatus == 0 ? "Done." : "Failed. The log has the details."
                self.refresh()
            }
        }
        do { try process.run() } catch {
            busy = false
            result = "Could not start \(script): \(error.localizedDescription)"
        }
    }

    // MARK: Reading the machine

    private enum Hook: Equatable { case ours, other(String), none }

    private static func hookState() -> Hook {
        let plist = steamApp.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let insert = (dict["LSEnvironment"] as? [String: String])?["DYLD_INSERT_LIBRARIES"]
        else { return .none }
        return insert == hookPath ? .ours : .other(URL(filePath: insert).lastPathComponent)
    }

    private static func engineVersion() -> String? {
        let runtime = support.appending(path: "runtime")
        guard FileManager.default.fileExists(atPath: runtime.appending(path: "engine/fexdarwin-run").path),
              let target = try? FileManager.default.destinationOfSymbolicLink(atPath: runtime.path)
        else { return nil }
        return target.components(separatedBy: "/").first?.replacingOccurrences(of: "voile-", with: "")
    }

    // The newest build among the installed Steam's manifests, the same number tool/steamclient.sh goes by.
    private static func macSteamBuild() -> String? {
        let package = steamSupport.appending(path: "Steam.AppBundle/Steam/Contents/MacOS/package")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: package.path)) ?? []
        let versions = names.filter { $0.hasPrefix("steam_client") && $0.hasSuffix("osx.manifest") }.compactMap { name in
            (try? String(contentsOf: package.appending(path: name), encoding: .utf8))?
                .split(separator: "\n").lazy
                .compactMap { line -> String? in
                    let parts = line.split(separator: "\"")
                    return parts.count >= 4 && parts[0].trimmingCharacters(in: .whitespaces).isEmpty
                        && parts[1] == "version" ? String(parts[3]) : nil
                }.first
        }
        return versions.max()
    }
}
