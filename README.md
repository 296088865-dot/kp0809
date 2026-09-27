# dump.cs Viewer (iOS)

一个原生的 iOS App，用来查看 Il2CppDumper 生成的 `dump.cs`。
纯本地运行，不联网，不上传任何数据。

## 功能

- 载入 `dump.cs`，解析出全部类型 / 字段 / 方法
- 字段显示 `类型 + 名字 + 0x偏移`，点一下直接复制偏移
- 方法显示完整签名 + `RVA / Offset / VA`，点一下复制偏移
- 按类名、命名空间实时搜索
- 成员搜索：单独搜字段名 / 方法名，直接跳回所属类
- 收藏类，退出重进还在
- 自动记住上次载入的文件，下次打开直接就有
- 内置十六进制 ↔ 十进制转换

## 三种载入方式

1. App 内点右上角文件夹按钮 → 从"文件"里选
2. Filza 里长按 `dump.cs` → 打开方式 → `dump.cs`（本 App）
3. 把 `dump.cs` 改名为 `current.cs` 放进 App 的 Documents 目录（需开启文件共享）

## 构建

**这台设备上没法编译**，需要一个 macOS 环境。
最简单的办法是让 GitHub 免费帮你编：

1. 注册 / 登录 https://github.com
2. 右上角 `+` → New repository，名字随便（比如 `dumpviewer`），选 **Public**，Create
3. 进到新仓库，点 **Add file → Upload files**
4. 把本目录下这些东西全部拖进去上传（注意 `.github` 文件夹也要，用 Filza 打包成 zip 再传也行）：
   - `Sources/` 整个目录
   - `Tools/` 整个目录
   - `.github/workflows/build.yml`
   - `Info.plist`
   - `build.sh`
   - `README.md`
5. 上传完点 **Commit changes**
6. 点仓库顶部的 **Actions** 标签，会看到正在跑 `Build IPA`
7. 等 3~5 分钟，跑完后点进去，页面底部 **Artifacts** 里下载 `DumpViewer-ipa`
8. 下载得到的是一个 zip（GitHub 会自动压缩），用 Filza 解压出 `DumpViewer.ipa`
9. 打开 **TrollStore** → 右上角 `+` → 选那个 ipa → 安装

装完桌面上就有一个图标，点开就能用。

## 备注

- 最低系统 iOS 16.0
- 只编译 arm64
- 大文件（20MB 量级）解析大概几秒，界面上有进度提示
- 图标是脚本自动画的，想换就改 `Tools/make-icon.swift`
