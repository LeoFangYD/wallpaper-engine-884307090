# 故障排查

排查三件套：

```bash
BIN=~/.local/share/wallpaper-engine-linux/bin
$BIN/doctor.sh            # 环境体检：会话/依赖/引擎/壁纸/字体
$BIN/status-wallpaper.sh  # 运行状态 + 日志尾部
tail -f ~/.local/share/wallpaper-engine-linux/log/engine.log
```

---

## 1. 黑屏 / 只显示纯黑背景

**现象**：桌面全黑，桌面图标正常，没有樱花和时钟。

| 原因 | 检查 | 解决 |
|---|---|---|
| 引擎退出 | `status-wallpaper.sh` 显示“未运行” | 看 `engine.log` 末尾报错，按对应条目处理 |
| 背景色是黑的（正常） | 壁纸模式下 GNOME 背景本就设成纯黑，动态壁纸在它上方 | 不是故障；确认引擎进程在跑即可 |
| 窗口没被压到桌面层 | `wmctrl -l` 能看到壁纸窗口但盖住了图标 | 见第 3 节 |
| CEF/OpenGL 初始化失败 | 日志里有 `libcef.so` / `GL_` / `zygote` 报错 | 确认配置里 `WPE_GL_THREADED_OPTIMIZATIONS="0"`，且 `LD_PRELOAD` 指向同目录 `libcef.so`（脚本已处理） |

## 2. 日志里提示 CEF 相关崩溃、进程反复重启

- 确认没有手动 `export LD_PRELOAD` 之类污染环境（脚本自己设置，不要外部覆盖）。
- 确认 NVIDIA 驱动与内核匹配：`nvidia-smi` 能正常输出。驱动刚升级过需要重启。
- 崩溃循环保护触发后（日志出现 `检测到崩溃循环`），修好问题再执行 `start-wallpaper.sh` 即可继续（它会清掉停用标记）。

## 3. 动态壁纸盖住了桌面图标 / 抢焦点

这是本套件专门修的问题，处理链路是：

1. `xprop -set _NET_WM_WINDOW_TYPE_DESKTOP` —— 声明成桌面窗口；
2. `wmctrl -b add,below,sticky,skip_taskbar,skip_pager` —— 不参与窗口切换；
3. `python3` 调 `XLowerWindow` 反复下压 —— GNOME 映射窗口期间会重排，压一次不够。

排查：

```bash
wmctrl -lG                       # 找到壁纸窗口，看它是否 below/desktop
xprop -id <WID> | grep -E "WINDOW_TYPE|STATE"
```

如果手工执行 `start-wallpaper.sh` 正常、但开机自启后盖住图标，通常是自启动太早。解决：

- 使用安装时生成的 autostart（含 `X-GNOME-Autostart-Delay=6`）；
- 或把 `~/.config/autostart/linux-wallpaperengine.desktop` 里的延迟调大到 10。

## 4. 纯 Wayland 会话下完全不工作

本套件的置底方案依赖 X11（`_NET_WM_WINDOW_TYPE_DESKTOP` + `XLowerWindow`），Wayland 下没有等价能力。

**解决**：在 GDM 登录界面点右下角齿轮，选 **GNOME on Xorg** 登录，然后确认：

```bash
echo $XDG_SESSION_TYPE   # 应该是 x11
```

## 5. 时间 / 日期 / 字号排版错位

字体缺失导致浏览器回退到别的字体。检查：

```bash
fc-match "DengXian Light"
fc-match "Microsoft YaHei Light"
```

输出里应分别出现 `DengXian/等线` 和 `YaHei/雅黑`。安装方法见 `system/fonts-README.md`。

## 6. 没有声纹 / 圆环不动

壁纸通过 PulseAudio 抓系统音频做可视化。

```bash
pactl info                       # 能输出说明 PulseAudio/PipeWire-pulse 正常
pactl list short sink-inputs     # 播放音乐时应有输入流
```

- 静音时显示白色圆环是**预期行为**（源码里的静音处理）。
- 完全不需要音频可视化时，在配置里加 `WPE_EXTRA_ARGS="--no-audio-processing"` 可以省一点 CPU。

## 7. 换了分辨率 / 插拔显示器后壁纸尺寸不对

壁纸的几何信息在启动时确定，不会自动跟随。处理：

```bash
stop-wallpaper.sh && start-wallpaper.sh
```

多显示器想固定在某块屏幕上，编辑 `~/.config/wallpaper-engine-linux/wallpaper.conf`：

```bash
WPE_MONITOR="HDMI-0"        # xrandr 里的输出名，用 xrandr 查看
# 或者直接写死几何 XxYxWxH
# WPE_GEOMETRY="0x0x2560x1440"
```

## 8. 编译问题

| 现象 | 解决 |
|---|---|
| `cmake configure 失败` | 先看 `$ROOT/build/build.log`；缺依赖就 `install.sh --install-deps` |
| CEF 下载失败（`DownloadCEF`） | 需要联网访问 `cef-builds.spotifycdn.com`；国内网络请先配代理再重试，或把别的机器上 `build/cef/*.tar.bz2` 拷到同一路径复用 |
| 编译中磁盘满 | 首次编译约需 10GB 空闲；清理 `$ROOT/build` 重来 |
| 想跳过编译 | 在别的机器编译好，然后 `install.sh --reuse-build /path/to/build` |

## 9. GPU 占用高 / 风扇响 / 笔记本耗电

在 `~/.config/wallpaper-engine-linux/wallpaper.conf` 调整：

```bash
WPE_FPS="30"                          # 降到 30 帧
WPE_EXTRA_ARGS="--no-audio-processing" # 关掉音频可视化
```

改完 `stop-wallpaper.sh && start-wallpaper.sh` 生效。
