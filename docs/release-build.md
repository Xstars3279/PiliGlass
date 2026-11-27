# PiliGlass Android 打包与 GitHub 发布指南

本文档记录 PiliGlass（`arm64-v8a`）本地正式签名打包、校验、发布 GitHub Release，以及日常 `dev` 调试安装的完整流程，避免因缺少签名配置或版本号参数导致无法覆盖安装。

---

## 一、环境与签名准备

1. **Flutter 与 Pub 缓存环境变量（PowerShell）**

   ```powershell
   $env:FLUTTER_ROOT = "D:\dev\flutter-3.47.9\flutter"
   $env:PUB_CACHE = "D:\dev\pub-cache"
   $env:PATH = "D:\dev\flutter-3.47.9\flutter\bin;$env:PATH"
   Set-Location D:\dev\PiliPlus-sync-2.2.1
   ```

2. **检查正式签名配置**
   - 确认 `android\key.properties` 存在，且指向正式密钥文件（例如 `D:\dev\keys\piliglass-release.jks`）。
   - `android\.gitignore` 已忽略 `key.properties` 与 `*.jks`，不要将密钥文件提交进 Git。
   - 若新迁工程目录缺少 `android\key.properties`，Gradle 会回退到 `Android Debug` 证书，导致手机端提示「**软件包与现有软件包存在冲突 / 开发者签名有异常**」。

---

## 二、版本号约定

- **PiliGlass 版本号（`--build-name` / `pili.name`）**：使用不带 `v` 的版本号（如 `0.2.2`）。应用内检查更新时会自动去掉 GitHub Tag 的 `v` 前缀再做分段比较。
- **Android `versionCode`（`--build-number` / `pili.code`）**：使用当前提交数 `git rev-list --count HEAD`（例如 `5791`，高于 `v0.2.1` 的 `5660`）。
  - 若省略 `--build-name` / `--build-number`，Gradle 会读取 `pubspec.yaml` 中上游同步过来的 `2.2.1+1`（`versionCode=1`），导致手机端提示「**已存在更高版本“0.2.1”**」而无法覆盖安装。

---

## 三、编译 GitHub 正式发布包

> 不传 `--android-project-arg dev=1` 时，包名为 `io.github.xstars3279.piliglass`，使用 `android\key.properties` 中的正式密钥签名。

```powershell
$ver  = "0.2.2"
$code = [int](git rev-list --count HEAD).Trim()
$hash = (git rev-parse --short HEAD).Trim()
$ts   = [int][DateTimeOffset]::Now.ToUnixTimeSeconds()

flutter build apk --release --target-platform android-arm64 --no-pub `
  --build-name=$ver `
  --build-number=$code `
  --dart-define=pili.name=$ver `
  --dart-define=pili.code=$code `
  --dart-define=pili.hash=$hash `
  --dart-define=pili.time=$ts

Copy-Item `
  build\app\outputs\flutter-apk\app-release.apk `
  "build\app\outputs\flutter-apk\PiliGlass-v$ver-arm64-v8a.apk" `
  -Force
```

---

## 四、打包产物校验

发布前务必确认**包名、版本号、`versionCode`、签名证书**全部正确：

```powershell
$apk = "D:\dev\PiliPlus-sync-2.2.1\build\app\outputs\flutter-apk\PiliGlass-v0.2.2-arm64-v8a.apk"

$aapt2 = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Filter aapt2.exe -Recurse |
  Select-Object -First 1 -ExpandProperty FullName
& $aapt2 dump badging $apk | Select-String "package:"

$apksigner = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Filter apksigner.bat -Recurse |
  Select-Object -First 1 -ExpandProperty FullName
& $apksigner verify --print-certs $apk
```

预期输出关键字段：

- `package: name='io.github.xstars3279.piliglass' versionCode='5791' versionName='0.2.2'`
- `Signer #1 certificate DN: CN=PiliGlass, O=Xstars3279`
- `Signer #1 certificate SHA-256 digest: d53645782013e1a4b5e3a7853c4a36e8c340c8cba8ed76e68cbf82fe8ef78436`

---

## 五、推送代码并发布 GitHub Release

1. 撰写并提交发布说明（如 `docs/release-v0.2.2.md`）：

   ```powershell
   git add docs/release-v0.2.2.md
   git commit -m "docs(release): the v0.2.2 notes"
   git tag v0.2.2
   git push origin HEAD:main v0.2.2
   ```

2. 创建 Pre-release（仓库参数 `-R Xstars3279/PiliGlass`，避免 `gh` 默认指向上游仓库）：

   ```powershell
   gh release create v0.2.2 -R Xstars3279/PiliGlass `
     --prerelease `
     --title "PiliGlass v0.2.2" `
     --notes-file docs/release-v0.2.2.md `
     "build\app\outputs\flutter-apk\PiliGlass-v0.2.2-arm64-v8a.apk"
   ```

3. 若需要替换已发布 Release 上的安装包，使用 `--clobber` 覆盖上传（注意会重置该附件的下载计数）：

   ```powershell
   gh release upload v0.2.2 -R Xstars3279/PiliGlass --clobber `
     "build\app\outputs\flutter-apk\PiliGlass-v0.2.2-arm64-v8a.apk"
   ```

---

## 六、日常本地 `dev` 版编译与真机 root 安装

日常开发测试传 `--android-project-arg dev=1`（包名 `com.example.piliplus.dev`，固定用 debug 签名，与正式版共存，可不传正式版本号参数）：

```powershell
flutter build apk --release --target-platform android-arm64 --android-project-arg dev=1 --no-pub
adb push build\app\outputs\flutter-apk\app-release.apk /data/local/tmp/pg-dev.apk
adb shell "su -c 'pm install -r /data/local/tmp/pg-dev.apk'"
```

---

## 七、常见问题排查

| 提示现象 | 原因 | 处理方式 |
| --- | --- | --- |
| 提示「已存在更高版本“0.2.1”」 | 未传 `--build-number`，`versionCode` 回退为 `pubspec.yaml` 中的 `1` | 传入 `--build-name` 与 `git rev-list --count HEAD` 作为 `--build-number` |
| 提示「软件包与现有软件包存在冲突 / 开发者签名有异常」 | 缺少 `android\key.properties`，用成了 debug 签名 | 补齐 `android\key.properties`（指向 `piliglass-release.jks`）后重新编译 |
| 更新弹窗或关于页版本显示异常（`SNAPSHOT` / `2.2.1`） | 未传入 `--dart-define=pili.name=...` 等参数 | 编译时补全 `pili.name` / `pili.code` / `pili.hash` / `pili.time` |
