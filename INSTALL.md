# 安装到 Lively Wallpaper(任意 Windows 电脑)

这个仓库是 **Wallpaper Engine 的 web 工程**,不能直接当桌面壁纸用。本文说明怎么在**一台新电脑**上
把它装成动态桌面壁纸,以及怎么**自证装对了**。

## 必备步骤(照这个顺序做)

四步,每步都给了「怎么确认成功」。全程不需要 Wallpaper Engine、Steam、.NET 或 Node.js。

| # | 做什么 | 命令 / 操作 | 成功的标志 |
| --- | --- | --- | --- |
| **1** | 装 Lively Wallpaper | [Microsoft Store · Lively Wallpaper](https://www.microsoft.com/store/productId/9NTM2QC6QWS7) | 开始菜单能启动 Lively |
| **2** | 克隆仓库(**放浅路径**) | `git clone https://github.com/LeoFangYD/wallpaper-engine-884307090.git` | 目录里能看到 `884307090/` 和 `tools/` |
| **3** | 转换 + 自检 | `python tools/verify.py --convert --installed` | 末行 `RESULT: ready to import into Lively`,退出码 0 |
| **4** | 导入 | Lively → **Add Wallpaper** → 选 `884307090` **文件夹** | 桌面出现樱花粒子动态壁纸 |

第 3 步的输出长这样(15 项检查):

```
  [OK] python >= 3.9
  [OK] project folder 884307090/
  [OK] generated files
  ...
15 checks: 15 ok, 0 failed, 0 skipped
RESULT: ready to import into Lively (Add Wallpaper -> select the 884307090 folder)
```

> 嫌克隆慢可以直接下 ZIP,但**必须解压后再导入** —— Lively 要的是文件夹。
> 仓库里**已经提交了**转换产物,所以第 3 步在干净克隆上通常只需做自检;
> 跑 `--convert` 只是确保一定齐全。

下面是要点说明和排错。

## 0. 环境要求

| 项目 | 要求 | 说明 |
| --- | --- | --- |
| 系统 | Windows 10 1809+ / Windows 11 | Lively 只支持 Windows |
| Lively Wallpaper | 任意近期版本(实测 v2.2.1.5) | 商店版或 [GitHub Release](https://github.com/rocksdanister/lively/releases) 均可 |
| Python | **3.9+** | 只用标准库,**不需要 pip install**、不需要第三方包 |
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

## 7. 真正必备的文件(其余都不需要)

整条路径只依赖这些文件,每个都有明确职责:

| 文件 | 必备原因 | 能删吗 |
| --- | --- | --- |
| `884307090/` 整目录 | 壁纸本体。`index.html`、`project.json`、`js/`、`style/`、`imgs/` 缺一不可 | ❌ |
| `884307090/index-lively.html` | Lively 实际加载的入口页 | ❌ |
| `884307090/adapter.js` | 代替 WE 专有配置 API,喂入作者 132 项默认值;没有它页面停在"未配置" | ❌ |
| `884307090/js/main-lively.js` | 去掉解析期反盗版校验;没有它 WebView2 卡死 | ❌ |
| `884307090/LivelyInfo.json` | Lively 项目清单,指向入口页 | ❌ |
| `884307090/lively/` | 库里显示的缩略图/预览图 | 缺了仍能跑,但库列表没图 |
| `tools/verify.py` | 安装前后自检 | ✅ 可删,但删了就没法自证 |
| `tools/convert-to-lively.py` | 重新生成上面那 4 个文件 | ✅ 可删(文件已提交),但换 Python 版本后想重生成就需要 |
| `tools/verify_running_vs_repo.py`、`tools/verify_reproducible.py` | 一致性闸门:确认「跑着的 = 仓库里的 = 生成器产出的」 | ✅ 可删,开发者自用 |
| `linux-port/` | Linux 路线,与 Windows 无关 | ✅ Windows 用户可删 |

**这个仓库不依赖任何第三方 Python 包。** `verify.py`、`convert-to-lively.py`、
`verify_reproducible.py`、`verify_running_vs_repo.py` 全部只用标准库;
`convert-to-lively.py` 里对 Pillow 的引用是**可选**的(缺省时退化为直接复制原图)。

## 8. 排错

| 现象 | 原因与处理 |
| --- | --- |
| 自检报 `[FAIL] generated files` | 直接跑 `python tools/verify.py --convert` 生成即可 |
| 自检报 `[SKIP] Lively Wallpaper installed` | 没装或装在非标准位置。装完后重跑;若装在自定义目录,自检找不到不算失败 |
| 自检报 `[FAIL] manifest Thumbnail ... null` | 说明有人用 `--output` 生成到了空目录。**就地**重新转换:`python tools/convert-to-lively.py 884307090` |
| 导入后**全黑** | 十有八九是加载了 `index.html` 而不是 `index-lively.html`。请选 `884307090` **文件夹**让 Lively 读清单,别单独拖 `index.html` |
| Lively 里看不到这一项 | 确认选的是**文件夹**且里面有 `LivelyInfo.json` |
| `git clone` 报路径太长 | 换 `D:\` 这类浅路径;或在组策略里启用长路径支持 |
| `python` 不是内部或外部命令 | 装 Python 3.9+ 并勾选 **Add python.exe to PATH**,或改用 `py tools\verify.py --convert` |
| 壁纸能跑但没有声音 | **预期行为**,见第 6 节:音频是 0 字节占位文件 |
| 桌面上出现莫名的色块/图标错乱 | **与壁纸无关**。实测过一次,根因是 Windows 图标缓存损坏,重建 `iconcache_*.db` 并重启后消失;壁纸退出后色块依旧存在即可确认与此工程无关 |
| 想确认「桌面跑的就是仓库里这份」 | 跑 `python tools/verify_running_vs_repo.py`(需本机已是运行副本;它按 git blob SHA-1 逐字节比对) |

## 9. 卸载

Lively 里删掉壁纸 → 关闭 **Start with Windows** → 删除克隆下来的仓库文件夹即可。
本工程**不往系统里装任何东西**,不改注册表,不加自启动项。
