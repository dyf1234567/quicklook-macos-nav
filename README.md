# QuickLook 方向键导航

QuickLook（Windows 空格预览工具）的小改版：预览窗口能自己用方向键切图，不用再依赖资源管理器。基于官方 v4.5.0，只改了主程序。

## 能干嘛

- 焦点在预览窗口上，直接按方向键切图，`←`/`↑` 上一个，`→`/`↓` 下一个
- 鼠标移到预览窗口上，方向键也归它管，而且浏览器不会跟着滚
- 鼠标移开后，方向键还给浏览器正常用
- 原来在资源管理器里按方向键选文件、预览跟着变的用法不受影响

切的是当前文件夹里的图片（jpg/png/gif/webp/raw 等常见格式都算），非图片文件会跳过。

## 安装

最快：退出 QuickLook，用 `dist/QuickLook.exe` 覆盖 `%LOCALAPPDATA%\Programs\QuickLook\QuickLook.exe`，重启。

或者用脚本（自动备份、替换、改配置）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

还原原版：`scripts/install.ps1 -Restore`。

## 自己编译

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

它会装 SDK、拉官方 4.5.0 源码、打补丁、编译，产物放到 `dist/`。

## 改了啥

方向键按下时，QuickLook 不再傻等资源管理器的选中变化，而是直接在当前文件夹里找上一张/下一张图片切换。鼠标悬停时把方向键吞掉，不让后台的浏览器之类的也收到。

改动就 3 个主程序文件（`KeystrokeDispatcher.cs`、`PipeServerManager.cs`、`ViewWindowManager.cs`），具体补丁在 `patches/`，想自己研究的看 diff 就行。

## 注意

- 如果别的窗口把预览窗口整个盖住了，鼠标不在预览窗口上，方向键自然归那个窗口
- 只改了主程序，插件和原生 DLL 没动
- 官方升级前先用 `-Restore` 还原，升完再装回来

License：GPL-3.0，跟上游一致。上游：[QL-Win/QuickLook](https://github.com/QL-Win/QuickLook)
