# 构建脚本 QA 验证方案（build_and_run.bat / build_apk.bat）

> 工程目录：`D:\work_photos`（纯英文路径，已确认无中文/空格风险）
> 文档版本：v1.0 · QA：严过关（Yan）
> 适用范围：`build_and_run.bat`（本机跑 App）、`build_apk.bat`（打包 APK）

---

## 0. 环境基线（QA 已实测确认，作为审查依据）

| 项目 | 实测结果 | 说明 |
|------|---------|------|
| Flutter SDK | `D:\flutter` ✅ 存在 | `D:\flutter\bin\flutter.bat` 在位 |
| JDK 17 | `D:\jdk-17.0.14+7` ✅ 存在 | Gradle 需要，需设 `JAVA_HOME` |
| Android SDK | `C:\Users\19629\AppData\Local\Android\Sdk` ✅ 存在 | 需 `ANDROID_SDK_DIR` |
| `android/` 目录 | ❌ **不存在** | 首次运行场景，脚本必须处理 |
| `lib/**/*.g.dart` | ❌ **一个都没有** | `build_runner` 从未成功跑过，`.g.dart` 缺失必然编译失败 |
| `pubspec.yaml` name | `work_photos` ✅ | 与插件 `photo_manager` 已解耦（README 第六节） |
| `pubspec.lock` / `.dart_tool` | ✅ 存在（21:55） | `pub get` 曾成功，依赖已缓存 |
| 工程路径 | ✅ 纯英文无空格 | 无中文路径导致 Gradle 报错的风险 |

> ⚠️ **沙箱限制说明**：QA 侧**无法真实执行** `flutter` / `dart` 命令（Dart 无法 spawn 子进程，
> 必然报 `CreateFile failed 231 / ERROR_PIPE_BUSY`）。因此本方案以**静态审查 + 用户本机验收**为主，
> 不做agent 侧实跑。

---

## 1. 静态审查清单（逐条给出 通过 / 不通过 + 依据）

### C1. bat 文件注释是否纯英文（无任何中文字符）
- **通过标准**：全文（`REM` 注释与 `echo` 输出）无中文/全角字符。
- **审查方法**：`Grep` 搜 `[\x{4e00}-\x{9fff}]`，应 0 命中。
- **依据**：本机已踩坑——bat/ps1 带中文注释会因编码（GBK/UTF-8）错乱导致乱码甚至语法错误。
- **结果**：☐ 待审

### C2. 是否有 `CD /D %~dp0` 切目录
- **通过标准**：在执行任何 flutter 命令**之前**切换到脚本所在目录。
- **审查方法**：确认 `CD /D "%~dp0"` 出现在第一个 `flutter` 调用前；建议加引号（路径含空格时更稳）。
- **结果**：☐ 待审

### C3. 代理设置是否在开头、端口可见可改
- **通过标准**：
  - `HTTP_PROXY` / `HTTPS_PROXY`（建议同时设 `http_proxy`/`https_proxy` 小写，兼容性更好）
    在**所有网络命令之前**设置；
  - 端口 `7897` 出现在文件**顶部**的 `REM` 注释里，明写"端口可改"；
  - 不得把代理写死在文件深处。
- **结果**：☐ 待审

### C4. 权限注入是否幂等（重复运行不会插两遍）
- **通过标准**：注入前先检测 `AndroidManifest.xml` 中是否已存在 `READ_MEDIA_IMAGES`；
  已存在则跳过并打印 "already present"。
- **🔴 已知基线缺陷（必须避免复现）**：旧 `setup_b1.bat` 第 22 行用
  `-replace '</manifest>', ($p + ... + '</manifest>')` 无条件替换 —— **每跑一次就多插一遍**，
  第二次运行会出现 4 条权限。Gradle 虽可能容忍重复声明，但这是明确的幂等性缺陷，新脚本不得照抄。
- **结果**：☐ 待审

### C5. 每步是否检查 ERRORLEVEL 并在失败时停止
- **通过标准**：每个 `flutter` / `powershell` 调用后都有 `if errorlevel 1`（或
  `if not "%ERRORLEVEL%"=="0"`）判断，失败时 `echo` 明确错误原因 + `goto :fail` / `exit /b 1`。
- **特别注意**：
  - 在 `if (...)` 代码块**内部**检查 `ERRORLEVEL` 必须开 `setlocal enabledelayedexpansion`
    并用 `!ERRORLEVEL!`，否则拿到的是块执行**前**的旧值。
  - `flutter run` 属长时交互进程，其退出码检查意义有限，可只提示不强拦。
- **结果**：☐ 待审

### C6. 日志是否写入工程根目录（各自独立）
- **通过标准**：日志落在**工程根目录**（`%~dp0`）而非系统临时目录；建议 `>>` 追加并在开头写
  时间分隔行，而非每次覆盖（便于对比多次运行）。
- **结果**：☐ 待审

### C7. 是否处理「`android/` 目录不存在」的首次运行场景
- **通过标准**：`android\app\src\main\AndroidManifest.xml` 不存在时，
  ① 先自动执行 `flutter create --platforms android .` 补齐脚手架；② 或明确报错并给出处理指引。
  **不能默认目录已存在就直接注入失败**。
- **实测现状**：`android/` 确实不存在，**这是首次运行必经路径**。
- **结果**：☐ 待审

### C8. `build_apk.bat` 是否提示了 APK 输出路径
- **通过标准**：结尾 `echo` 出 APK 完整路径，默认应为
  `build\app\outputs\flutter-apk\app-release.apk`（`--release`）或 `app-debug.apk`（`--debug`），
  并提示"文件在资源管理器哪里 / 如何拷贝到手机"。
- **结果**：☐ 待审

### C9. 结尾是否 `pause`
- **通过标准**：脚本最末尾有 `pause`（或 `pause >nul` 前先输出"按任意键关闭"），
  保证双击运行时窗口不一闪而过。所有 `goto :fail` / 提前 `exit` 分支路径也应汇入同一 `pause`。
- **结果**：☐ 待审

### C10. 有无明显批处理语法错误
- **重点排查**：
  | 项 | 检查点 |
  |----|--------|
  | 括号配对 | `if (` / `for (%%a in ...)` 是否成对；`(` 与 `)` 跨行时的转义 |
  | goto/endlabel | `:fail` 等标签是否存在且拼写一致（含尾随空格会导致找不到） |
  | 延迟展开 | 块内用 `!var!` 需 `setlocal enabledelayedexpansion` |
  | 变量含空格 | `%VAR%` 展开成路径时是否加了引号 |
  | 转义 | PowerShell 内嵌命令中的 `"` 双重转义（`""`）是否正确 |
  | 中文全角 | 见 C1 |
- **结果**：☐ 待审

### D. 第二轮新增必查项（工程师实测踩坑后补充，**全部为致命级**）

以下 11 条**不是风格建议，漏掉任何一条都会导致脚本直接失效或静默死掉**。
已加入必查清单，后续任何改动都必须全部通过。

- [ ] **D1. 所有 `flutter` / `dart` 命令必须加 `call` 前缀**
  Windows 上 `flutter`/`dart` 都是 `.bat` 文件。`.bat` 里不加 `call` 直接调用会
  **转移控制权且永不返回** → 脚本在第一步后**静默结束，无任何报错**，
  看起来像"卡住了"。这是最容易漏、后果最严重的一条。
  （`powershell` 是真正的 `.exe`，**不需要** `call`。）

- [ ] **D2. 单行长度必须 < 255 字符**
  超长行会让 cmd.exe 无法定位后面的 `call :标签`。
  → `:fail_*` 的说明文字先拼进变量 `M`，再 `call :fail_step ... "%M%"`。

- [ ] **D3. 文件必须是 CRLF 换行**
  LF-only 的 `.bat` 会出现标签解析异常。

- [ ] **D4. 不得使用裸 `find` / `more`**
  会命中 Git for Windows 的 Unix 版：`find /c /v ""` 变成扫整个 C 盘（卡死），
  `more` 是分页器（等按键）。
  → 改为每步先写 `%TEMP%\work_photos_step.log`，再 `type` 到屏幕并追加进日志。

- [ ] **D5. PATH 里要加"文件夹"，不能加 `.bat` 文件路径**
  加了 `.bat` 文件路径会导致 `where flutter` **仍然找不到**。
  → 必须加 `D:\flutter\bin` 与 `D:\flutter\bin\cache\dart-sdk\bin`。

- [ ] **D6. 预检不能写成"重试循环"**
  `where flutter` 失败 → 补 PATH → `goto` 回到检查点 → **死循环**。
  → 必须是单次通过结构。

- [ ] **D7. 中文显示必须放在独立 `.bat` 中，不能用 `call :标签`**
  cmd.exe 解析 `call :标签` 时会缓存字节偏移，经过若干次 `goto` 跳转后该缓存可能失效，
  报「系统找不到指定的批处理标签」（同一标签**第一次成功、第二次失败**）。
  → 中文提示外置为 `help_zh\*.txt`（UTF-8），由 `tools\show_help.bat` 读取显示，
  且**不需要 `chcp` 切换**，不会把控制台代码页改坏。

- [ ] **D8. 两个脚本的日志文件名必须不同，且各自引用一致**
  `build_and_run.bat` → `build_run.log`；`build_apk.bat` → `build_apk.log`。
  理由：用户排错的第一动作就是"把日志发给开发/技术支持"。
  若两者共用一个文件，用户拿到运行日志准备发出、再顺手双击一次打包，
  **那份待发日志会被静默销毁**，属实质损失。
  → 复核口径：两个 bat 的 `set "LOG="` 指向不同文件名；
  `echo`/用户可见文案与 `help_zh\*.txt`、README 中的日志名与之**保持一致**；
  不允许出现"统一日志名"的后续改动。
  → 核查时用「剔除 `REM` 注释行」的口径，只看**功能性**引用。

- [ ] **D9. 共用帮助文本必须与调用它的脚本匹配**
  `99_errors.txt` 被**两个脚本共用**（`build_and_run.bat` 与 `build_apk.bat` 都会调用）。
  若共用文件里写死某个脚本专属的文件名（如"把 `build_run.log` 发给开发"），
  另一个脚本的用户会被误导去打开错误的、或压根不存在的文件。
  → 共用帮助文本应写成**脚本无关的中性表述**，或按脚本拆分多个错误页。

- [ ] **D10. 改名类改动必须做"引用完整性"全量扫描**
  第 3 轮的教训：把 `build_run.log` 改成 `build_apk.log` 后，
  改了 bat 里的 `echo` 与 `M` 变量，**却漏了 3 处共用帮助文本**，
  以及本文档内 3 处同类表述。**改一个名字，要找出它出现的所有地方。**
  → 扫描口径：把该字符串在**全部** `.bat` / `.ps1` / `.md` / `help_zh\*.txt` 中
  逐个列出，再按「功能性引用 / 说明性引用」分类确认，**不要只扫当前改动的那个文件**。
  → 特别注意**被多个文件共用**的文本（`99_errors.txt` 就是典型），
  以及**面向用户的排错指引**——指引指错文件等于把用户引向二次返工。

- [ ] **D11. `set` 变量值中的 cmd 特殊字符必须移除或转义，且必须实测运行时真值**
  cmd 特殊字符（`|` `&` `>` `<` `^`）出现在 `set` 变量值时必须转义，
  或在不影响功能时**直接移除**；`set "VAR=value"` 的外层引号
  **不足以保护管道符**——引号只保住 `set` 这一行不被劈断，
  变量真值里仍然是裸 `|`，任何不带引号展开它的下游 `.bat` 都会再次被劈断。
  → **本机真实事故**：`GRADLE_OPTS` 里的 `-Dhttp.nonProxyHosts=localhost|127.0.0.1`
    在 `android\gradlew.bat` 第 75 行被**不带引号**展开
    （`"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=..."`），
    cmd 在管道处把 java 命令行劈成两半 →
    `'127.0.0.1' 不是内部或外部命令` → java 根本没启动 → **Gradle exit 255**。
  → **预期修法是「移除该参数」，不是「转义管道符」。** 写作 `^|` 时，
    `set "VAR=...^|..."` 会把 caret 一并存进真值（实测真值为 `localhost^|127.0.0.1`），
    它"看上去能用"只是因为 gradlew.bat 恰好不带引号展开，
    Gradle 一升级就可能静默失效。**任何人不得再把这段加回去。**
  → **验证口径（不可只看代码）**：写一个临时 `.bat` 执行同一条 `set`，
    用 `> file set VAR`（不要用不带引号的 `echo %VAR%`，它自己也会被管道劈断而误判）
    把**运行时实际值**导出，再读文件核对：值未截断、无残留 `^`、无引号。
    若该变量还会被子 `.bat` 展开，必须再加一层子脚本探针
    （子脚本里写 `echo java %VAR% ...`），确认不会复现「'xxx' 不是内部或外部命令」。
  → 验证结束后**必须删除全部临时探针与输出文件**，避免污染工程。

---

## 0bis. 本次验证记录（GRADLE_OPTS 管道符事故，第 4 轮）

| 项 | 结果 |
|----|------|
| 修复方案 | **移除** `-Dhttp.nonProxyHosts=localhost\|127.0.0.1`（非转义），保留四个 `proxyHost/proxyPort` |
| 落盘位置 | `build_apk.bat` 第 92 行、`build_and_run.bat` 第 94 行（各配 14 行英文注释说明原因） |
| 运行时实测值 | `GRADLE_OPTS=-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7897 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7897` |
| 字节证据 | 导出值 hexdump 无 `7c`（`\|`）、无 `5e`（`^`），结尾仅 `0d 0a` |
| 子脚本探针 | 子 `.bat` 不带引号展开 `%GRADLE_OPTS%` 后正常执行，无「不是内部或外部命令」，退出码 0 |
| 结论 | ✅ **已修复，放行** |

> 排错提示：今后若再遇到 `'xxx' 不是内部或外部命令，也不是可运行的程序或批处理文件`
> 这类报错，**优先怀疑某个 `set` 变量值里混入了未转义（或未移除）的 cmd 特殊字符**，
> 而不是先怀疑工具未安装或 PATH 配置错误。

---

## 1bis. 关于日志覆盖 vs 追加（C6 的结论修订）

我最初建议"追加不覆盖"，工程师选择了**每次覆盖**并在第 2 轮提出理由：
> 覆盖式日志不会和上次的残留内容混在一起，用户发日志给开发时不会误判。

**QA 接受该理由，撤回原建议。** 理由成立：双击脚本的用户是"跑一次、看一份日志"的
非技术用户，日志与某一次运行**严格对应**比"保留历史"更有价值，
混在一起的日志反而会让人误判故障发生在哪一步。

**✅ 该副作用已修复。** 两个脚本各自独立日志：
`build_and_run.bat` → `build_run.log`，`build_apk.bat` → `build_apk.log`，
**互不覆盖**。原先共用一个文件会毁掉用户"正准备发出去"的日志，属实质损失，故已拆分。
详见必查项 **D8**。

---


### A1. 🔴 Gradle 不读 `HTTP_PROXY` 环境变量 —— 首次构建大概率卡在下载
`dart pub` 认 `HTTP_PROXY/HTTPS_PROXY`，但 **Android Gradle Plugin 不认**，
它只读 `~/.gradle/gradle.properties` 里的 `systemProp.http.proxyHost/Port`，
或 `JAVA_OPTS` / `GRADLE_OPTS`。
→ 后果：`flutter run` / `build apk` 首次要下载 Gradle 发行包 + Android 依赖，
若这一步不走代理就会长时间 `Downloading...` 直到超时。
**期望**：脚本在 `build_apk.bat`（及 `build_and_run.bat` 的 build 阶段）中，
额外提示或写入 Gradle 代理配置。

### A2. `flutter create .` 的覆盖风险需有备份兜底
`flutter create --platforms android .` 对**已存在**的文件默认不覆盖（除非加 `--overwrite`），
但它**会**再生成/刷新部分托管文件（`.metadata`、`.gitignore`、`analysis_options.yaml` 等），
且 `pubspec.yaml` 的处理随 Flutter 版本而异。
→ **期望**：脚本在执行 `flutter create` 前，把 `pubspec.yaml` 与 `lib/` 做一次备份
（或至少 `copy /Y` 一份 `pubspec.yaml` → `pubspec.yaml.bak`）。

### A3. `JAVA_HOME` / `ANDROID_SDK_DIR` 与 `where flutter` 兜底
本机 Flutter 在 `D:\flutter`，**不保证已在 PATH**。
→ **期望**：脚本检查 `where flutter`，找不到时用 `D:\flutter\bin\flutter.bat` 兜底；
并显式设置 `JAVA_HOME=D:\jdk-17.0.14+7`、`ANDROID_SDK_DIR=C:\Users\19629\AppData\Local\Android\Sdk`。
建议在用户验收清单里加一步 `flutter doctor`。

### A4. `build_runner` 从未成功跑过（最高风险项）
`lib/` 下**零个 `.g.dart`**。`build_runner build` 是本工程**唯一**能生成
`app_database.g.dart` 的手段；未生成必然编译失败。
→ **期望**：`build_and_run.bat` 与 `build_apk.bat` 都必须跑 `build_runner`；
失败时错误提示要指向"这是 Dart 代码/依赖问题，不是脚本问题"（见第 4 节）。

### A5. `flutter pub run` 已废弃
新版 Flutter 提示 `flutter pub run` 已弃用，推荐 `dart run build_runner build`。
→ 期望：用 `dart run build_runner build --delete-conflicting-outputs`
（或 `flutter pub run` 亦可，但需容忍一条 deprecation 警告）。

---

## 3. 给用户的本机验收清单（假设您完全不懂技术）

> 前提：**Clash 代理已启动**（127.0.0.1:7897），手机已开 USB 调试并连上电脑。
> 首次运行需要下载依赖，**10–30 分钟属正常**，请不要中途关窗口。

### 第 0 步：确认工具链（只做一次）
1. 按 `Win` 键，输入 `cmd`，回车。
2. 依次输入下面三行，每行回车：
   ```
   D:\flutter\bin\flutter.bat doctor
   ```
3. **成功标志**：输出里 Flutter / Android toolchain 两项**没有红色叉**；
   若 Android toolchain 报 `licenses not accepted`，执行
   `D:\flutter\bin\flutter.bat doctor --android-licenses`，一路输入 `y` 回车。
4. 若 doctor 报 `Unknown command` 或命令不存在 → 说明 Flutter 路径不对，请把报错发给技术支持。

### 第 1 步：跑 App（`build_and_run.bat`）
1. 打开 `D:\work_photos` 文件夹。
2. **双击 `build_and_run.bat`**。
3. **成功标志（按顺序看到）**：
   - 黑色的命令行窗口**不会闪退**，停在窗口里；
   - 看到 `[1/x]`、`[2/x]`… 这样的**步骤编号**逐步推进；
   - 出现 `Permissions injected ...` 或 `already present`（权限相关提示）；
   - `Resolving dependencies...` → `Got dependencies!`；
   - `build_runner` 阶段出现 `Succeeded after ...`；
   - 最后出现 `Launching lib/main.dart on ...`，手机屏幕上**自动装上并打开** App。
4. 手机上**首次运行**会弹出相册权限框 → 点**允许**。
5. **验收 App**：底部四个页签能切换——仪表盘 / 分类 / 导入 / 网格。
6. 结束：回到黑色窗口按 `q` 回车（或 Ctrl+C）停止 App，再按任意键关窗。

### 第 2 步：打包 APK（`build_apk.bat`）
1. 同一文件夹，双击 `build_apk.bat`。
2. **成功标志**：
   - 同样有步骤编号推进，窗口不闪退；
   - Gradle 阶段第一次会**下载**依赖（可能 5–20 分钟，屏幕滚动很快是正常的）；
   - 最后出现 `Built build\app\outputs\flutter-apk\...apk` 且**屏幕上直接打印出 APK 的完整路径**。
3. 把这个 APK 拷到手机安装：把 `.apk` 文件发到微信/QQ 传到手机 → 点击安装 →
   系统提示"允许安装未知应用" → 允许。
4. 安装后打开 App，权限弹窗点**允许**。

### 第 3 步：看日志
1. 跑完 `build_and_run.bat` 后，同一文件夹里应出现 **`build_run.log`**；
   若跑过 `build_apk.bat`，则另外出现 **`build_apk.log`**，两者**互不覆盖**。
2. 出问题时，把对应那一份**整个发给技术支持**——里面记录了每一步的输出，比截图有用得多。

### 第 4 步：如果卡在 Gradle 下载（重要）
首次打包时**最可能**卡住的地方：屏幕停在 `Downloading...` 或
`Configure project :app` 长时间不动，因为要下载 Gradle 和 Android 编译组件。

1. **先等 10 分钟**，首次下载确实慢。
2. 15 分钟仍无进展 → **不要反复重试**，直接：
   把 **`build_apk.log`**（打包脚本的日志）发给技术支持，并说明一句"**卡在 Gradle 下载**"。
3. 技术支持会需要你本机的 Gradle 代理配置（脚本已尽力自动配置，
   但某些 Gradle 版本还需要额外一步）。

### 出错了怎么办（对照处理）

| 屏幕上出现 | 含义 | 你该做什么 |
|-----------|------|-----------|
| `'flutter' 不是内部或外部命令` | Flutter 不在 PATH | 找技术支持，或用 `D:\flutter\bin\` 下的完整路径 |
| 卡在 `Downloading...` 很久不动 | 代理没生效 / 网络慢 | 确认 Clash 已在**代理模式**且能刷网页；等待或重启脚本 |
| `Failed to find a target named ...` / `No such method` | **Dart 代码问题**，不是脚本问题 | 把报错发给技术支持，改代码 |
| `Could not find a set of Flutter SDK` | 路径/环境变量错 | 找技术支持 |
| `Gradle build failed` + 网络超时 | Gradle 不走代理（见 A1） | 找技术支持，需配 Gradle 代理 |
| **`'127.0.0.1' 不是内部或外部命令` 且 Gradle 报 exit 255** | ✅ **已修复**（第 4 轮）。原因为 `GRADLE_OPTS` 里的管道符被 cmd 当命令分隔符，现已移除该参数 | 若仍出现，请确认自己拿的是最新版脚本；并把 `build_apk.log` 发给技术支持 |
| 其它 `'xxx' 不是内部或外部命令` | **优先怀疑某个 `set` 变量值里有未转义/未移除的 cmd 特殊字符**（`\|` `&` `>` `<` `^`），见 D11 | 不要先怀疑工具没装；把完整报错发给技术支持，并核对脚本里所有 `set` 语句的值 |
| 权限弹窗没出现 | Manifest 未注入成功 | 看对应日志（跑 App 看 `build_run.log`，打包看 `build_apk.log`）是否有 `already present` 之外的报错 |
| 窗口一闪而过 | 缺 `pause`（见 C9） | 改用"在地址栏输入 `cmd` 回车 → 拖入 bat 文件"的方式运行，可保留窗口 |

---

## 4. 风险提示（务必先看）

1. **首次 build_runner 很慢，且从未在本机成功过。** `lib/` 下目前没有任何 `.g.dart`。
   `build_runner` 要解析全量 AST + 生成 Drift 代码，5–15 分钟属正常。
   ⚠️ 若它**报错**，那几乎一定是 **Dart 代码或依赖版本问题，不是脚本问题**——
   报错信息形如 `sealed class ... doesn't extend`、`Could not resolve package`、
   `Bad state: ...` 之类。请把原文发给技术支持，不要反复重跑脚本。

2. **必须全程联网。** 三处都要下载：`pub get`（pub.dev，需代理）、
   `build_runner`（pub 依赖，需代理）、Gradle（Google Maven + Gradle 发行包）。
   Clash 中途关闭会直接导致失败。

3. **Gradle 代理已配，但仍需留意**。脚本已设 `GRADLE_OPTS`（`-Dhttp.proxyHost/Port`、
   `-Dhttps.proxyHost/Port`，已**移除**会引发管道的 `nonProxyHosts` 一段，见 D11）
   与 `JAVA_HOME`/`ANDROID_SDK_DIR`。若首次打包仍卡在 `Downloading...` 不动，
   说明该 Gradle 版本还需要 `~/.gradle/gradle.properties` 里的 `systemProp.*`。
   → **处理办法**：把 **`build_apk.log`** 发给技术支持，并说明"卡在 Gradle 下载"。

4. **两个脚本日志已分离，不会互相覆盖**：`build_run.log` 与 `build_apk.log` 各自独立，
   打包不会毁掉待发的运行日志（见 D8）。

5. **`flutter create` 是有副作用的**。本工程目前**没有** `android/` 目录，
   脚本会先生成它。若 Flutter 版本变化导致 `flutter create` 意外覆盖
   `pubspec.yaml`，会破坏依赖声明（详见 A2）。**首次运行后建议立刻备份整个工程**。

6. **手机必须开 USB 调试**并信任此电脑，否则 `flutter run` 会一直停在等待设备。

7. **不要把工程移到中文路径下**。当前路径 `D:\work_photos`
   是纯英文的，**请保持不变**——中文路径会导致 Android/Gradle 编译报错。

8. **端口 7897 与代理地址集中在脚本顶部**，若你换端口，只需改那一处。

---

## 5. 审查结论（QA 填写）

**受审文件**（第 2 轮定稿）：`build_and_run.bat`(412行)、`build_apk.bat`(368行)、
`tools\inject_permissions.ps1`(111行)、`tools\show_help.bat`(38行)、`help_zh\*.txt`(9个)

### 结论：**IS_PASS = ✅ YES**

第 1 轮的两个 BLOCKER 均已修复，7 项附加发现全部处理完毕，
C1–C10 + D1–D9 全部通过。**可以交付用户本机验收。**

> **第 4 轮增量结论（GRADLE_OPTS 管道符事故回归）**：✅ **同样 PASS，放行。**
> 详见「0bis. 本次验证记录」。修复采用**移除** `-Dhttp.nonProxyHosts=...` 而非转义，
> 两脚本改法一致；回归项（纯 ASCII / CRLF / 无 BOM / D1 / D2 / D5 / D8 / 变量引用）全部保持；
> 新增 D11 已入必查清单，并明确"预期修法是移除、不得再加回去"。

---

### 5.1 第 1 轮 BLOCKER 修复确认

| BLOCKER | 修复方式 | 验证结果 |
|---------|---------|---------|
| **BLOCKER-1** flutter/dart 不在 PATH | 增加 PATH 兜底：检测 `where flutter` 失败后，若 `%FLUTTER_FALLBACK%` 存在则 `set "PATH=%FLUTTER_BIN_DIR%;%DART_BIN_DIR%;%PATH%"`，并提示用户永久修改方式 | ✅ **通过**。且正确遵守了 D5：加的是**文件夹**（`D:\flutter\bin`、`D:\flutter\bin\cache\dart-sdk\bin`）而非 `.bat` 文件路径。**实测两个目录均真实存在**，`dart.exe` 就在 `D:\flutter\bin\cache\dart-sdk\bin\` 下，兜底后 `where dart` 能找到 |
| **BLOCKER-2** Gradle 不认 HTTP_PROXY | 增加 `GRADLE_OPTS=-Dhttp.proxyHost/-Dhttp.proxyPort/-Dhttps.proxyHost/-Dhttps.proxyPort`，并显式设 `JAVA_HOME`/`ANDROID_SDK_DIR`/`ANDROID_HOME` | ✅ **通过**。⚠️ **历史修正**：本行原写"额外加了 `-Dhttp.nonProxyHosts=localhost\|127.0.0.1`"，该写法**是第 4 轮事故的根因**（见 D11 / 0bis），现已移除。当前 `GRADLE_OPTS` 仅保留四个 proxyHost/proxyPort 参数，**运行时真值已实测确认无 `\|`、无 `^`**（见 0bis）。实测 `D:\jdk-17.0.14+7` 与 Android SDK 目录均存在 |

### 5.2 C1–C10 逐条复核（全通过）

| # | 检查项 | 结论 | 复核依据 |
|---|--------|------|---------|
| C1 | 纯英文注释 | ✅ | **non-ascii 字节数 = 0**（三个 .bat 全量字节扫描），比第一轮的正则匹配更严格 |
| C2 | `CD /D %~dp0` | ✅ | `set "ROOT=%~dp0"` → `cd /D "%ROOT%"`，仍在所有命令之前，带引号 |
| C3 | 代理开头可改 | ✅ | 顶部 USER SETTINGS 块；大/小写 4 变量 + NO_PROXY；新增 `GRADLE_OPTS`；开头醒目 PROXY WARNING |
| C4 | 权限注入幂等 | ✅ | **QA 独立实测验证**（见 5.3） |
| C5 | ERRORLEVEL 检查 | ✅ | 改为 `call :begin_step` / `call :end_step` 子程序模式，`:end_step` 首行 `set "RC=!ERRORLEVEL!"` 在 `type` 覆盖前捕获，并用 `!` 延迟展开规避块内解析时序问题——**这个实现比第一轮更严谨**。build_runner 仍有双路径降级 |
| C6 | 日志落工程根 | ✅ | `build_and_run.bat` → `%ROOT%build_run.log`；`build_apk.bat` → `%ROOT%build_apk.log`；两者独立，**同名脚本重复运行才覆盖各自日志**（符合预期，见 D8） |
| C7 | 首次无 android/ | ✅ | `if exist MANIFEST goto skip` → 否则 flutter create → **之后二次校验**，幂等 |
| C8 | APK 路径提示 | ✅ | 打印完整路径 + `dir /b *.apk` 实际列表 + `adb install -r` 与"拷到手机"双指引 |
| C9 | 结尾 pause | ✅ | `:the_end` 唯一收口，`pause` 计数 = 1，所有 `:fail_*` 均 `goto :the_end`，无一条能绕过 |
| C10 | 批处理语法 | ✅ | 详见 5.3 |

### 5.3 C4/C10 深度验证（QA 独立实测，非采信工程师自述）

**C4 幂等性 —— 我真的把 ps1 跑了 3 遍：**
```
RUN 1: [add] READ_MEDIA_IMAGES + [add] READ_EXTERNAL_STORAGE，写入 2 行，exit=0
RUN 2: [skip] ×2，"Nothing to do"，exit=0
RUN 3: [skip] ×2，"Nothing to do"，exit=0
最终：READ_MEDIA_IMAGES 计数=1，READ_EXTERNAL_STORAGE 计数=1，uses-permission 总数=2
权限落位：</application> 之后、</manifest> 之前 ✅
BOM检查：首 3 字节 = 60,63,120（即 "<?x"，非 EF BB BF）→ 无 BOM ✅
.bak 备份：已生成 ✅
```

**补充边界用例（工程师声称但未展示的）：**
- **单引号 + 无空格写法** `<uses-permission android:name='android.permission.READ_MEDIA_IMAGES'/>`
  → 正确识别为 `[skip]`（未重复插入），只补另一条 → 总数仍为 2 ✅
  （实现用的是正则 `android:name\s*=\s*['"]NAME['"]`，比第一轮的纯 `.Contains()` 更健壮，能容忍单/双引号与空格差异）
- **manifest 不存在** → 打印 ERROR+HINT，`exit=2` ✅
- **无 `</manifest>` 闭合标签** → 打印"文件已损坏"+删除 android 目录的指引，`exit=3` ✅

**C10 批处理语法 —— 全量机械校验：**
| 校验项 | build_and_run.bat | build_apk.bat | show_help.bat |
|--------|------------------|---------------|--------------|
| CRLF 一致性 | 412/412 ✅ | 368/368 ✅ | 38/38 ✅ |
| non-ascii 字节 | 0 ✅ | 0 ✅ | 0 ✅ |
| **单行 > 255 字符** | **0 行**（最长 180）✅ | **0 行**（最长 180）✅ | **0 行**（最长 121）✅ |
| 括号配平（剔除 `echo(`） | 13/13 ✅ | 7/7 ✅ | 0/0 ✅ |
| 未定义 goto/call 目标 | **无** ✅ | **无** ✅ | **无** ✅ |
| 从未被引用的标签 | 无 ✅ | 无 ✅ | 无 ✅ |
| 未加 `call` 的 flutter/dart | **0 处** ✅ | **0 处** ✅ | — |
| `pause` 数量 | 1 ✅ | 1 ✅ | — |

**D1 逐条核验**：11 处 flutter/dart 调用**全部**已加 `call` 前缀；
2 处 `powershell`（真 `.exe`）**正确地未加** `call`——这个区分很专业，
说明工程师理解的是"控制权转移"本质而非无脑加前缀。

**D6 复核预检结构**：`where flutter` → 失败则补 PATH → **单向向下**落到
`:preflight_flutter_ok` 再验一次 → 仍失败才 `goto :fail_no_flutter`。
是**单次通过**，不存在回跳，**无死循环风险** ✅

**D7 复核**：`show_help.bat` 用 `Get-Content -Encoding UTF8` 读取，
**不再用 `chcp` 切换**，控制台代码页零污染；且文件缺失/powershell 缺失时
`goto :done` 静默跳过（帮助文字永远不该阻断构建）——容错设计正确 ✅

### 5.4 遗留问题 / 已知限制（不阻塞交付）

1. **Gradle 代理是否真生效，只能首次 build 时验证。** 静态只能确认变量写对。
   若用户首次 `build apk` 仍卡在 `Downloading...`，
   说明该 Gradle 版本/场景仍需 `~/.gradle/gradle.properties` 的
   `systemProp.*`（`GRADLE_OPTS` 对 Gradle daemon 的代理生效性依版本而异）。
   → 已写入用户验收清单第 4 节的排查路径。
2. **沙箱限制**：agent 侧无法实跑 flutter/dart（Dart 无法 spawn 子进程，
   必报 `CreateFile failed 231 / ERROR_PIPE_BUSY`），故"端到端跑通"需用户本机验证。
   工程师用 stub 可执行文件做的控制流验证与我的静态校验结论一致，互为印证。
3. ⚠️ **最大不确定项：`build_runner` 从未在本机成功过。**
   `lib/` 下**零个 `.g.dart`**，该步骤是唯一能生成 `app_database.g.dart` 的手段。
   若失败，几乎必然是 **Dart 代码/依赖问题而非脚本问题**。
   脚本已在 `:fail_codegen` 做了正确引导（明确写"NOT because of the network"、
   指引看 `Error` 开头的行、按文件+行号定位）。
4. **未验证项**：`flutter doctor` 是否全绿、Android SDK 许可是否已接受。

### 5.5 交付结论

✅ **可以交付用户本机验收。** 第 3 节用户验收清单（按"完全不懂技术"编写，
含每步成功标志与 8 种常见报错对照表）与第 4 节风险提示已同步更新，
用户按清单执行即可；出问题把对应那一份日志发回即可定位
（`build_and_run.bat` → `build_run.log`，`build_apk.bat` → `build_apk.log`）。