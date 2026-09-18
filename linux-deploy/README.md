# Wallpaper Engine 动态壁纸 · Ubuntu/GNOME/X11 可移植部署套件

把当前这台 Linux 机器上「能跑的动态壁纸 + 全部配套设置」打包成**换台机器也能一键部署**的形式。

- 壁纸：Wallpaper Engine 创意工坊 **884307090**（纯 Web 壁纸：樱花 + 时钟 + 声纹圆环）
- 引擎：`linux-wallpaperengine`（已在源码快照里带齐所有补丁与内置子模块）
- 目标环境：**Ubuntu 22.04+ / GNOME / X11**（NVIDIA 显卡验证通过，AMD/Intel 亦可）

> 旧版 `linux-port/` 目录保留的是**原始归档**（脚本里写死了 `/home/qy/...`，换机不能用）。
> 本目录 `linux-deploy/` 才是**可直接部署**的版本：零硬编码路径 + 一键安装 + 体检 + 卸载。

---

## 一键部署（新机器）

```bash
git clone -b linux-ubuntu2204 https://github.com/LeoFangYD/wallpaper-engine-884307090.git
cd wallpaper-engine-884307090

# 推荐：装依赖 + 部署 + 编译 + 配置登录自启
./linux-deploy/install.sh --install-deps --build --autostart

# 没有 sudo / 依赖已装好：只部署，之后再编译
./linux-deploy/install.sh
./linux-deploy/build/build-engine.sh
```

编译完成后：

```bash
~/.local/share/wallpaper-engine-linux/bin/doctor.sh            # 体检
~/.local/share/wallpaper-engine-linux/bin/start-wallpaper.sh   # 立即启动
```

想省掉“每台机器都下载 CEF 再编译”的麻烦，可以在已编译的机器上复用产物：

```bash
./linux-deploy/install.sh --reuse-build ~/linux-wallpaperengine/build --autostart
```

---

## 部署后长什么样

```
~/.local/share/wallpaper-engine-linux/     ← 安装根目录（$WPE_ROOT）
├── src/               linux-wallpaperengine 源码快照（含补丁 + 内置子模块）
├── build/             编译产物，可执行文件在 build/output/linux-wallpaperengine
├── build/output/      运行时需要的 libcef.so / locales / 资源，全部在此
├── empty-assets/      空 assets 目录（纯 Web 壁纸不需要 Steam assets）
├── wallpapers/
│   └── 884307090/     ← 默认软链到仓库里的 884307090/（--copy-wallpaper 则复制）
├── bin/               start / stop / status / doctor / watchdog + common.sh
└── log/               engine.log、watchdog.log（超 5MB 自动轮转）

~/.config/wallpaper-engine-linux/wallpaper.conf      ← 机器自适应配置
~/.config/autostart/linux-wallpaperengine.desktop    ← GNOME 登录自启（可选）
```

## 常用命令

| 操作 | 命令 |
|---|---|
| 启动 | `<ROOT>/bin/start-wallpaper.sh` |
| 停止（watchdog 不再拉起） | `<ROOT>/bin/stop-wallpaper.sh` |
| 连 watchdog 一起停 | `<ROOT>/bin/stop-wallpaper.sh --watchdog` |
| 看状态与日志尾部 | `<ROOT>/bin/status-wallpaper.sh` |
| 环境体检 | `<ROOT>/bin/doctor.sh` |
| 编译引擎 | `linux-deploy/build/build-engine.sh [--clean] [--jobs N]` |
| 卸载 | `linux-deploy/uninstall.sh` |

> `<ROOT>` 默认是 `~/.local/share/wallpaper-engine-linux`。

## 配置：一个文件管全部

`~/.config/wallpaper-engine-linux/wallpaper.conf`（安装时自动生成，带中文注释）。
优先级：**该文件 > 环境变量 > 脚本内置默认值**。

```bash
WPE_FPS="60"                      # 30 可省电
WPE_MONITOR="primary"             # 或 "HDMI-0"，或 "0x0x2560x1440"
WPE_EXTRA_ARGS=""                 # 例如 "--no-audio-processing"
WPE_MAX_RESTARTS="5"              # 崩溃循环保护阈值
```

改完 `stop-wallpaper.sh && start-wallpaper.sh` 生效。所有路径都按安装时的真实位置写好，**换机器不用手改脚本**。

---

## install.sh 参数

| 参数 | 作用 |
|---|---|
| `--build` | 部署后立即编译（首次联网下载 CEF，约 10GB 磁盘） |
| `--autostart` | 安装 GNOME 登录自启（推荐） |
| `--systemd` | 安装 systemd 用户服务（不自动 enable；X11 环境下不如 GNOME 自启稳） |
| `--reuse-build DIR` | 复用已有 `build` 目录，跳过编译 |
| `--copy-wallpaper` | 复制壁纸而非软链（仓库移走后仍可用，多占约 640MB） |
| `--install-deps` | `sudo apt-get` 安装依赖清单 |
| `--root DIR` | 自定义安装根目录（默认 `~/.local/share/wallpaper-engine-linux`） |
| `--force` | 覆盖已存在的源码 / 配置 / 自启动文件 |
| `-h` | 帮助 |

## 换机前需要手动的两件事

1. **字体**（微软雅黑/等线，授权原因不在仓库里）—— 见 `system/fonts-README.md`；
2. **桌面环境**：登录时选 **GNOME on Xorg**（Wayland 下置底方案不生效）。

其余（源码、补丁、脚本、自启、配置、日志目录）都由 `install.sh` 自动完成。

## 文档

- `docs/TROUBLESHOOTING.md` —— 黑屏、盖住桌面图标、音频、字体、编译、省电等问题的排查
- `system/README.md` —— 桌面侧配套设置（DING 桌面图标扩展、纯黑背景、图标大小）
- `../linux-port/README.md` —— 原始归档说明（历史版本）

## 已知限制

- **仅 X11**：置底依赖 `_NET_WM_WINDOW_TYPE_DESKTOP` + `XLowerWindow`，Wayland 无等价能力；
- **分辨率变化后需重启壁纸**：几何信息在启动时确定，不自动跟随；
- **CEF 首次编译需联网**（`cef-builds.spotifycdn.com`），约 150MB；
- 源码快照体积较大（18MB 压缩），壁纸素材通过 git-lfs 管理（克隆前请装 `git-lfs`）。
