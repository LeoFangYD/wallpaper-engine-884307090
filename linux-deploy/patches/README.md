# 引擎补丁（linux-wallpaperengine 改动记录）

归档里的 `linux-port/linux-wallpaperengine-working-source.tar.xz` 是一个**改过的**上游源码快照，
但快照本身看不出"改了哪里、为什么改"。本目录就是那份改动的**可审查记录**。

## 已核验的事实

上游基线：`Almamu/linux-wallpaperengine` @ **`b016d7d`**
（`refactor: remove subprocess in favor of dbus and wire up to javascript (#606)`，与本快照检出同日）

```
上游 b016d7d  +  engine/ 下 7 个补丁  ==  归档快照里的源码
```

验证方式（见 `apply-engine-patches.sh --verify`）：把 7 个补丁打到干净的上游检出上，
再与归档快照逐文件比对——7 个文件全部**逐字节一致**，且整棵源码树（除内置子模块
`src/External` 与 `build/`）**没有任何其它差异**。

## 补丁清单

| 补丁 | 改动文件 | 修的问题 | 做法 |
|---|---|---|---|
| `0001-desktop-layering-glfw-floating` | `src/WallpaperEngine/Render/Drivers/GLFWOpenGLDriver.cpp` | 上游把显式窗口设成 `GLFW_FLOATING`（始终置顶），动态壁纸会**盖住桌面图标和所有窗口** | `GLFW_FLOATING` 由 `TRUE` 改成 `FALSE`（一行） |
| `0002-web-wallpaper-black-screen-texture` | `src/WallpaperEngine/WebBrowser/CEF/RenderHandler.cpp` | Web 壁纸**黑屏**：取到了错误的帧缓冲 | `getWallpaperFramebuffer()` → `getWallpaperTexture()` |
| `0003-cef-zygote-subprocess-argv` | `src/WallpaperEngine/WebBrowser/CEF/BrowserApp.cpp` | CEF 子进程（zygote/renderer）**崩溃或无法启动**：`OnBeforeChildProcessLaunch` 把原始 `argv` 全量透传，而 `argparse` 已改动/重排过这些缓冲区，传给子进程的命令行是坏的 | 只透传子进程真正需要的两项：`--assets-dir` 与背景路径 |
| `0004-cef-init-order-vs-opengl` | `src/WallpaperEngine/Application/WallpaperApplication.cpp` | CEF 与 OpenGL 的初始化顺序冲突：子进程必须先 `CefExecuteProcess`，主进程要在 GL 上下文就绪之后才初始化 CEF | 识别 `--type=` 子进程走早期 CEF 初始化；主进程把 `setupBrowser()` 挪到 `setupOutput()/setupAudio()` 之后 |
| `0005-gcc11-no-std-format` | `src/WallpaperEngine/Data/Builders/ColorBuilder.cpp` | Ubuntu 22.04 的 **GCC 11 / libstdc++ 没有 `<format>`**，直接编译失败 | 用 `std::ostringstream` + `<iomanip>` 重写；顺带修正 3/4 位 CSS 十六进制颜色扩展，补齐 `Log.h` 引用 |
| `0006-gcc11-missing-includes` | `src/WallpaperEngine/Media/MediaSource.h` | 同上的头文件缺失（新版 libstdc++ 隐式包含，GCC 11 不行） | 显式补 `<cstdint> <memory> <optional>` |
| `0007-web-wallpaper-audio-bridge` | `src/WallpaperEngine/Render/Wallpapers/CWeb.cpp` | Web 壁纸的 **声纹圈不动**：Wallpaper Engine 的 Web API 用 `wallpaperAudioListener()` 收 128 个频谱值，而 linux-wallpaperengine 只提供 PulseAudio 采到的 64 band FFT，两边接不上 | 每 2 帧把 64 band 复制成 128 值（模拟左右声道），通过 `ExecuteJavaScript` 注入到 `wallpaperAudioListener` / `window.__linuxWallpaperEngineAudioListener` |

## 怎么用

```bash
# 1) 已有上游检出：直接打补丁
git clone https://github.com/Almamu/linux-wallpaperengine.git
./linux-deploy/patches/apply-engine-patches.sh ~/linux-wallpaperengine

# 2) 没有检出：脚本自己 clone 到临时目录再打
./linux-deploy/patches/apply-engine-patches.sh --clone /tmp/wpe-upstream

# 3) 只做验证：打完后与归档快照逐文件比对
./linux-deploy/patches/apply-engine-patches.sh --verify
```

> **换机部署不需要跑这个脚本**：`linux-port/linux-wallpaperengine-working-source.tar.xz`
> 已经是打好补丁的源码，`install.sh` 直接解压使用。补丁的意义是**可审查、可迁移**——
> 比如上游更新后，把补丁 rebase 到新版本上，就不必再依赖这份冻结的快照。

## 上游更新后怎么办

见 `../docs/MAINTENANCE.md`。要点：先把补丁 `git apply -3`（三方合并）打到新版本，
冲突通常集中在 `0003`/`0004`（CEF 架构改动最频繁），`0001`/`0002`/`0005`/`0006` 一般能直接过。
