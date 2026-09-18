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
git clone -b linux-ubuntu2204 https://github.com/LeoFangYD/wallpaper-engine-884307090.git
cd wallpaper-engine-884307090
./linux-deploy/install.sh --install-deps --build --autostart
~/.local/share/wallpaper-engine-linux/bin/doctor.sh
```

详细说明、配置项、故障排查见 **[`linux-deploy/README.md`](linux-deploy/README.md)**。

## 已验证环境

Ubuntu 22.04.5 LTS · GNOME 42.9 · **X11** · NVIDIA GeForce RTX 4070 Ti (驱动 580.173.02) ·
gcc 11.4 · cmake 3.22.1 · 单屏 HDMI-0 2560x1440

## 仓库内容

```
884307090/     壁纸本体（HTML/JS/图片/音频/视频，音视频走 git-lfs）
linux-deploy/  可移植部署套件（推荐入口，见其 README）
linux-port/    最早的原始归档（脚本路径写死，仅作历史留存）
fonts/         字体说明与校验值（微软字体二进制不入库）
```

## 注意

- 运行时需要 **X11 会话**（GNOME on Xorg），纯 Wayland 不支持；
- 壁纸排版依赖 **DengXian Light / Microsoft YaHei Light**，字体需自行从 Windows 复制（见 `linux-deploy/system/fonts-README.md`）；
- 克隆前请安装 `git-lfs`，否则音视频素材是占位指针文件。
