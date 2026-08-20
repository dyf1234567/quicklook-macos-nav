# QuickLook 方向键导航改版

QuickLook（Windows 的空格预览工具）的一个小改版：让预览窗口自己响应用方向键切换图片，还支持"鼠标悬停接管方向键"。基于官方 v4.5.0 源码，只改了主程序。

## 为什么会有这个版本

原版 QuickLook 切图是"跟着资源管理器走"的：它每 500ms 看一眼前台文件管理器选中了哪个文件，选中变了预览就跟着变。这套逻辑有两个坑：

- 预览窗口会抢焦点。你点一下或者拖一下预览窗口，焦点就从资源管理器跑到预览窗口上，跟随机制立刻断掉，方向键怎么按都没反应。
- 焦点不在文件管理器就直接失灵。只要你在用浏览器、聊天软件之类的，前台不是文件管理器，切换整个就罢工。

说白了，原版是"你在资源管理器里选哪个我就看哪个"，预览窗口自己没有"上一张/下一张"的概念。这个改版把它做成 macOS Quick Look 那样：预览窗口自己切图，不依赖资源管理器；另外加了鼠标悬停接管，兼顾你平时在用其他软件的场景。

## 功能

**焦点在预览窗口上，方向键直接切图。** 打开图片预览 → 点一下预览窗口 → 按方向键就是上一个/下一个。切换是即时的，不经过 500ms 轮询。

**鼠标悬停在预览窗口上，方向键归预览管。** 比如你开着浏览器，鼠标移到预览窗口上按方向键，切的是图，而且按键会被吞掉，浏览器不会跟着滚。鼠标一移出预览窗口，方向键就还给浏览器，翻页、移动光标都不受影响。

**原来的用法不受影响。** 在资源管理器里用方向键移动选中、预览跟着变的旧逻辑还保留着。空格开关预览、Esc 关闭、F11 全屏这些快捷键也没动。

## 按键

- `←` / `↑`：上一个文件
- `→` / `↓`：下一个文件

切换范围是当前文件所在目录里的所有文件（按文件名排），不只是图片。想只切图片的话，改 `ViewWindowManager.cs` 里的 `GetAdjacentFile()`，加个扩展名过滤就行。

## 安装

最快的办法是直接替换 exe：

1. 退出 QuickLook（托盘图标右键退出，或任务管理器结束 `QuickLook.exe`）
2. 把原 `%LOCALAPPDATA%\Programs\QuickLook\QuickLook.exe` 备份一份
3. 用 `dist/QuickLook.exe` 覆盖它
4. 重新启动 QuickLook
5. 顺手改一下 `%APPDATA%\pooi.moe\QuickLook\QuickLook.config`：
   - `<Topmost>True</Topmost>` —— 预览窗口置顶，鼠标才够得着它
   - `<DisableAutoUpdateCheck>True</DisableAutoUpdateCheck>` —— 免得官方自动更新把补丁冲掉

也可以用仓库里的脚本，它会自己备份、替换、改配置，还能回滚：

```powershell
# 安装（自动备份原版、替换、设 Topmost、禁自动更新）
powershell -ExecutionPolicy Bypass -File scripts/install.ps1

# 只备份
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -BackupOnly

# 还原原版
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -Restore
```

## 自己编译

一键脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

它会装 .NET SDK 9（没有的话）→ 拉官方 4.5.0 源码 → 打补丁 → 编译 → 把 exe 放到 `dist/`。

手动来也行：

```bash
git clone --depth 1 --branch 4.5.0 https://github.com/QL-Win/QuickLook.git
cd QuickLook
git apply ../patches/quicklook-4.5.0-macos-nav.patch
dotnet build QuickLook/QuickLook.csproj -c Release -p:Platform=AnyCPU "-p:PreBuildEvent="
```

产物在 `Build/Release/QuickLook.exe`。

几个编译要点，省得你踩坑：

- 官方 pre-build 会调 `update-version.ps1` 生成 `GitVersion.cs`，还依赖 VS 环境。这里用 `-p:PreBuildEvent=` 跳过了它，仓库里放了等价的 `GitVersion.cs`。
- `Directory.Build.props` 提供了无 VS 环境下编译 net462 所需的引用程序集和资源序列化设置。
- `QuickLook.csproj` 的 LangVersion 改成了 `preview`——原版用到了 C# 12 的 preview 特性（`?.=`），纯 SDK 环境默认编不过。

## 改了哪些代码

补丁在 `patches/quicklook-4.5.0-macos-nav.patch`，共 6 处：

| 文件 | 改了什么 |
|---|---|
| `KeystrokeDispatcher.cs` | 方向键 KeyUp 带上方向发切换；`_isPreviewRequest` 加了"鼠标悬停预览窗口"判定；鼠标在预览窗口上且前台不是文件管理器时，方向键直接吞掉（`e.Handled = true`）并立即切换，避免前台应用也跟着收到按键 |
| `PipeServerManager.cs` | Switch 管道消息带上方向参数，传给 `SwitchPreview(path, direction)` |
| `ViewWindowManager.cs` | `SwitchPreview` 加 direction 参数；从前台拿不到选中项时，回退到 `GetAdjacentFile()`，按文件名排序取当前目录的上一个/下一个文件 |
| `QuickLook.csproj` | LangVersion latest → preview |
| `GitVersion.cs`（新增） | 等价于官方 pre-build 生成的版本属性，供本地构建 |
| `Directory.Build.props`（新增） | 无 VS 编译 net462 的辅助设置 |

切换逻辑的核心：

```csharp
public void SwitchPreview(string path = null, int direction = 0)
{
    if (!_viewerWindow.IsVisible) return;

    // 1) 前台是资源管理器/桌面 → 读它的选中项（原版行为）
    if (string.IsNullOrEmpty(path))
        path = NativeMethods.QuickLook.GetCurrentSelection();

    // 2) 拿不到选中项（焦点/鼠标在预览窗口）→ 在当前目录里上/下一个
    if (string.IsNullOrEmpty(path) && direction != 0 && !string.IsNullOrEmpty(_invokedPath))
        path = GetAdjacentFile(_invokedPath, direction);

    if (string.IsNullOrEmpty(path)) return;

    InvokePreview(path);
}
```

"鼠标悬停"的判定就是 `GetCursorPos` + `WindowFromPoint` + 进程比对，看鼠标底下那个窗口是不是 QuickLook 自己。

## 已知限制

- 切图范围是目录内所有文件，不只是图片。要只切图片得自己加过滤。
- 如果有窗口把预览窗口整个盖住了，鼠标实际悬停的是那个窗口，方向键归它——这是"鼠标在哪归哪"的规则，不是 bug。
- 只改了主程序 `QuickLook.exe`，插件和原生 DLL 都没动。
- 官方升级前先 `-Restore` 还原，升完再装回来。

## License

GPL-3.0，跟上游一致。上游项目：[QL-Win/QuickLook](https://github.com/QL-Win/QuickLook)
