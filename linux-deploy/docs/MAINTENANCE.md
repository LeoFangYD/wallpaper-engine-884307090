# 维护手册

这份备份要长期可用，关键是三件事：**引擎能跟着上游走**、**设置快照能刷新**、**换机能验证**。

---

## 1. 引擎跟着上游更新

归档快照 `linux-port/linux-wallpaperengine-working-source.tar.xz` 是冻结的，好处是稳，
坏处是上游修 bug 你吃不到。想要新版本就用补丁迁移：

```bash
# 拿到新版本源码
git clone https://github.com/Almamu/linux-wallpaperengine.git /tmp/wpe-new

# 打补丁（能直接过就直接过，过不去走三方合并）
./linux-deploy/patches/apply-engine-patches.sh /tmp/wpe-new

# 确认补丁与旧快照等价（确认没有漏改）
./linux-deploy/patches/apply-engine-patches.sh --verify /tmp/wpe-new
```

然后让部署使用新源码：

```bash
# 方式 A：配置里把源码目录指过去，再编译
echo 'WPE_SRC_DIR="/tmp/wpe-new"' >> ~/.config/wallpaper-engine-linux/wallpaper.conf
~/.local/share/wallpaper-engine-linux/bin/build-engine.sh

# 方式 B：编译好之后把产物复用过来
./linux-deploy/install.sh --reuse-build /tmp/wpe-new/build
```

**冲突高发区**：`0003`（CEF 子进程/zygote）与 `0004`（CEF 初始化顺序）——上游这两块改动最频繁
（例如 `b016d7d` 就是 CEF 子进程架构的重构）。`0001`/`0002`/`0005`/`0006` 通常能一直干净应用。

补一个新的适配时：改代码 → 保留原文件为 `xxx.bak-before-<原因>` → 用
`patches/apply-engine-patches.sh` 的生成方式（`diff -u --label a/... --label b/...`）产出补丁 →
补进 `patches/engine/` → 更新 `patches/README.md` 的表格。

## 2. 刷新机器设置快照

`linux-deploy/system/` 是**本机**桌面侧设置的备份。换了显示器、调了 GNOME 设置、装了新依赖之后，
重新采集一次即可：

```bash
./linux-deploy/system/collect.sh

cd <仓库>
git add linux-deploy/system
git commit -m "Refresh desktop settings snapshot"
git push
```

`collect.sh` 会刷新：`system.txt`（系统/会话/GPU/显示器/字体）、
`gnome-desktop-settings.txt`（GNOME 扩展与 dconf 关键项）、`packages.txt`（依赖版本）、
`fonts.sha256`（已安装字体校验值）。

## 3. 换机后的验收清单

```bash
BIN=~/.local/share/wallpaper-engine-linux/bin
$BIN/doctor.sh            # 环境体检：会话/依赖/引擎/壁纸/LFS/字体/自启动
$BIN/start-wallpaper.sh   # 启动
$BIN/status-wallpaper.sh  # 状态与日志尾部
```

四项必查：

| 检查 | 期望 |
|---|---|
| `echo $XDG_SESSION_TYPE` | `x11`（Wayland 不支持置底） |
| `git lfs ls-files \| wc -l` 与 `pw` 里的素材 | 非 LFS 指针文件——否则音频/视频失效（见下） |
| `fc-match "DengXian Light"` | 输出含 `DengXian`/`等线` |
| 壁纸窗口 `xprop` | `_NET_WM_WINDOW_TYPE_DESKTOP` + `_NET_WM_STATE_BELOW` |

**忘记装 git-lfs 的症状**：`884307090/audio/*.ogg`、`video/*.webm` 变成 130 字节的文本指针，
壁纸能显示但没声音、声纹圈不动。修复：

```bash
sudo apt-get install -y git-lfs && git lfs install && git lfs pull
```

## 4. 分支怎么用

| 分支 | 定位 |
|---|---|
| `main` | 原始存档（Windows 侧上传的壁纸工程 + 最早的 `linux-port/`） |
| `linux-ubuntu2204` | **日常使用/部署分支**：便携部署套件 + 同一套壁纸与源码快照 |

建议：本机（当前 Ubuntu）就 clone 这个分支长期使用，改配置、刷新快照都提交到它上面；
`main` 只在需要回看原始工程时用。

## 5. 本机（当前这台）的现状

- 旧布局 `~/linux-wallpaperengine` 仍在服役，脚本路径写死；
- 想迁到新的便携布局、又不重新编译：

```bash
cd <仓库>
./linux-deploy/install.sh --reuse-build ~/linux-wallpaperengine/build --autostart
```

迁完之后 `~/.config/autostart/linux-wallpaperengine.desktop` 会指向
`~/.local/share/wallpaper-engine-linux/bin/wallpaper-watchdog.sh`（原文件自动留 `.bak-<时间戳>`），
旧目录留着不影响，确认新布局跑稳后再删。
