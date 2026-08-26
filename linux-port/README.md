# Wallpaper Engine 884307090 - Ubuntu Linux Port

这是 Wallpaper Engine Workshop 884307090 的 Ubuntu GNOME X11 完整适配归档。

## 已实现

- CEF Web Wallpaper 渲染
- NVIDIA/OpenGL 修复
- Web Wallpaper 黑屏修复
- CEF zygote 子进程兼容
- GNOME 桌面层级修复
- 桌面图标显示在动态壁纸上方
- PulseAudio 系统音频捕获
- PWCircle 实时声纹响应
- 静音时显示白色圆环
- 樱花效果适配
- DengXian Light / Microsoft YaHei Light 字体适配
- 时间和日期整体居中、内部左对齐
- 天气隐藏
- 手动启动和关闭
- watchdog 异常退出自动恢复
- GNOME 登录自动启动

## 文件

884307090/
最终修改后的 Web Wallpaper。

linux-port/linux-wallpaperengine-working-source.tar.xz
当前可工作的 linux-wallpaperengine 完整源码快照。
不包含 build 目录。

linux-port/scripts/
启动、停止、watchdog 和自动启动脚本。

linux-port/autostart/
GNOME 自动启动配置。

linux-port/environment/
当前系统和编译环境信息。

linux-port/fonts/
所需字体名称和 SHA256。
Microsoft 字体文件本身不上传。

## 恢复源码

创建目录：

    mkdir -p ~/linux-wallpaperengine

解压：

    tar -xJf linux-port/linux-wallpaperengine-working-source.tar.xz -C ~/linux-wallpaperengine

恢复脚本：

    cp linux-port/scripts/*.sh ~/linux-wallpaperengine/
    chmod +x ~/linux-wallpaperengine/*.sh

恢复开机启动：

    mkdir -p ~/.config/autostart
    cp linux-port/autostart/linux-wallpaperengine.desktop ~/.config/autostart/

检查字体：

    fc-match "DengXian Light"
    fc-match "Microsoft YaHei Light"

启动：

    ~/linux-wallpaperengine/start-wallpaper.sh

停止：

    ~/linux-wallpaperengine/stop-wallpaper.sh

## 注意

build/ 没有归档，因为它约 3.4GB，并且需要针对本机重新编译。

Microsoft 字体二进制文件没有上传到公开 GitHub 仓库。

linux-wallpaperengine 原目录没有 .git 元数据，因此这里保存的是当前实际可工作的完整源码快照。
