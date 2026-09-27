import Foundation

struct ParseResult {
    var classes: [ClassInfo]
    var lineCount: Int
    var fieldCount: Int
    var methodCount: Int
    var milliseconds: Double
}

enum DumpParser {

    static let typeKeywords: Set<String> = ["class", "struct", "interface", "enum"]

    static let modifiers: Set<String> = [
        "public", "private", "protected", "internal", "static", "readonly", "volatile",
        "const", "unsafe", "sealed", "new", "extern", "fixed", "event", "virtual",
        "abstract", "override", "partial", "async", "ref", "final", "unsafe"
    ]

    // MARK: - 主入口

    static func parse(_ text: String) -> ParseResult {
        let start = Date()
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)

        var classes: [ClassInfo] = []
        var stack: [(indent: Int, index: Int)] = []
        var currentNS = ""
        var pending: (rva: String, off: String?, va: String?)? = nil

        var clsID = 0, fID = 0, mID = 0
        var fieldCount = 0, methodCount = 0

        for (lineNo, rawLine) in rawLines.enumerated() {
            var s = rawLine.drop(while: { $0 == " " || $0 == "\t" || $0 == "\r" })
            if let last = s.last, last == "\r" { s = s.dropLast() }
            if s.isEmpty { continue }

            // 注释行
            if s.hasPrefix("//") {
                if s.hasPrefix("// Namespace:") {
                    currentNS = String(s.dropFirst(13)).trimmingCharacters(in: .whitespaces)
                    continue
                }
                if s.hasPrefix("// RVA:") {
                    if let rva = hexAfter("RVA:", in: s) {
                        pending = (rva, hexAfter("Offset:", in: s), hexAfter("VA:", in: s))
                    }
                }
                continue
            }

            // 闭合大括号
            if s == "}" || s == "};" {
                let ind = indentCount(rawLine)
                while let last = stack.last, last.indent >= ind { stack.removeLast() }
                pending = nil
                continue
            }

            // 类型声明
            if let decl = parseTypeDecl(s) {
                var fullName: String
                var nsName = currentNS
                var parentFull: String? = nil
                if let p = stack.last {
                    let pc = classes[p.index]
                    parentFull = pc.full
                    nsName = pc.ns
                    fullName = pc.full + "." + decl.name
                } else {
                    fullName = currentNS.isEmpty ? decl.name : currentNS + "." + decl.name
                }
                let cls = ClassInfo(
                    id: clsID,
                    name: decl.name,
                    full: fullName,
                    ns: nsName,
                    kind: decl.kind,
                    base: decl.base,
                    tdi: decl.tdi,
                    line: lineNo + 1,
                    parent: parentFull,
                    fields: [],
                    methods: [],
                    lowerFull: fullName.lowercased()
                )
                clsID += 1
                classes.append(cls)
                stack.append((indentCount(rawLine), classes.count - 1))
                pending = nil
                continue
            }

            guard let top = stack.last else { continue }
            let clsIdx = top.index

            // 方法（前面有 RVA 注释）
            if let p = pending, let m = parseMethod(s) {
                let info = MethodInfo(id: mID, name: m.name, ret: m.ret, sig: String(s),
                                      rva: p.rva, off: p.off, va: p.va,
                                      line: lineNo + 1, lowerName: m.name.lowercased())
                mID += 1
                methodCount += 1
                classes[clsIdx].methods.append(info)
                pending = nil
                continue
            }

            // 字段
            if let f = parseField(s) {
                let info = FieldInfo(id: fID, type: f.type, name: f.name, off: f.off,
                                     line: lineNo + 1, lowerName: f.name.lowercased())
                fID += 1
                fieldCount += 1
                classes[clsIdx].fields.append(info)
            }
        }

        return ParseResult(classes: classes,
                           lineCount: rawLines.count,
                           fieldCount: fieldCount,
                           methodCount: methodCount,
                           milliseconds: Date().timeIntervalSince(start) * 1000)
    }

    // MARK: - 子解析

    static func parseTypeDecl(_ s: Substring) -> (kind: String, name: String, base: String, tdi: Int?)? {
        var body = s
        var tdi: Int? = nil
        if let r = body.range(of: "// TypeDefIndex:", options: .backwards) {
            let tail = body[r.upperBound...].trimmingCharacters(in: .whitespaces)
            tdi = Int(tail)
            body = body[..<r.lowerBound]
        }
        let tokens = body.split(whereSeparator: { $0 == " " || $0 == "\t" })
        var i = 0
        while i < tokens.count, modifiers.contains(String(tokens[i])) { i += 1 }
        guard i < tokens.count, typeKeywords.contains(String(tokens[i])) else { return nil }
        let kind = String(tokens[i])
        i += 1
        guard i < tokens.count else { return nil }
        var name = String(tokens[i])
        i += 1
        var base = ""
        if i < tokens.count {
            var rest = tokens[i...].joined(separator: " ")
            if rest.hasPrefix(":") { rest = String(rest.dropFirst()) }
            base = rest.trimmingCharacters(in: .whitespaces)
        }
        if name.hasPrefix(":") { name = String(name.dropFirst()) }
        if name.isEmpty { return nil }
        return (kind, name, base, tdi)
    }

    static func parseField(_ s: Substring) -> (type: String, name: String, off: String)? {
        guard let semi = s.range(of: ";") else { return nil }
        let after = s[semi.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
        guard after.hasPrefix("//") else { return nil }
        let comment = after.dropFirst(2).drop(while: { $0 == " " || $0 == "\t" })
        guard comment.hasPrefix("0x") || comment.hasPrefix("0X") else { return nil }
        let digits = comment.dropFirst(2).prefix(while: { $0.isHexDigit })
        guard !digits.isEmpty else { return nil }
        let offset = "0x" + digits

        var decl = s[..<semi.lowerBound]
        if let eq = decl.firstIndex(of: "=") { decl = decl[..<eq] }
        let tokens = decl.split(whereSeparator: { $0 == " " || $0 == "\t" })
        var i = 0
        while i < tokens.count, modifiers.contains(String(tokens[i])) { i += 1 }
        guard tokens.count - i >= 2 else { return nil }
        let name = String(tokens[tokens.count - 1])
        guard isValidIdentifier(name) else { return nil }
        let type = tokens[i..<(tokens.count - 1)].joined(separator: " ")
        guard !type.isEmpty else { return nil }
        return (type, name, offset)
    }

    static func parseMethod(_ s: Substring) -> (name: String, ret: String)? {
        guard let p = s.firstIndex(of: "(") else { return nil }
        let head = s[..<p]
        let tokens = head.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let lastTok = tokens.last else { return nil }
        var name = String(lastTok)
        if let colon = name.lastIndex(of: ":") {
            name = String(name[name.index(after: colon)...])
        }
        guard isValidMethodName(name) else { return nil }
        var retToks = tokens.dropLast()
        while let f = retToks.first, modifiers.contains(String(f)) { retToks = retToks.dropFirst() }
        return (name, retToks.joined(separator: " "))
    }

    // MARK: - 工具

    static func hexAfter(_ key: String, in s: Substring) -> String? {
        guard let r = s.range(of: key) else { return nil }
        var t = s[r.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
        guard t.count > 2 else { return nil }
        guard t.hasPrefix("0x") || t.hasPrefix("0X") else { return nil }
        t = t.dropFirst(2)
        let digits = t.prefix(while: { $0.isHexDigit })
        guard !digits.isEmpty else { return nil }
        return "0x" + digits
    }

    static func indentCount(_ s: Substring) -> Int {
        var n = 0
        for ch in s {
            if ch == " " || ch == "\t" { n += 1 } else { break }
        }
        return n
    }

    static func isValidIdentifier(_ s: String) -> Bool {
        guard let f = s.first else { return false }
        guard f.isLetter || f == "_" || f == "@" || f == "$" else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "@" || $0 == "$" }
    }

    static func isValidMethodName(_ s: String) -> Bool {
        if s.isEmpty { return false }
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.$<>[]=!+-*/%&|^~")
        return s.allSatisfy { allowed.contains($0) }
    }
}
