import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var scriptStore: ScriptStore
    @ObservedObject var appSettings: AppSettings
    @State private var selectedScriptID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Script management: list + detail
            HSplitView {
                // Left: script list with +/- controls
                VStack(spacing: 0) {
                    List(selection: $selectedScriptID) {
                        ForEach(scriptStore.scripts) { script in
                            Text(script.title)
                                .tag(script.id)
                                .lineLimit(1)
                        }
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))

                    // +/- toolbar at bottom
                    HStack(spacing: 1) {
                        Button(action: {
                            if scriptStore.addScript() {
                                selectedScriptID = scriptStore.scripts.last?.id
                            }
                        }) {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .disabled(scriptStore.scripts.count >= 10)

                        Button(action: {
                            guard let id = selectedScriptID,
                                  let idx = scriptStore.scripts.firstIndex(where: { $0.id == id }) else { return }
                            // Clear selection first to avoid stale reference
                            selectedScriptID = nil
                            scriptStore.removeScript(at: idx)
                            // Select nearest remaining script
                            if !scriptStore.scripts.isEmpty {
                                let newIdx = min(idx, scriptStore.scripts.count - 1)
                                selectedScriptID = scriptStore.scripts[newIdx].id
                            }
                        }) {
                            Image(systemName: "minus")
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedScriptID == nil)

                        Spacer()

                        Text("\(scriptStore.scripts.count)/10")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
                .padding(.leading, 16)

                // Right: detail editor
                VStack(spacing: 0) {
                    if let id = selectedScriptID,
                       let index = scriptStore.scripts.firstIndex(where: { $0.id == id }) {
                        ScriptDetailView(script: binding(for: index))
                    } else {
                        Spacer()
                        Text("Select a script to edit")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .frame(minWidth: 320)
            }
            .frame(minHeight: 300)

            Divider()

            // Appearance section
            GroupBox(label: Label("Appearance", systemImage: "textformat.size")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Text Size:")
                        Slider(value: textSizeBinding, in: 10...28, step: 1)
                        Text("\(Int(appSettings.textSize))pt")
                            .frame(width: 36)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Font:")
                        Picker("", selection: Binding(
                            get: { appSettings.fontName },
                            set: { appSettings.fontName = $0 }
                        )) {
                            Text("System").tag("System")
                            Divider()
                            ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                                Text(family).tag(family)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }

                    HStack {
                        Text("Text Color:")
                        ColorPicker("", selection: colorBinding)
                            .labelsHidden()
                        Spacer()
                        Button("White") { setColor(1, 1, 1) }
                        Button("Green") { setColor(0.2, 1, 0.4) }
                        Button("Yellow") { setColor(1, 0.95, 0.4) }
                    }

                    HStack {
                        Text("Scroll Speed:")
                        Slider(value: scrollSpeedBinding, in: 0.1...0.8, step: 0.05)
                        Text(scrollSpeedLabel)
                            .frame(width: 50)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(width: 580, height: 520)
    }

    private func binding(for index: Int) -> Binding<Script> {
        let id = scriptStore.scripts[index].id
        return Binding(
            get: {
                scriptStore.scripts.first(where: { $0.id == id }) ?? Script(title: "")
            },
            set: { scriptStore.updateScript($0) }
        )
    }

    private var textSizeBinding: Binding<CGFloat> {
        Binding(
            get: { appSettings.textSize },
            set: { appSettings.textSize = $0 }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { appSettings.textColor },
            set: { newColor in
                if let components = NSColor(newColor).usingColorSpace(.sRGB) {
                    appSettings.textColorR = Double(components.redComponent)
                    appSettings.textColorG = Double(components.greenComponent)
                    appSettings.textColorB = Double(components.blueComponent)
                }
            }
        )
    }

    private var scrollSpeedBinding: Binding<Double> {
        Binding(
            get: { appSettings.scrollSpeed },
            set: { appSettings.scrollSpeed = $0 }
        )
    }

    private var scrollSpeedLabel: String {
        let speed = appSettings.scrollSpeed
        if speed < 0.2 { return "Slow" }
        if speed < 0.4 { return "Medium" }
        if speed < 0.6 { return "Fast" }
        return "Faster"
    }

    private func setColor(_ r: Double, _ g: Double, _ b: Double) {
        appSettings.textColorR = r
        appSettings.textColorG = g
        appSettings.textColorB = b
    }
}

// MARK: - Detail view for editing a single script

struct ScriptDetailView: View {
    @Binding var script: Script
    @State private var sourceMode: Script.SourceMode = .inline

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            HStack {
                Text("Title:")
                TextField("Script title", text: $script.title)
                    .textFieldStyle(.roundedBorder)
            }

            // Source toggle
            Picker("Script Source:", selection: $sourceMode) {
                ForEach(Script.SourceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: sourceMode) { newMode in
                if newMode == .inline {
                    script.filePath = nil
                    script.bookmarkData = nil
                } else {
                    script.bodyText = nil
                }
            }

            // Content area
            if sourceMode == .inline {
                Text("Script:")

                TextEditor(text: Binding(
                    get: { script.bodyText ?? "" },
                    set: { script.bodyText = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .border(Color.gray.opacity(0.3))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("File:")

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        Text(script.filePath ?? "No file selected")
                            .foregroundColor(script.filePath != nil ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.plainText, .text]
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            if panel.runModal() == .OK, let url = panel.url {
                                script.filePath = url.path
                                if let bookmark = try? url.bookmarkData(
                                    options: .withSecurityScope,
                                    includingResourceValuesForKeys: nil,
                                    relativeTo: nil
                                ) {
                                    script.bookmarkData = bookmark
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))

                    if script.filePath != nil {
                        // Preview of file contents
                        Text("Preview:")
                        ScrollView {
                            Text(script.resolvedText.prefix(2000))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .background(Color(nsColor: .textBackgroundColor))
                        .border(Color.gray.opacity(0.3))
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .onAppear {
            sourceMode = script.sourceMode
        }
        .onChange(of: script.id) { _ in
            sourceMode = script.sourceMode
        }
    }
}
