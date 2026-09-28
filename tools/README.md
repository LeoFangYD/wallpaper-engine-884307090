# tools

这个目录只有 5 个文件,都是**安装与自证**需要的,没有调试残留。

| 文件 | 给谁用 | 说明 |
| --- | --- | --- |
| `verify.py` | **使用者** | 检查这台机器能不能装、装得对不对。见下 |
| `convert-to-lively.py` | 使用者 / 维护者 | 把工程转换成 **Lively Wallpaper** 可加载的形式。原理见 [`../884307090/LIVELY.md`](../884307090/LIVELY.md) |
| `README.md` | — | 本文 |
| `verify_reproducible.py` | 维护者 | 一致性闸门:从全新克隆重跑生成器,产物须同时等于**已部署副本**与**已发布分支** |
| `verify_running_vs_repo.py` | 维护者(仅本机) | 一致性闸门:本机 Lively 库副本与分支逐 blob 比对。**只在「壁纸正跑在本机且仓库对应那份部署」时有意义,普通克隆里跑不通** |

## verify.py

```bash
python tools/verify.py                # 检查仓库本身
python tools/verify.py --convert      # 缺文件时先跑一次转换,再检查
python tools/verify.py --installed    # 附带检查当前跑的壁纸是不是这个目录
```

逐项输出 `[OK]` / `[FAIL]` / `[SKIP]`,**只用标准库**(不需要 pip install),
有 `FAIL` 时退出码为 1,可以直接用在 CI 里。它检查:

- Python 是否 ≥ 3.9
- `884307090/` 是否有 `index.html` 与 `project.json`
- 4 个生成物是否齐全(`--convert` 会先生成)
- 入口页里 bootstrap / `adapter.js` / `main-lively.js` 是否各恰好出现一次,是否还引用着原 `main.js`
- 媒体占位是否由 bootstrap 在运行时清除(原工程的 `<source src= null>` 属作者笔误,原样保留)
- `LivelyInfo.json` 的 `FileName` 是否指向入口页、路径是否为相对路径、`Thumbnail`/`Preview` 是否真实存在
- Lively 是否已安装(经 AppX 包注册表解析安装位置,因为 `WindowsApps` 默认不可列目录)
- `--installed`:当前 Lively 跑的壁纸是否就是这个目录

## convert-to-lively.py

```bash
# 就地转换(只新增文件,不修改任何原有文件)
python tools/convert-to-lively.py 884307090

# 只生成到一个临时目录,自己挑要哪个
python tools/convert-to-lively.py 884307090 --output D:\tmp\lively-out
```

脚本是**幂等**的:重复运行不会重复插入 bootstrap、`adapter.js` 标签或 favicon。
从**全新克隆**(删掉全部生成物)重跑任意次,输出都与已提交的版本逐字节相同。

> `--output` 指向一个**空的**目录时,生成的 `LivelyInfo.json` 里 `Thumbnail`/`Preview` 会是
> `null` —— 清单只登记项目里已经存在的美术资源(`preview.jpg`、`lively/`)。正式使用请就地转换。

### 它会生成什么

| 生成物 | 为什么需要 |
| --- | --- |
| `884307090/adapter.js` | 页面靠 `window.wallpaperPropertyListener.applyUserProperties()` 取配置(WE 专有 API)。该文件把 `project.json` 里作者的 132 项默认值喂给页面,否则页面停在"未配置"状态。 |
| `884307090/js/main-lively.js` | `js/main.js` 在解析阶段有一句反盗版校验:XHR 取 `project.json` 核对 workshop id,不匹配就跳 `error.html`。本地加载会让 WebView2 卡死,这里替换为空操作。 |
| `884307090/index-lively.html` | Lively 的入口页(加载 `adapter.js` + 原脚本 + 去掉 0 字节媒体占位的 bootstrap)。`LivelyInfo.json` 的 `FileName` 指向它。 |
| `884307090/LivelyInfo.json` | Lively 项目清单。 |
| `884307090/lively/` | 库缩略图与预览图。 |

依赖:Python 3.9+;**无第三方依赖**。`Pillow` 若存在则用于把缩略图缩小,不存在会退化为直接复制原图。
