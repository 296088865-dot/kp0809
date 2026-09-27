import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 工具函数

func kindColor(_ kind: String) -> Color {
    switch kind {
    case "enum": return .orange
    case "interface": return .purple
    case "struct": return .cyan
    default: return .blue
    }
}

func copyToPasteboard(_ s: String) {
    UIPasteboard.general.string = s
}

// MARK: - 根视图

struct RootView: View {
    @EnvironmentObject var vm: Store

    var body: some View {
        TabView {
            NavigationStack {
                ClassListView()
            }
            .tabItem { Label("类", systemImage: "list.bullet") }

            NavigationStack {
                MemberSearchView()
            }
            .tabItem { Label("成员", systemImage: "magnifyingglass") }

            NavigationStack {
                FavoritesView()
            }
            .tabItem { Label("收藏", systemImage: "star") }

            NavigationStack {
                ToolsView()
            }
            .tabItem { Label("工具", systemImage: "wrench") }
        }
        .sheet(isPresented: $vm.showPicker) {
            DocumentPicker { url in
                vm.load(url: url)
            }
        }
        .onOpenURL { url in
            vm.load(url: url)
        }
        .overlay {
            if vm.loading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                        Text(vm.status.isEmpty ? "处理中…" : vm.status)
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(white: 0.15))
                    .cornerRadius(14)
                }
            }
        }
    }
}

// MARK: - 类列表

struct ClassListView: View {
    @EnvironmentObject var vm: Store
    @State private var query = ""

    private var results: [ClassInfo] {
        vm.searchClasses(query)
    }

    var body: some View {
        Group {
            if vm.classes.isEmpty {
                ScrollView {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                        Text("还没有载入 dump.cs")
                            .font(.headline)
                        Button("选择文件") { vm.showPicker = true }
                            .buttonStyle(.borderedProminent)

                        if !vm.lastError.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("上次失败原因")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(vm.lastError)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(white: 0.14))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }

                        Divider().padding(.horizontal, 40)

                        Text("App 的 Documents 目录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(vm.documentsURL.path)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        if vm.documentFiles.isEmpty {
                            Text("（这里是空的）")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(vm.documentFiles, id: \.self) { url in
                                Button {
                                    vm.load(url: url, copyIn: false)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text(url.lastPathComponent)
                                            .font(.system(size: 13))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        Button {
                            vm.refreshDocuments()
                        } label: {
                            Label("重新扫描", systemImage: "arrow.clockwise")
                        }
                        .font(.footnote)
                        .padding(.bottom, 30)
                    }
                }
            } else {
                List {
                    ForEach(results) { cls in
                        NavigationLink(destination: ClassDetailView(cls: cls)) {
                            ClassRow(cls: cls)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $query, prompt: "搜类名 / 命名空间")
        .navigationTitle(vm.classes.isEmpty ? "dump.cs" : "\(results.count) 个类")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.showPicker = true } label: {
                    Image(systemName: "folder")
                }
            }
        }
    }
}

struct ClassRow: View {
    @EnvironmentObject var vm: Store
    let cls: ClassInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(String(cls.kind.prefix(1)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(kindColor(cls.kind).opacity(0.22))
                    .foregroundColor(kindColor(cls.kind))
                    .cornerRadius(4)
                Text(cls.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                if vm.isFavorite(cls.full) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
            }
            HStack(spacing: 8) {
                Text(cls.ns.isEmpty ? "<global>" : cls.ns)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(cls.fields.count)f \(cls.methods.count)m")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 类详情

struct ClassDetailView: View {
    @EnvironmentObject var vm: Store
    let cls: ClassInfo

    private var metaText: String {
        var parts: [String] = [cls.kind]
        if let t = cls.tdi { parts.append("TypeDefIndex \(t)") }
        if !cls.base.isEmpty { parts.append("继承 \(cls.base)") }
        if let p = cls.parent { parts.append("嵌套于 \(p)") }
        parts.append("第 \(cls.line) 行")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text(cls.full)
                        .font(.system(size: 15, weight: .bold))
                        .textSelection(.enabled)
                    Text(metaText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)

                Button {
                    copyToPasteboard(cls.full)
                } label: {
                    Label("复制类全名", systemImage: "doc.on.doc")
                }
            }

            Section(header: Text("字段 (\(cls.fields.count))")) {
                if cls.fields.isEmpty {
                    Text("无").foregroundColor(.secondary)
                }
                ForEach(cls.fields) { f in
                    Button {
                        copyToPasteboard(f.off)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.type)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                Text(f.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Text(f.off)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Section(header: Text("方法 (\(cls.methods.count))")) {
                if cls.methods.isEmpty {
                    Text("无").foregroundColor(.secondary)
                }
                ForEach(cls.methods) { m in
                    Button {
                        copyToPasteboard(m.off ?? m.rva ?? "")
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.sig)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text(rvaText(m))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(m.off ?? m.rva ?? "—")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(cls.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.toggleFavorite(cls.full)
                } label: {
                    Image(systemName: vm.isFavorite(cls.full) ? "star.fill" : "star")
                }
            }
        }
    }

    private func rvaText(_ m: MethodInfo) -> String {
        var parts: [String] = []
        if let x = m.rva { parts.append("RVA " + x) }
        if let x = m.off { parts.append("Offset " + x) }
        if let x = m.va { parts.append("VA " + x) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 成员搜索

struct MemberSearchView: View {
    @EnvironmentObject var vm: Store
    @State private var query = ""

    var body: some View {
        Group {
            if query.count < 2 {
                VStack(spacing: 10) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("输入至少 2 个字符")
                        .foregroundColor(.secondary)
                }
            } else {
                let res = vm.searchMembers(query)
                List {
                    if !res.fields.isEmpty {
                        Section(header: Text("字段 (\(res.fields.count))")) {
                            ForEach(Array(res.fields.enumerated()), id: \.offset) { _, item in
                                Button {
                                    copyToPasteboard(item.0.off)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.0.type + " · " + item.1.name)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            Text(item.0.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                        Text(item.0.off)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                    if !res.methods.isEmpty {
                        Section(header: Text("方法 (\(res.methods.count))")) {
                            ForEach(Array(res.methods.enumerated()), id: \.offset) { _, item in
                                NavigationLink(destination: ClassDetailView(cls: item.1)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.0.sig)
                                            .font(.system(size: 11.5, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text(item.1.name + " · " + (item.0.off ?? item.0.rva ?? "—"))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    if res.fields.isEmpty && res.methods.isEmpty {
                        Text("没有匹配").foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $query, prompt: "搜字段名 / 方法名")
        .navigationTitle("成员")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 收藏

struct FavoritesView: View {
    @EnvironmentObject var vm: Store

    var body: some View {
        Group {
            let favs = vm.favoriteClasses()
            if favs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "star")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("还没有收藏")
                        .foregroundColor(.secondary)
                    Text("打开一个类，点右上角 ☆")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(favs) { cls in
                        NavigationLink(destination: ClassDetailView(cls: cls)) {
                            ClassRow(cls: cls)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            vm.toggleFavorite(favs[i].full)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("收藏")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 工具

struct ToolsView: View {
    @EnvironmentObject var vm: Store
    @State private var hexInput = ""

    private var hexResult: String {
        let s = hexInput.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return "—" }
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            guard let v = UInt64(s.dropFirst(2), radix: 16) else { return "格式不对" }
            return "\(v)"
        }
        guard let v = UInt64(s) else { return "格式不对" }
        return "0x" + String(v, radix: 16).uppercased()
    }

    var body: some View {
        List {
            Section(header: Text("文件")) {
                LabeledContent("名称", value: vm.fileName.isEmpty ? "—" : vm.fileName)
                LabeledContent("总行数", value: vm.lineCount == 0 ? "—" : "\(vm.lineCount)")
                LabeledContent("类", value: "\(vm.classes.count)")
                LabeledContent("字段", value: "\(vm.fieldCount)")
                LabeledContent("方法", value: "\(vm.methodCount)")
                LabeledContent("解析耗时", value: String(format: "%.0f ms", vm.parseMS))
            }

            Section(header: Text("十六进制 / 十进制")) {
                TextField("0x18 或 24", text: $hexInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 14, design: .monospaced))
                LabeledContent("结果", value: hexResult)
                Button("复制结果") { copyToPasteboard(hexResult) }
            }

            Section(header: Text("操作")) {
                Button {
                    vm.showPicker = true
                } label: {
                    Label("选择 dump.cs", systemImage: "folder")
                }
                Button {
                    vm.loadFromDocuments()
                } label: {
                    Label("重新载入上次的文件", systemImage: "arrow.clockwise")
                }
                Button {
                    copyToPasteboard(vm.favorites.joined(separator: "\n"))
                } label: {
                    Label("复制收藏列表", systemImage: "doc.on.doc")
                }
            }

            Section(header: Text("关于")) {
                Text("dump.cs 查看器 · 纯本地运行，不联网，不上传任何数据")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("工具")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 文件选择器

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.plainText, .data, .item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}