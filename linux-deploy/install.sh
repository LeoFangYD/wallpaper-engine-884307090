#!/usr/bin/env bash
# ==============================================================================
# install.sh — 一键把「动态壁纸 + 这套配套设置」部署到一台新的 Ubuntu/GNOME/X11 机器
#
# 它做什么：
#   1. 检查系统、会话与依赖，缺什么直接告诉你要装什么；
#   2. 在 ~/.local/share/wallpaper-engine-linux 下建立标准目录；
#   3. 校验并解压归档的 linux-wallpaperengine 源码快照（子模块已内置）；
#   4. 把仓库里的壁纸 884307090 链接/复制成部署目录下的壁纸；
#   5. 写入机器自适应配置 ~/.config/wallpaper-engine-linux/wallpaper.conf；
#   6. 把启停脚本安装到 <ROOT>/bin（路径全部自动替换，无硬编码）；
#   7. 可选：编译引擎、安装 GNOME 自启动 / systemd 用户服务。
#
# 用法:
#   ./install.sh                       # 只做部署（不编译、不开机自启）
#   ./install.sh --build               # 部署并编译引擎（首次需要联网下载 CEF）
#   ./install.sh --build --autostart   # 全自动：编译 + 登录自启（推荐新机器用这条）
#   ./install.sh --reuse-build ~/linux-wallpaperengine/build   # 复用已有编译产物
#   ./install.sh --copy-wallpaper      # 复制壁纸而不是软链（仓库移走后仍可用）
#   ./install.sh --install-deps        # 用 sudo apt 安装缺失依赖
#   ./install.sh --force               # 覆盖已有的源码/配置
#   -h | --help
# ==============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$HERE/.." && pwd -P)"

WPE_ROOT="${WPE_ROOT:-$HOME/.local/share/wallpaper-engine-linux}"
SRC_ARCHIVE="$REPO_ROOT/linux-port/linux-wallpaperengine-working-source.tar.xz"
WALLPAPER_SRC="$REPO_ROOT/884307090"
AUTOSTART_DESKTOP="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/linux-wallpaperengine.desktop"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wallpaper-engine-linux"
CONFIG_FILE="$CONFIG_DIR/wallpaper.conf"

DO_BUILD=0
DO_AUTOSTART=0
DO_SYSTEMD=0
DO_DEPS=0
FORCE=0
COPY_WALLPAPER=0
REUSE_BUILD=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)           WPE_ROOT="${2:?--root 需要参数}"; shift 2 ;;
        --src-archive)    SRC_ARCHIVE="${2:?--src-archive 需要参数}"; shift 2 ;;
        --wallpaper)      WALLPAPER_SRC="${2:?--wallpaper 需要参数}"; shift 2 ;;
        --reuse-build)    REUSE_BUILD="${2:?--reuse-build 需要参数}"; shift 2 ;;
        --build)          DO_BUILD=1; shift ;;
        --autostart)      DO_AUTOSTART=1; shift ;;
        --systemd)        DO_SYSTEMD=1; shift ;;
        --install-deps)   DO_DEPS=1; shift ;;
        --copy-wallpaper) COPY_WALLPAPER=1; shift ;;
        --force)          FORCE=1; shift ;;
        -h|--help)        sed -n '2,28p' "$0"; exit 0 ;;
        *) echo "未知参数: $1（-h 查看用法）" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m== [%s] %s\033[0m\n' "$1" "$2"; }
ok()   { printf '   ✓ %s\n' "$*"; }
info() { printf '   · %s\n' "$*"; }
warn() { printf '   ! %s\n' "$*"; }
die()  { printf '\n   ✗ %s\n' "$*" >&2; exit 1; }

echo "============================================================"
echo " Wallpaper Engine (884307090) Ubuntu/GNOME/X11 部署脚本"
echo "============================================================"
info "仓库根目录   : $REPO_ROOT"
info "安装根目录   : $WPE_ROOT"
info "源码归档     : $SRC_ARCHIVE"
info "壁纸来源     : $WALLPAPER_SRC"

# ---------------------------------------------------------------- 依赖检查
step 1/9 "检查运行环境与依赖"
[ "$(uname -s)" = "Linux" ] || die "本脚本只支持 Linux（当前: $(uname -s)）"

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    info "系统: ${PRETTY_NAME:-unknown}"
    case "${ID:-}${ID_LIKE:-}" in
        *debian*|*ubuntu*) DEP_FILE="$HERE/deps/ubuntu-22.04.txt"
            case "${VERSION_ID:-}" in 24.*|25.*) DEP_FILE="$HERE/deps/ubuntu-24.04.txt" ;; esac ;;
        *) DEP_FILE="$HERE/deps/ubuntu-22.04.txt"
           warn "非 Debian/Ubuntu 系发行版，依赖清单仅供参考: $DEP_FILE" ;;
    esac
fi

SESSION_TYPE="${XDG_SESSION_TYPE:-未知}"
if [ "$SESSION_TYPE" = "x11" ]; then
    ok "会话类型 X11（本套件的置底方案依赖 X11）"
elif [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    warn "当前是 Wayland 会话：可以部署和编译，但运行时请改用 'GNOME on Xorg' 登录"
else
    warn "未检测到图形会话（脚本可能在 ssh/root 下运行）——部署不受影响，运行前请在桌面会话里操作"
fi

MISSING_CMDS=()
for c in bash tar xz sha256sum; do
    command -v "$c" >/dev/null 2>&1 || MISSING_CMDS+=("$c")
done
[ ${#MISSING_CMDS[@]} -eq 0 ] && ok "基础工具齐全 (bash/tar/xz/sha256sum)" \
    || warn "缺少基础工具: ${MISSING_CMDS[*]}"

RUNTIME_MISSING=()
for c in xrandr xprop wmctrl python3; do
    command -v "$c" >/dev/null 2>&1 || RUNTIME_MISSING+=("$c")
done
[ ${#RUNTIME_MISSING[@]} -eq 0 ] && ok "运行依赖齐全 (xrandr/xprop/wmctrl/python3)" \
    || warn "运行依赖缺失: ${RUNTIME_MISSING[*]}"

BUILD_MISSING=()
for c in cmake g++ make; do
    command -v "$c" >/dev/null 2>&1 || BUILD_MISSING+=("$c")
done
[ ${#BUILD_MISSING[@]} -eq 0 ] && ok "编译依赖齐全 (cmake/g++/make)" \
    || warn "编译依赖缺失: ${BUILD_MISSING[*]}（不编译可以忽略）"

if [ "$DO_DEPS" = "1" ]; then
    step "1b" "安装依赖（sudo apt-get）"
    # shellcheck disable=SC2046
    sudo apt-get update && sudo apt-get install -y $(grep -v '^#' "${DEP_FILE:-$HERE/deps/ubuntu-22.04.txt}" | tr '\n' ' ') \
        || die "依赖安装失败"
    ok "依赖安装完成"
else
    info "缺依赖可执行: sudo apt-get install -y \$(grep -v '^#' ${DEP_FILE:-$HERE/deps/ubuntu-22.04.txt} | tr '\\n' ' ')"
    info "或直接重跑本脚本加 --install-deps"
fi

# ---------------------------------------------------------------- 目录
step 2/9 "建立部署目录"
mkdir -p "$WPE_ROOT"/{src,build,wallpapers,empty-assets,log,bin} || die "无法创建 $WPE_ROOT"
ok "$WPE_ROOT/{src,build,wallpapers,empty-assets,log,bin}"

# ---------------------------------------------------------------- 源码
step 3/9 "校验并解压引擎源码快照"
[ -f "$SRC_ARCHIVE" ] || die "找不到源码归档: $SRC_ARCHIVE
可从仓库 linux-port/ 目录获取，或指定 --src-archive <文件>"
if [ -f "$SRC_ARCHIVE.sha256" ]; then
    EXPECT="$(awk '{print $1; exit}' "$SRC_ARCHIVE.sha256")"
    ACTUAL="$(sha256sum "$SRC_ARCHIVE" | awk '{print $1}')"
    if [ -n "$EXPECT" ] && [ "$EXPECT" = "$ACTUAL" ]; then
        ok "SHA256 校验通过 ($ACTUAL)"
    else
        die "SHA256 校验失败：归档文件可能损坏，请重新从 GitHub 拉取
     期望: $EXPECT
     实际: $ACTUAL"
    fi
fi

if [ -f "$WPE_ROOT/src/CMakeLists.txt" ] && [ "$FORCE" != "1" ]; then
    ok "源码已存在，跳过解压（--force 可强制重解压）"
else
    [ "$FORCE" = "1" ] && rm -rf "$WPE_ROOT/src"
    mkdir -p "$WPE_ROOT/src"
    tar -xJf "$SRC_ARCHIVE" -C "$WPE_ROOT/src" || die "解压失败"
    [ -f "$WPE_ROOT/src/CMakeLists.txt" ] || die "解压后没有 CMakeLists.txt，归档结构异常"
    ok "源码已解压到 $WPE_ROOT/src ($(find "$WPE_ROOT/src" -type f | wc -l) 个文件)"
fi

# ---------------------------------------------------------------- 壁纸
step 4/9 "部署壁纸资源"
[ -f "$WALLPAPER_SRC/project.json" ] || die "壁纸目录无效（缺 project.json）: $WALLPAPER_SRC"
DEST_WALLPAPER="$WPE_ROOT/wallpapers/$(basename "$WALLPAPER_SRC")"
rm -rf "$DEST_WALLPAPER"
if [ "$COPY_WALLPAPER" = "1" ]; then
    cp -a "$WALLPAPER_SRC" "$DEST_WALLPAPER" || die "复制壁纸失败"
    ok "已复制壁纸到 $DEST_WALLPAPER（$(du -sh "$DEST_WALLPAPER" | cut -f1)）"
else
    ln -sfn "$(cd "$WALLPAPER_SRC" && pwd -P)" "$DEST_WALLPAPER" || die "创建壁纸软链失败"
    ok "已软链壁纸: $DEST_WALLPAPER -> $(readlink "$DEST_WALLPAPER")"
    info "（仓库被移动/删除后软链会失效；想彻底独立请用 --copy-wallpaper，代价是约 640MB 额外磁盘）"
fi

# ---------------------------------------------------------------- 脚本
step 5/9 "安装启停脚本"
cp -a "$HERE/lib/." "$WPE_ROOT/bin/" || die "复制 lib 失败"
cp -a "$HERE/scripts/." "$WPE_ROOT/bin/" || die "复制 scripts 失败"
# 编译脚本也装进 bin：这样安装后即使仓库被删，也能在 <ROOT>/bin 里重新编译
cp -a "$HERE/build/build-engine.sh" "$WPE_ROOT/bin/" || die "复制 build-engine.sh 失败"
chmod +x "$WPE_ROOT/bin"/*.sh
ok "脚本已安装: $(ls "$WPE_ROOT/bin" | tr '\n' ' ')"

# ---------------------------------------------------------------- 编译产物
step 6/9 "准备编译产物"
if [ -n "$REUSE_BUILD" ]; then
    REUSE_BUILD="$(cd "$REUSE_BUILD" 2>/dev/null && pwd -P)" || die "复用目录不存在: $REUSE_BUILD"
    [ -x "$REUSE_BUILD/output/linux-wallpaperengine" ] || die "复用目录里没有 output/linux-wallpaperengine: $REUSE_BUILD"
    rm -rf "$WPE_ROOT/build"
    ln -sfn "$REUSE_BUILD" "$WPE_ROOT/build"
    ok "已复用已有编译产物: $WPE_ROOT/build -> $REUSE_BUILD"
elif [ -x "$WPE_ROOT/build/output/linux-wallpaperengine" ]; then
    ok "检测到已有编译产物: $WPE_ROOT/build/output/linux-wallpaperengine"
else
    warn "还没有编译产物（$WPE_ROOT/build/output/linux-wallpaperengine 不存在）"
    info "接下来需要二选一："
    info "  1) 编译: $WPE_ROOT/bin/build-engine.sh   （首次会联网下载 CEF，约需 10GB 磁盘、10~30 分钟）"
    info "  2) 复用: 重跑本脚本并加 --reuse-build <已有 build 目录的绝对路径>"
fi

# ---------------------------------------------------------------- 配置
step 7/9 "生成机器自适应配置"
mkdir -p "$CONFIG_DIR"
WALLPAPER_CONF_VALUE="$DEST_WALLPAPER"
if [ -f "$CONFIG_FILE" ] && [ "$FORCE" != "1" ]; then
    ok "配置已存在，保留不动: $CONFIG_FILE（--force 可重新生成）"
else
    sed -e "s|@WPE_ROOT@|$WPE_ROOT|g" \
        -e "s|@WPE_WALLPAPER@|$WALLPAPER_CONF_VALUE|g" \
        "$HERE/config/wallpaper.conf.example" >"$CONFIG_FILE" || die "写入配置失败"
    ok "已生成 $CONFIG_FILE"
    info "所有路径都指向本机实际位置，无需手改；改之后 start/stop/watchdog 立即生效"
fi

# ---------------------------------------------------------------- 自启动
step 8/9 "开机自启动"
if [ "$DO_AUTOSTART" = "1" ]; then
    mkdir -p "$(dirname "$AUTOSTART_DESKTOP")"
    if [ -f "$AUTOSTART_DESKTOP" ] && [ "$FORCE" != "1" ]; then
        cp -a "$AUTOSTART_DESKTOP" "$AUTOSTART_DESKTOP.bak-$(date +%Y%m%d%H%M%S)"
        info "已备份原自启动文件"
    fi
    sed -e "s|@WPE_BIN_DIR@|$WPE_ROOT/bin|g" \
        "$HERE/autostart/linux-wallpaperengine.desktop.in" >"$AUTOSTART_DESKTOP" || die "写入自启动文件失败"
    chmod +x "$AUTOSTART_DESKTOP"
    ok "已安装 GNOME 自启动: $AUTOSTART_DESKTOP"
else
    info "未安装自启动（加 --autostart 即可；GNOME/X11 下推荐用这个方式）"
fi

if [ "$DO_SYSTEMD" = "1" ]; then
    UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$UNIT_DIR"
    sed -e "s|%h/.local/share/wallpaper-engine-linux/bin|$WPE_ROOT/bin|g" \
        -e "s|Environment=DISPLAY=:0|Environment=DISPLAY=${DISPLAY:-:0}|g" \
        "$HERE/systemd/wallpaper-engine.service" >"$UNIT_DIR/wallpaper-engine.service" || die "写入 systemd 服务失败"
    systemctl --user daemon-reload 2>/dev/null || true
    ok "已安装 systemd 用户服务（未 enable，避免与 GNOME 自启动重复）"
    info "如需启用: systemctl --user enable --now wallpaper-engine.service"
    warn "systemd + X11 的 DISPLAY/XAUTHORITY 环境在部分发行版上不稳，优先用 GNOME 自启动"
fi

# ---------------------------------------------------------------- 可选项：编译
if [ "$DO_BUILD" = "1" ]; then
    step "8b" "编译引擎"
    "$HERE/build/build-engine.sh" || die "编译失败"
fi

# ---------------------------------------------------------------- 体检
step 9/9 "部署结果自检"
"$WPE_ROOT/bin/doctor.sh" || warn "体检有未通过项，请按上面提示处理"

FONT_OK=1
for f in "DengXian Light" "Microsoft YaHei Light"; do
    m="$(fc-match "$f" 2>/dev/null || echo '')"
    case "$m" in *DengXian*|*等线*|*YaHei*|*雅黑*) ;; *) FONT_OK=0 ;; esac
done
if [ "$FONT_OK" != "1" ]; then
    warn "缺少 DengXian Light / Microsoft YaHei Light 字体（壁纸的时间/日期排版会移位）"
    info "解决: 从 Windows 复制 C:\\Windows\\Fonts\\DENGL.TTF 和 MSYHL.TTC 到"
    info "      /usr/local/share/fonts/microsoft/ 然后执行 fc-cache -f -v"
    info "      字体校验值见 linux-deploy/system/fonts.sha256"
fi

echo
echo "============================================================"
echo " 部署完成"
echo "============================================================"
echo " 启动   : $WPE_ROOT/bin/start-wallpaper.sh"
echo " 停止   : $WPE_ROOT/bin/stop-wallpaper.sh"
echo " 状态   : $WPE_ROOT/bin/status-wallpaper.sh"
echo " 体检   : $WPE_ROOT/bin/doctor.sh"
echo " 日志   : $WPE_ROOT/log/engine.log  $WPE_ROOT/log/watchdog.log"
echo " 配置   : $CONFIG_FILE"
echo " 卸载   : $HERE/uninstall.sh"
echo
