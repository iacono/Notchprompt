import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    @Published var textSize: CGFloat {
        didSet { UserDefaults.standard.set(Double(textSize), forKey: "textSize") }
    }
    @Published var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: "fontName") }
    }
    @Published var textColorR: Double {
        didSet { UserDefaults.standard.set(textColorR, forKey: "textColorR") }
    }
    @Published var textColorG: Double {
        didSet { UserDefaults.standard.set(textColorG, forKey: "textColorG") }
    }
    @Published var textColorB: Double {
        didSet { UserDefaults.standard.set(textColorB, forKey: "textColorB") }
    }
    @Published var scrollSpeed: Double {
        didSet { UserDefaults.standard.set(scrollSpeed, forKey: "scrollSpeed") }
    }

    var textColor: Color {
        Color(red: textColorR, green: textColorG, blue: textColorB)
    }

    /// Returns the NSFont for the current font name and size, falling back to system font
    func nsFont(size: CGFloat? = nil) -> NSFont {
        let sz = size ?? textSize
        if fontName == "System" {
            return NSFont.systemFont(ofSize: sz, weight: .medium)
        }
        return NSFont(name: fontName, size: sz) ?? NSFont.systemFont(ofSize: sz, weight: .medium)
    }

    init() {
        let size = UserDefaults.standard.double(forKey: "textSize")
        self.textSize = size > 0 ? CGFloat(size) : 16
        self.fontName = UserDefaults.standard.string(forKey: "fontName") ?? "System"
        let r = UserDefaults.standard.double(forKey: "textColorR")
        let g = UserDefaults.standard.double(forKey: "textColorG")
        let b = UserDefaults.standard.double(forKey: "textColorB")
        self.textColorR = (r == 0 && g == 0 && b == 0) ? 1.0 : r
        self.textColorG = (r == 0 && g == 0 && b == 0) ? 1.0 : g
        self.textColorB = (r == 0 && g == 0 && b == 0) ? 1.0 : b
        let savedSpeed = UserDefaults.standard.double(forKey: "scrollSpeed")
        self.scrollSpeed = savedSpeed > 0 ? savedSpeed : 0.35
    }
}
