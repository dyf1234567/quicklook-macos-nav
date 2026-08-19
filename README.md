# QuickLook macOS-style Navigation Build

给 [QuickLook](https://github.com/QL-Win/QuickLook)（Windows 版 macOS Quick Look 空格预览工具）打的一个小补丁，让图片预览支持 **macOS 式的键盘方向键导航**，并在此基础上支持 **鼠标悬停接管方向键**。

基于官方 **v4.5.0**（`4.5.0` tag）源码修改，只动了主程序，不涉及插件。可直接替换安装，也可自行编译。

---

## 为什么会有这个项目

原版 QuickLook 的图片切换**完全依赖资源管理器**：它每 500ms 轮询一次"前台窗口当前选中的文件"，跟随你在大资源管理器里移动选中项来切图。由此带来两个问题：

1. **预览窗口会抢焦点**：点击或拖动预览窗口后，焦点从资源管理器转移到了预览窗口，跟随机制立即暂停，方向键怎么按都没反应。
2. **焦点不在文件管理器时就完全失效**：一旦你切到浏览器、聊天窗口等其他应用，前台窗口不是文件管理器，切换直接罢工。

简单说：原版是"你在资源管理器里选哪个，我就看哪个"，而不是"预览窗口自己会切图"。

本补丁把行为改成了 macOS Quick Look 的样子：**预览窗口自己响应方向键**，不依赖资源管理器；并且支持 **鼠标悬停在预览窗口上时接管方向键**，鼠标移开就还给当前应用。

---

## 功能特性

### 1. 焦点在预览窗口时，方向键直接切图
- 打开图片预览 → 点击预览窗口 → 按方向键即切换同目录文件。
- 切换**即时**，不经过 500ms 轮询，无延迟。
- 不依赖资源管理器选中项，资源管理器在不在前台都无所谓。

### 2. 鼠标悬停在预览窗口上时，方向键被预览接管
- 场景：浏览器在前台，鼠标移到预览窗口上 → 按方向键切换图片，且按键被**吞掉**（浏览器不会跟着滚动/移动光标）。
- 鼠标移出预览窗口 → 方向键**原样**还给当前应用，不影响浏览器翻页、输入框移动光标等任何正常用途。
- 判定依据是**鼠标位置**（不是键盘焦点），这就是"鼠标在哪归哪"的体验。

### 3. 原有行为完全保留
- 在资源管理器里按方向键移动选中、预览跟随，依然照常工作。
- 空格开关预览、Esc 关闭、F11 全屏等快捷键不变。

---

## 按键说明

| 按键 | 行为 |
|---|---|
| `←` / `↑` | 上一个文件 |
| `→` / `↓` | 下一个文件 |

切换范围：当前文件所在目录内的**所有文件**（按文件名排序，包含子目录外的同级文件），不只是图片。如果你希望只切图片，可以在源码 `ViewWindowManager.cs` 的 `GetAdjacentFile()` 里加扩展名过滤。

---

## 安装

### 方式 A：直接用编译好的 exe（最快）

`dist/QuickLook.exe` 是编译好的完整版（12MB，依赖已内嵌）。

1. 退出 QuickLook（右键托盘图标退出，或任务管理器结束 `QuickLook.exe`）。
2. 备份原文件：把 `%LOCALAPPDATA%\Programs\QuickLook\QuickLook.exe` 复制一份留底。
3. 把 `dist/QuickLook.exe` 复制过去覆盖。
4. 重启 QuickLook。
5. （推荐）编辑 `%APPDATA%\pooi.moe\QuickLook\QuickLook.config`：
   - `<Topmost>True</Topmost>` —— 预览窗口置顶，鼠标才能悬停在它上面
   - `<DisableAutoUpdateCheck>True</DisableAutoUpdateCheck>` —— 防止官方自动更新覆盖本补丁

### 方式 B：用脚本安装 / 回滚

```powershell
# 安装（自动备份原版、替换、设置 Topmost、禁用自动更新）
powershell -ExecutionPolicy Bypass -File scripts/install.ps1

# 只备份
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -BackupOnly

# 从备份还原原版
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -Restore
```

---

## 自行编译

```powershell
# 一键脚本：装 SDK → 拉 4.5.0 源码 → 打补丁 → 编译 → 输出到 dist/
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

### 手动步骤（等价）

1. 安装 .NET SDK 9（任意渠道，或 `dotnet-install.ps1`）。
2. 拉取官方源码并切到 4.5.0：
   ```bash
   git clone --depth 1 --branch 4.5.0 https://github.com/QL-Win/QuickLook.git
   ```
3. 应用补丁：
   ```bash
   git apply patches/quicklook-4.5.0-macos-nav.patch
   ```
4. 编译：
   ```bash
   dotnet build QuickLook/QuickLook.csproj -c Release -p:Platform=AnyCPU "-p:PreBuildEvent="
   ```
   产物在 `Build/Release/QuickLook.exe`。

> 说明：官方构建依赖 `GitVersion.cs`（由 pre-build 脚本生成）和 VS 环境。仓库里已附上等价的 `GitVersion.cs` 与 `Directory.Build.props`（提供 net462 引用程序集、`LangVersion=preview`、资源序列化等设置），并用 `-p:PreBuildEvent=` 跳过官方 pre-build 脚本，因此在只有 .NET SDK 9 的机器上也能完整编译。

---

## 修改了什么（源码层面）

针对官方 `4.5.0` 源码，共 6 处变更（见 `patches/quicklook-4.5.0-macos-nav.patch`）：

| 文件 | 改动 |
|---|---|
| `QuickLook/KeystrokeDispatcher.cs` | ①方向键 KeyUp 时随 `Switch` 消息携带方向（`1`/`-1`）；②`_isPreviewRequest` 增加"鼠标悬停在预览窗口上方"判定；③新增鼠标悬停拦截逻辑——当鼠标在预览窗口上、前台是非文件管理器且非 QuickLook 自身时，方向键被 `e.Handled = true` 吞掉并立即发送切换，防止浏览器等前台应用也收到按键 |
| `QuickLook/PipeServerManager.cs` | `Switch` 管道消息解析方向参数并传给 `SwitchPreview(path, direction)` |
| `QuickLook/ViewWindowManager.cs` | `SwitchPreview` 新增 `direction` 参数；当从前台拿不到选中项（焦点/悬停在预览窗口）时，回退到 `GetAdjacentFile()`——按文件名排序在**当前文件所在目录**内取上一个/下一个文件 |
| `QuickLook/QuickLook.csproj` | `<LangVersion>preview</LangVersion>`（原版用到了 C# 12 preview 特性 `?.=`，官方 CI 环境能编译，纯 SDK 环境需要这个设置） |
| `GitVersion.cs`（新增） | 等价于官方 pre-build 生成的版本属性（`4.5.0.0`），供本地构建 |
| `Directory.Build.props`（新增） | 本地构建辅助：`Microsoft.NETFramework.ReferenceAssemblies`（无 VS 时编译 net462）、`System.Resources.Extensions`、`GenerateResourceUsePreserializedResources=true` |

### 核心逻辑（`ViewWindowManager.cs`）

```csharp
public void SwitchPreview(string path = null, int direction = 0)
{
    if (!_viewerWindow.IsVisible) return;

    // 1) 优先：前台是资源管理器/桌面 → 读取其当前选中项（原版行为）
    if (string.IsNullOrEmpty(path))
        path = NativeMethods.QuickLook.GetCurrentSelection();

    // 2) 回退：拿不到选中项（焦点/鼠标在预览窗口）→ 在当前目录里上/下一个
    if (string.IsNullOrEmpty(path) && direction != 0 && !string.IsNullOrEmpty(_invokedPath))
        path = GetAdjacentFile(_invokedPath, direction);

    if (string.IsNullOrEmpty(path)) return;

    InvokePreview(path);
}
```

### 鼠标悬停拦截（`KeystrokeDispatcher.cs`）

```csharp
// KeyDown 方向键时：
if (IsMouseOverOwnWindow() && !fgIsFileManager && !fgIsSelf)
{
    _arrowKeySuppressed = true;
    e.Handled = true;              // 吞掉按键 → 浏览器不滚动
    SendSwitchWithDirection(e.KeyCode); // 立即切换
    return;
}
```

`IsMouseOverOwnWindow()` = `GetCursorPos` + `WindowFromPoint` + 进程比对（鼠标下的窗口是否属于 QuickLook 进程）。

---

## 已知限制

- 切换范围包含目录内所有文件（含 .txt/.pdf 等），不只是图片。需要"只切图片"可以改 `GetAdjacentFile()` 的过滤条件。
- 如果某个应用窗口**完全盖住**预览窗口，鼠标实际悬停的是那个应用，方向键自然归它——"鼠标在哪归哪"的规则使然。
- 本补丁只动了主程序 `QuickLook.exe`，插件、原生 DLL 均未改动。
- 官方更新时请先 `-Restore` 还原再升级，升级后重新安装本补丁。

---

## 版本与许可

- 基于：官方 [QL-Win/QuickLook](https://github.com/QL-Win/QuickLook) tag `4.5.0`
- 许可：GPL-3.0（继承上游，见 `LICENSE`）
- 上游：https://github.com/QL-Win/QuickLook
