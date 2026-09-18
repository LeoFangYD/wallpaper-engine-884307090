#!/usr/bin/env bash
# ==============================================================================
# build-engine.sh — 编译 linux-wallpaperengine
#
# 说明：
#   * 源码来自 install.sh 解压的归档快照，子模块已内置，不需要 git submodule；
#   * CEF 由 CMake 在 configure 阶段自动下载（约 150MB，需要联网），
#     版本固定在 CMakeLists 里的 135.0.17+gcbc1c5b+chromium-135.0.7049.52；
#   * 编译需要约 10GB 空闲磁盘（CEF 解压 + 中间产物）；
#   * 全部产物落在 $WPE_BUILD_DIR/output/，运行时不依赖安装到 /usr。
#
# 用法:
#   ./build-engine.sh                 # 按当前配置编译
#   ./build-engine.sh --clean         # 删掉 build 目录后全新编译
#   ./build-engine.sh --jobs 16       # 指定并行度（默认 nproc）
# ==============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
. "$HERE/../lib/common.sh"

CLEAN=0
JOBS="$(nproc 2>/dev/null || echo 4)"

while [ $# -gt 0 ]; do
    case "$1" in
        --clean) CLEAN=1; shift ;;
        --jobs) JOBS="${2:?--jobs 需要参数}"; shift 2 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) wpe_die "未知参数: $1（-h 查看用法）" ;;
    esac
done

# ---------- 1. 工具检查 ----------
MISSING=()
for c in cmake g++ make tar bzip2 patch; do
    wpe_have "$c" || MISSING+=("$c")
done
if [ ${#MISSING[@]} -gt 0 ]; then
    wpe_die "缺少编译工具: ${MISSING[*]}
请先安装（Ubuntu 22.04）:
  sudo apt-get install -y \$(grep -v '^#' $HERE/../deps/ubuntu-22.04.txt | tr '\\n' ' ')
或直接运行: $HERE/../install.sh --install-deps"
fi

[ -d "$WPE_SRC_DIR" ] || wpe_die "源码目录不存在: $WPE_SRC_DIR
请先运行 install.sh（它会解压 linux-port/linux-wallpaperengine-working-source.tar.xz）"
[ -f "$WPE_SRC_DIR/CMakeLists.txt" ] || wpe_die "$WPE_SRC_DIR 里没有 CMakeLists.txt，源码归档可能不完整。

提示：也可以用 --reuse-build 复用别的机器上已经编译好的 build 目录，
避免在每台机器上重复下载 CEF 和编译。"

if [ "$CLEAN" = "1" ]; then
    echo "== 清理旧的 build 目录: $WPE_BUILD_DIR"
    rm -rf "$WPE_BUILD_DIR"
fi

mkdir -p "$WPE_BUILD_DIR"
LOG="$WPE_BUILD_DIR/build.log"
echo "== 编译日志: $LOG"
echo "== 源码: $WPE_SRC_DIR"
echo "== 产物: $WPE_BUILD_DIR/output/linux-wallpaperengine"

# ---------- 2. configure（会联网下载 CEF） ----------
echo
echo "== [1/2] cmake configure（首次会下载 CEF，请保持联网）"
if ! cmake -S "$WPE_SRC_DIR" -B "$WPE_BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$WPE_ROOT" \
        >"$LOG" 2>&1; then
    tail -n 40 "$LOG" >&2
    wpe_die "cmake configure 失败（完整日志: $LOG）"
fi

# ---------- 3. build ----------
echo "== [2/2] 编译（并行 $JOBS 路，首次约 10~30 分钟）"
if ! cmake --build "$WPE_BUILD_DIR" -j "$JOBS" >>"$LOG" 2>&1; then
    tail -n 40 "$LOG" >&2
    wpe_die "编译失败（完整日志: $LOG）"
fi

# ---------- 4. 校验 ----------
if [ -x "$WPE_ENGINE_BIN" ]; then
    echo
    echo "✓ 编译完成: $WPE_ENGINE_BIN"
    ls -la "$(dirname "$WPE_ENGINE_BIN")" | head -n 8
    echo
    echo "下一步: $HERE/../scripts/doctor.sh  然后  $HERE/../scripts/start-wallpaper.sh"
else
    wpe_die "编译流程结束但没有生成 $WPE_ENGINE_BIN，请检查日志: $LOG"
fi
