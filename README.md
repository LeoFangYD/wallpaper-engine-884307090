# wallpaper-engine-884307090

Steam 创意工坊 **884307090「完美壁纸」**(Wallpaper Engine **web** 类型工程)在各种桌面引擎上的
移植归档。仓库里的 `884307090/` 是**原工程本体**,以下两条路线都**不改动它的原有文件**。

![效果](884307090/lively/lively-screenshot.jpg)

## 这个工程是什么

一个 HTML5 动态壁纸:WebGL 樱花粒子着色器、`backstretch` 动态背景、实时时钟/日期、天气组件、
音频可视化圆环(PWLine / PWCircle)。它通过 Wallpaper Engine 的专有 API 读取配置,其中的媒体资源
(`audio/*.ogg`、`video/*-test.webm`)在仓库里是 **0 字节占位文件** —— 作者的完整媒体通过 Steam
创意工坊分发。

## 选一条路线

| 平台 | 引擎 | 怎么做 | 说明 |
| --- | --- | --- | --- |
| **Windows** | [Lively Wallpaper](https://github.com/rocksdanister/lively) | **[`INSTALL.md`](INSTALL.md)** | 推荐入口。装 Lively → 克隆仓库 → 跑一次转换 → 导入,不改动上游文件 |
| **Linux** | 自编译 `linux-wallpaperengine` | [`linux-port/README.md`](linux-port/README.md) | Ubuntu GNOME X11 完整适配归档,含启动/watchdog/自动启动脚本 |

### Windows(Lively Wallpaper)

```bash
git clone https://github.com/LeoFangYD/wallpaper-engine-884307090.git
cd wallpaper-engine-884307090
python tools/verify.py --convert      # 生成 Lively 需要的文件(只新增)
python tools/verify.py --installed    # 自证:15 项检查
```

然后在 Lively 里 **Add Wallpaper → 选 `884307090` 文件夹**。

逐步说明、环境要求、常见问题见 **[`INSTALL.md`](INSTALL.md)**;转换原理见
**[`884307090/LIVELY.md`](884307090/LIVELY.md)**。

## 目录

```
884307090/              原工程本体(Wallpaper Engine web 工程)
├─ project.json         工程清单,含作者预留的 132 项可调属性
├─ index.html           原入口页(保持不变)
├─ js/ style/ imgs/     原脚本、样式、贴图
└─ lively/              为 Lively 生成的缩略图/预览图
linux-port/             Linux(CEF)适配归档,含源码快照与脚本
tools/                  转换与校验脚本(见 tools/README.md)
INSTALL.md              任意 Windows 电脑的安装与自检指南
```

## 工具

| 脚本 | 用途 |
| --- | --- |
| `tools/verify.py` | **给使用者**:检查这台机器能否装、装得对不对。`--convert` 先转换,`--installed` 附带检查当前跑的壁纸 |
| `tools/convert-to-lively.py` | 把工程转换成 Lively 可加载的形式,幂等,只新增文件 |
| `tools/README.md` | 转换原理与各生成物的作用 |

## 已知差异

- **没有声音** —— 仓库里的音频/视频是 0 字节占位文件(见上)。
- **天气默认关闭**,与作者默认(`weather_show=false`)一致。
- 原工程 `index.html` 写的是 `<source src= null>`(作者笔误)。**原样保留**,因为本移植承诺不改动
  上游文件;运行时由 bootstrap `removeAttribute('src')`,不会产生网络请求。

## 许可与来源

原工程版权归其作者所有,来自 Steam 创意工坊 884307090。本仓库只做平台移植适配,
`884307090/` 下的原有文件未被修改。
