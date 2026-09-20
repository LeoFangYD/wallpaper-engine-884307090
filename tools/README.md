# tools

| 文件 | 说明 |
| --- | --- |
| `convert-to-lively.py` | 把 `884307090/` 这个 Wallpaper Engine web 工程转换成 **Lively Wallpaper** 可加载的形式。详见仓库根的 [`884307090/LIVELY.md`](../884307090/LIVELY.md)。 |

## 用法

```bash
# 就地转换(会新增文件,不修改任何原有文件)
python tools/convert-to-lively.py 884307090

# 只生成到一个临时目录,自己挑要哪个
python tools/convert-to-lively.py 884307090 --output /tmp/lively-out
```

脚本是**幂等**的,可以反复运行。

## 它会生成什么

| 生成物 | 为什么需要 |
| --- | --- |
| `884307090/adapter.js` | 页面靠 `window.wallpaperPropertyListener.applyUserProperties()` 取配置(WE 专有 API)。该文件把 `project.json` 里作者的 132 项默认值喂给页面,否则页面停在"未配置"状态。 |
| `884307090/js/main-lively.js` | `js/main.js` 在解析阶段有一句反盗版校验:XHR 取 `project.json` 核对 workshop id,不匹配就跳 `error.html`。本地加载会让页面卡死,这里替换为空操作。 |
| `884307090/index-lively.html` | Lively 的入口页(加载 `adapter.js` + 原脚本 + 去掉 0 字节媒体占位的 bootstrap)。`LivelyInfo.json` 的 `FileName` 指向它。 |
| `884307090/LivelyInfo.json` | Lively 项目清单。 |
| `884307090/lively/` | 库缩略图与预览图。 |

依赖:Python 3.9+;`Pillow` 可选(只用于把缩略图缩小,缺省时会退化为直接复制原图)。
