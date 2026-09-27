import Foundation
import SwiftUI
import Combine

final class Store: ObservableObject {

    @Published var classes: [ClassInfo] = []
    @Published var lineCount = 0
    @Published var fieldCount = 0
    @Published var methodCount = 0
    @Published var parseMS: Double = 0
    @Published var fileName = ""
    @Published var loading = false
    @Published var status = ""
    @Published var showPicker = false
    @Published var favorites: [String] = []
    @Published var lastError = ""
    @Published var documentFiles: [URL] = []

    private var index: [String: Int] = [:]

    private let favKey = "dv.favorites"

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var currentURL: URL {
        documentsURL.appendingPathComponent("current.cs")
    }

    init() {
        favorites = UserDefaults.standard.stringArray(forKey: favKey) ?? []
        refreshDocuments()
        let path = currentURL
        if FileManager.default.fileExists(atPath: path.path) {
            load(url: path, copyIn: false)
        }
    }

    func refreshDocuments() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: documentsURL,
                                                 includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])) ?? []
        documentFiles = items
            .filter { $0.lastPathComponent != "current.cs" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func humanSize(_ n: Int) -> String {
        if n > 1024 * 1024 { return String(format: "%.1f MB", Double(n) / 1048576.0) }
        if n > 1024 { return String(format: "%.0f KB", Double(n) / 1024.0) }
        return "\(n) B"
    }

    /// 宽容解码：UTF-8 不行就 GB18030，再不行按 UTF-8 有损解（和浏览器行为一致）
    static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        let gbk = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let s = String(data: data, encoding: String.Encoding(rawValue: gbk)) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - 载入

    func load(url: URL, copyIn: Bool = true) {
        loading = true
        status = "读取中…"
        lastError = ""
        let dest = currentURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var target = url
            var copyNote = ""
            if copyIn {
                try? FileManager.default.removeItem(at: dest)
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                    target = dest
                } catch {
                    copyNote = "（复制失败，直接读原路径）"
                }
            }

            let data: Data
            do {
                data = try Data(contentsOf: target)
            } catch {
                DispatchQueue.main.async {
                    self?.loading = false
                    self?.lastError = "打开文件失败：\(error.localizedDescription)\n对象：\(url.lastPathComponent) \(copyNote)"
                    self?.status = "读取失败"
                }
                return
            }

            DispatchQueue.main.async {
                self?.status = "解析中…（\(Store.humanSize(data.count))）"
            }

            let text = Store.decode(data)
            let result = DumpParser.parse(text)

            DispatchQueue.main.async {
                guard let self = self else { return }
                var idx: [String: Int] = [:]
                idx.reserveCapacity(result.classes.count)
                for (i, c) in result.classes.enumerated() { idx[c.full] = i }
                self.index = idx
                self.classes = result.classes
                self.lineCount = result.lineCount
                self.fieldCount = result.fieldCount
                self.methodCount = result.methodCount
                self.parseMS = result.milliseconds
                self.fileName = target.lastPathComponent
                self.loading = false
                self.status = ""
                self.lastError = ""
                self.refreshDocuments()
            }
        }
    }

    func loadFromDocuments() {
        let path = currentURL
        if FileManager.default.fileExists(atPath: path.path) {
            load(url: path, copyIn: false)
        }
    }

    // MARK: - 收藏

    func toggleFavorite(_ full: String) {
        if let i = favorites.firstIndex(of: full) {
            favorites.remove(at: i)
        } else {
            favorites.insert(full, at: 0)
        }
        UserDefaults.standard.set(favorites, forKey: favKey)
    }

    func isFavorite(_ full: String) -> Bool {
        favorites.contains(full)
    }

    func classByFull(_ full: String) -> ClassInfo? {
        if let i = index[full] { return classes[i] }
        return nil
    }

    func favoriteClasses() -> [ClassInfo] {
        favorites.compactMap { classByFull($0) }
    }

    // MARK: - 搜索

    func searchClasses(_ q: String) -> [ClassInfo] {
        let query = q.lowercased()
        if query.isEmpty { return classes }
        return classes.filter { $0.lowerFull.contains(query) }
    }

    func searchMembers(_ q: String, limit: Int = 300) -> (fields: [(FieldInfo, ClassInfo)], methods: [(MethodInfo, ClassInfo)]) {
        let query = q.lowercased()
        var fields: [(FieldInfo, ClassInfo)] = []
        var methods: [(MethodInfo, ClassInfo)] = []
        if query.count < 2 { return (fields, methods) }
        for cls in classes {
            for f in cls.fields where f.lowerName.contains(query) {
                fields.append((f, cls))
                if fields.count >= limit { break }
            }
            if fields.count >= limit { break }
        }
        for cls in classes {
            for m in cls.methods where m.lowerName.contains(query) {
                methods.append((m, cls))
                if methods.count >= limit { break }
            }
            if methods.count >= limit { break }
        }
        return (fields, methods)
    }
}