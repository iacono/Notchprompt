import Foundation
import Combine

class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []
    @Published var selectedScriptID: UUID?

    private let maxScripts = 10
    private let fileURL: URL

    var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID }
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("NotchPrompter")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("scripts.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = decoded
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func addScript() -> Bool {
        guard scripts.count < maxScripts else { return false }
        let script = Script(title: "Script \(scripts.count + 1)")
        scripts.append(script)
        save()
        return true
    }

    func removeScript(at index: Int) {
        guard scripts.indices.contains(index) else { return }
        let removed = scripts.remove(at: index)
        if selectedScriptID == removed.id {
            selectedScriptID = nil
        }
        save()
    }

    func updateScript(_ script: Script) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
        save()
    }

    func selectScript(_ id: UUID?) {
        selectedScriptID = id
    }
}
