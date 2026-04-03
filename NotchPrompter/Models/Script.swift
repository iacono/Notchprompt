import Foundation

struct Script: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var bodyText: String?
    var filePath: String?
    var bookmarkData: Data?

    init(id: UUID = UUID(), title: String = "Untitled", bodyText: String? = nil, filePath: String? = nil, bookmarkData: Data? = nil) {
        self.id = id
        self.title = title
        self.bodyText = bodyText
        self.filePath = filePath
        self.bookmarkData = bookmarkData
    }

    var resolvedText: String {
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let text = try? String(contentsOf: url, encoding: .utf8) {
                        return text
                    }
                }
            }
        }
        if let filePath = filePath, let text = try? String(contentsOfFile: filePath, encoding: .utf8) {
            return text
        }
        return bodyText ?? ""
    }

    var sourceMode: SourceMode {
        get {
            if filePath != nil || bookmarkData != nil { return .file }
            return .inline
        }
    }

    enum SourceMode: String, Codable, CaseIterable {
        case inline = "Text"
        case file = "File"
    }
}
