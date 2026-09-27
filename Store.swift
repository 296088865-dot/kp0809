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
        let path = currentURL
        if FileManager.default.fileExists(atPath: path.path) {
            load(url: path, copyIn: false)
        }
    }

    // MARK: - 载入

    func load(url: URL, copyIn: Bool = true) {
        loading = true
        status = "读取中…"
        let dest = currentURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var target = url
            if copyIn {
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: url, to: dest)
                if FileManager.default.fileExists(atPath: dest.path) { target = dest }
            }

            DispatchQueue.main.async {
                self?.status = "解析中…"
            }

            guard let text = try? String(contentsOf: target, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self?.loading = false
                    self?.status = "读取失败（不是文本文件？）"
                }
                return
            }

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