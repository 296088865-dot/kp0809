import Foundation

struct FieldInfo: Identifiable {
    let id: Int
    var type: String
    var name: String
    var off: String
    var line: Int
    var lowerName: String
}

struct MethodInfo: Identifiable {
    let id: Int
    var name: String
    var ret: String
    var sig: String
    var rva: String?
    var off: String?
    var va: String?
    var line: Int
    var lowerName: String
}

struct ClassInfo: Identifiable {
    let id: Int
    var name: String
    var full: String
    var ns: String
    var kind: String
    var base: String
    var tdi: Int?
    var line: Int
    var parent: String?
    var fields: [FieldInfo]
    var methods: [MethodInfo]
    var lowerFull: String
}
