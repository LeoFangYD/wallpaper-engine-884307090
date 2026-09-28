# 安装到 Lively Wallpaper(任意 Windows 电脑)

这个仓库是 **Wallpaper Engine 的 web 工程**,不能直接当桌面壁纸用。本文说明怎么在**一台新电脑**上
把它装成动态桌面壁纸,以及怎么**自证装对了**。

> 只想快速上手:装好 [Lively](https://www.microsoft.com/store/productId/9NTM2QC6QWS7) →
> `git clone` 本仓库 → `python tools/verify.py --convert` → Lively 里 **Add Wallpaper** 选
> `884307090` 文件夹。下面是要点说明。

## 0. 环境要求

| 项目 | 要求 | 说明 |
| --- | --- | --- |
| 系统 | Windows 10 1809+ / Windows 11 | Lively 只支持 Windows |
| Lively Wallpaper | 任意近期版本(实测 v2.2.1.5) | 商店版或 [GitHub Release](https://github.com/rocksdanister/lively/releases) 均可 |
| Python | **3.9+** | 只用于转换脚本;`tools/verify.py` 只用标准库,**不需要 pip install** |
| 磁盘 | 约 200 MB | 仓库本体 93 MB + 生成的缩略图 |

> **不需要** Wallpaper Engine、Steam、.NET SDK、Node.js。

## 1. 安装 Lively Wallpaper

- **商店版(推荐)**:[Microsoft Store · Lively Wallpaper](https://www.microsoft.com/store/productId/9NTM2QC6QWS7)
  装完后可执行文件在
  `C:\Program Files\WindowsApps\12030rocksdanister.LivelyWallpaper_<版本>_x64__97hta09mmv6hy\Build\Lively.exe`
  (该目录默认**不可列目录**,属正常现象)。
- **GitHub Release 版**:从 [releases](https://github.com/rocksdanister/lively/releases) 下载安装包。

## 2. 拿到仓库

```bash
git clone https://github.com/LeoFangYD/wallpaper-engine-884307090.git
cd wallpaper-engine-884307090
```

> **路径别放太深**。工程里有一个中文名文件 `884307090/map/1 拷贝.png`,Windows 默认 260 字符
> 路径上限下,克隆到 `C:\Users\<你>\Desktop\a\b\c\...` 这类深层目录可能失败。放
> `D:\wallpaper-engine-884307090` 这种浅路径最省事。

## 3. 转换(生成 Lively 需要的文件)

```bash
python tools/verify.py --convert
```

它会调用 `tools/convert-to-lively.py`,在 `884307090/` 里**只新增** 4 个文件 + `lively/` 图片,
**不修改仓库里任何一个原有文件**:

| 生成物 | 作用 |
| --- | --- |
| `884307090/index-lively.html` | Lively 入口页 |
| `884307090/adapter.js` | 喂给页面作者的 132 项默认设置(WE 专有 API 的替代) |
| `884307090/js/main-lively.js` | 去掉反盗版校验的 `main.js` 副本 |
| `884307090/LivelyInfo.json` | Lively 项目清单 |
| `884307090/lively/` | 库缩略图与预览图 |

不想跑脚本也行:仓库里**已经提交了**这些文件,直接进第 4 步即可。

> 转换是**幂等**的:重复运行不会重复插入任何东西。也可以 `--output` 生成到别处先看看:
> `python tools/convert-to-lively.py 884307090 --output D:\tmp\out`
> 注意此时生成的 `LivelyInfo.json` 里 `Thumbnail`/`Preview` 会是 `null`,因为清单只登记项目里
> 已经存在的美术资源 —— 要正式用就别用 `--output`。

## 4. 导入 Lively

1. 打开 Lively → **Add Wallpaper**(加号)→ 选择 `884307090` **文件夹**
   (Lively 见到 `LivelyInfo.json` 就按项目导入)。
2. 在库里点击 **完美壁纸 884307090** 生效。
3. 右键 → **Customise** 可调作者预留的属性;想开机自启就在 Lively 设置里开
   **Start with Windows**。

命令行方式(路径里的版本号按实际替换):

```powershell
$lively = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Filter "12030rocksdanister.LivelyWallpaper*" |
          ForEach-Object { Join-Path $_.FullName "Build\Lively.exe" } | Select-Object -First 1
if (-not $lively) { $lively = "C:\Program Files\Lively Wallpaper\Lively.exe" }
& $lively setwp --file "<仓库路径>\884307090"
```

## 5. 自证装对了

```bash
python tools/verify.py --installed
```

它会逐项检查 Python 版本、工程完整性、4 个生成物、入口页的 bootstrap/适配层/校验替换、
清单的 `FileName` 与路径、Lively 是否安装、以及(带 `--installed`)当前跑的壁纸是不是这个目录。
全部通过时退出码为 0:

```
15 checks: 15 ok, 0 failed, 0 skipped
RESULT: ready to import into Lively (Add Wallpaper -> select the 884307090 folder)
```

## 6. 预期效果与已知差异

- 画面:动画背景、樱花粒子、音频可视化圆环、实时时钟/日期,桌面图标与任务栏不受影响。
- **没有声音**:仓库里 `audio/*.ogg`、`video/*-test.webm` 是 **0 字节占位文件**(作者真正的媒体
  通过 Steam 创意工坊分发),bootstrap 会把它们移除。想要声音就放入真实音频文件。
- **天气默认关闭**(`project.json` 里 `weather_show=false`),与作者默认一致。
- 原工程 `index.html` 里写的是 `<source src= null>`(作者的笔误)。这个值**原样保留**,因为本分支
  承诺不改动任何上游文件;运行时 bootstrap 会 `removeAttribute('src')`,所以不会产生网络请求。

## 7. 卸载

Lively 里删掉壁纸 → 关闭 **Start with Windows** → 删除克隆下来的仓库文件夹即可。
本工程**不往系统里装任何东西**,不改注册表,不加自启动项。
