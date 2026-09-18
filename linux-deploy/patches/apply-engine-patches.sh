#!/usr/bin/env bash
# ==============================================================================
# apply-engine-patches.sh — 把 engine/ 下的补丁打到 linux-wallpaperengine 源码上
#
# 用途：
#   * 上游更新后，把本地适配补丁迁移到新版本（而不是一直用冻结的源码快照）；
#   * 验证补丁与归档快照完全等价。
#
# 用法:
#   ./apply-engine-patches.sh <上游源码目录>      # 直接给已 clone 的目录
#   ./apply-engine-patches.sh --clone <目标目录>  # 脚本自己 clone 上游再打补丁
#   ./apply-engine-patches.sh --verify            # 打完补丁后与归档快照逐文件比对
#   ./apply-engine-patches.sh --check             # 只检查能否干净应用，不落盘
#
# 说明：补丁基线是上游 b016d7d（与本仓库快照同日）。上游若已变动，
#       用 --3way 风格的三方合并失败时请手工解决冲突，冲突文件会列出来。
# ==============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$HERE/../.." && pwd -P)"
PATCH_DIR="$HERE/engine"
SNAPSHOT_ARCHIVE="$REPO_ROOT/linux-port/linux-wallpaperengine-working-source.tar.xz"
UPSTREAM_URL="https://github.com/Almamu/linux-wallpaperengine.git"

TARGET=""
DO_CLONE=0
DO_VERIFY=0
DO_CHECK=0

while [ $# -gt 0 ]; do
    case "$1" in
        --clone) DO_CLONE=1; TARGET="${2:?--clone 需要目标目录}"; shift 2 ;;
        --verify) DO_VERIFY=1; shift ;;
        --check) DO_CHECK=1; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) TARGET="$1"; shift ;;
    esac
done

die() { printf '错误: %s\n' "$*" >&2; exit 1; }
[ -d "$PATCH_DIR" ] || die "找不到补丁目录: $PATCH_DIR"

if [ "$DO_CLONE" = "1" ] && [ -n "$TARGET" ]; then
    [ -e "$TARGET" ] && die "目标已存在: $TARGET（请换个目录或先删除）"
    echo "== 克隆上游: $UPSTREAM_URL"
    git clone --depth 1 --no-recurse-submodules "$UPSTREAM_URL" "$TARGET" || die "clone 失败"
fi

[ -n "$TARGET" ] || die "请给出上游源码目录，或使用 --clone <目录>"
[ -d "$TARGET/.git" ] || die "$TARGET 不是 git 检出（补丁用 git apply，需要有 .git）"
TARGET="$(cd "$TARGET" && pwd -P)"

cd "$TARGET" || die "无法进入 $TARGET"
echo "== 目标仓库: $TARGET"
git log -1 --format='   HEAD: %h %s' 2>/dev/null || true

FAILED=0
for p in "$PATCH_DIR"/*.patch; do
    name="$(basename "$p")"
    if [ "$DO_CHECK" = "1" ]; then
        if git apply --check "$p" 2>/dev/null; then
            echo "   ✓ 可应用  $name"
        else
            echo "   ✗ 冲突    $name"
            FAILED=1
        fi
        continue
    fi
    if git apply "$p" 2>/dev/null; then
        echo "   ✓ 已应用  $name"
    elif git apply --3way "$p" 2>/dev/null; then
        echo "   ✓ 三方合并 $name"
    else
        echo "   ✗ 失败    $name（需手工解决，冲突文件见 git status）"
        FAILED=1
    fi
done

if [ "$DO_CHECK" = "1" ]; then
    [ "$FAILED" = "0" ] && echo "== 全部补丁可干净应用" || echo "== 有补丁冲突，请先看 README 的冲突处理说明"
    exit "$FAILED"
fi

[ "$FAILED" = "0" ] || die "有补丁未应用成功，请先处理冲突再编译"

if [ "$DO_VERIFY" = "1" ]; then
    echo
    echo "== 与归档快照逐文件比对"
    [ -f "$SNAPSHOT_ARCHIVE" ] || die "找不到归档快照: $SNAPSHOT_ARCHIVE"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    echo "   解压快照到 $TMP（约 120MB）"
    tar -xJf "$SNAPSHOT_ARCHIVE" -C "$TMP" || die "解压失败"
    for rel in \
        src/WallpaperEngine/Render/Drivers/GLFWOpenGLDriver.cpp \
        src/WallpaperEngine/WebBrowser/CEF/RenderHandler.cpp \
        src/WallpaperEngine/WebBrowser/CEF/BrowserApp.cpp \
        src/WallpaperEngine/Application/WallpaperApplication.cpp \
        src/WallpaperEngine/Data/Builders/ColorBuilder.cpp \
        src/WallpaperEngine/Media/MediaSource.h \
        src/WallpaperEngine/Render/Wallpapers/CWeb.cpp
    do
        if diff -q "$TARGET/$rel" "$TMP/$rel" >/dev/null 2>&1; then
            echo "   ✓ 一致  ${rel##*/}"
        else
            echo "   ✗ 不一致 ${rel##*/}"
            FAILED=1
        fi
    done
    if [ "$FAILED" = "0" ]; then
        echo "== 验证通过：上游 + 补丁 == 归档快照"
    else
        echo "== 验证失败：补丁与快照不等价"
    fi
fi

echo
echo "下一步：让部署使用这份源码——在 ~/.config/wallpaper-engine-linux/wallpaper.conf 里"
echo "        把 WPE_SRC_DIR 指向 $TARGET，然后运行 <ROOT>/bin/build-engine.sh。"
exit "$FAILED"
