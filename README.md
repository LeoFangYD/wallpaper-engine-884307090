# wallpaper-engine-884307090

Wallpaper Engine 创意工坊壁纸 **884307090**（纯 Web 壁纸：樱花 + 时钟 + 系统声纹圆环）
在 Linux 上运行所需的全部内容：壁纸本体、引擎源码快照（含补丁）、可移植部署套件。

## 分支说明

| 分支 | 内容 | 用途 |
|---|---|---|
| `main` | 从 Windows 侧上传的原始壁纸工程 + 最初的裸归档 `linux-port/` | 存档、原始素材 |
| **`linux-ubuntu2204`** | 便携部署套件 `linux-deploy/`（零硬编码路径、一键安装、体检、卸载）+ 同一套壁纸与源码快照 | **换 Linux 机器部署就用这个分支** |

## 快速开始（Linux）

```bash
sudo apt-get install -y git-lfs   # 音视频素材走 LFS，漏装会没声音
git clone -b linux-ubuntu2204 https://github.com/LeoFangYD/wallpaper-engine-884307090.git
cd wallpaper-engine-884307090
./linux-deploy/install.sh --install-deps --build --autostart
~/.local/share/wallpaper-engine-linux/bin/doctor.sh
```

详细说明、配置项、故障排查见 **[`linux-deploy/README.md`](linux-deploy/README.md)**。

## 改了哪些东西（可审查）

| 位置 | 内容 |
|---|---|
| [`linux-deploy/patches/`](linux-deploy/patches/README.md) | 引擎源码的 7 个补丁（桌面层级、Web 黑屏、CEF zygote、CEF/GL 顺序、GCC 11 编译、音频桥）。**上游 `b016d7d` + 这些补丁 == 归档快照源码**（逐字节核验过） |
| [`linux-deploy/docs/THEME-CHANGES.md`](linux-deploy/docs/THEME-CHANGES.md) | 壁纸本体的定制清单：CSS/JS 改了哪几行、`project.json` 调了哪些参数 |
| [`linux-deploy/system/`](linux-deploy/system/README.md) | 桌面侧设置快照：GNOME 扩展、纯黑背景、DING 图标大小、字体校验、依赖版本、GPU/显示器 |
| [`linux-deploy/docs/MAINTENANCE.md`](linux-deploy/docs/MAINTENANCE.md) | 上游更新后如何迁移补丁、如何刷新设置快照、换机验收清单 |

## 已验证环境

Ubuntu 22.04.5 LTS · GNOME 42.9 · **X11** · NVIDIA GeForce RTX 4070 Ti（驱动 580，内核模块 580.178.04）·
gcc 11.4 · cmake 3.22.1 · 单屏 HDMI-0 2560x1440

## 仓库内容

```
884307090/     壁纸本体（HTML/JS/图片/音频/视频，音视频走 git-lfs）
linux-deploy/  可移植部署套件（推荐入口，见其 README）
linux-port/    最早的原始归档（脚本路径写死，仅作历史留存）+ 引擎源码快照
fonts/         字体说明与校验值（微软字体二进制不入库）
```

## 注意

- 运行时需要 **X11 会话**（GNOME on Xorg），纯 Wayland 不支持；
- 壁纸排版依赖 **DengXian Light / Microsoft YaHei Light**，字体需自行从 Windows 复制（见 `linux-deploy/system/fonts-README.md`）；
- 克隆前请安装 `git-lfs`，否则音视频素材是占位指针文件（`linux-deploy/scripts/doctor.sh` 会检测出来）。

## 许可与来源

本仓库是**个人自用的移植与备份**，包含两部分第三方内容，请注意各自的许可：

| 内容 | 来源 | 许可 |
|---|---|---|
| 引擎源码快照 `linux-port/linux-wallpaperengine-working-source.tar.xz` | [Almamu/linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine)（基线 `b016d7d`） | **GPL-3.0**，快照内保留原始 `LICENSE`；本地的 7 处改动以补丁形式公开在 [`linux-deploy/patches/`](linux-deploy/patches/README.md) |
| 壁纸本体 `884307090/` | Steam 创意工坊作品 [884307090](https://steamcommunity.com/sharedfiles/filedetails/?id=884307090)「Perfect Wallpaper-完美壁纸」，作者 **老陈（ZYM）** | 创意工坊内容，版权归原作者；此处仅为个人备份，请勿再分发或商用 |
| 微软字体（`DENGL.TTF` / `MSYHL.TTC` 等） | Windows 系统 | 有版权，**未入库**，仅记录校验值与安装方法 |

如果你要基于本仓库二次发布：引擎部分的改动请一并提供源码（GPL-3.0 要求），壁纸部分请回到创意工坊订阅原作者的作品。
