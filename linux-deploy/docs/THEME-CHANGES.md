# 壁纸本体（884307090）的定制记录

仓库里的 `884307090/` 是**改过的**壁纸：原版是给 Windows 版 Wallpaper Engine 的 Web 壁纸，
依赖 Windows 端注入的属性与音频 API。下面是所有定制点，行号为当前文件的实际位置，
代码里都以 `Linux` 注释标记，便于日后对照上游壁纸版本。

> 这些文件都在仓库里（已提交），换机部署时自动带上，无需手工改。

## 1. `style/default.css`

| 行 | 内容 | 作用 |
|---|---|---|
| 20 | `#show { display:none; }` | 隐藏顶部的信息/天气块（原版天气接口早已失效，脚本里也停用了旧接口） |
| 28 / 52 / 73 | `font-family:"等线 Light","Microsoft Yahei Light";` | 时钟、日期等文字改用 DengXian Light / 微软雅黑 Light，与 Windows 端观感一致 |

字体需自行从 Windows 安装（授权原因不入库），见 `../system/fonts-README.md`。

## 2. `js/time.js` —— 布局基线 + 整体居中

| 行 | 内容 | 作用 |
|---|---|---|
| 83 | `/* ===== Linux Web Wallpaper default layout ===== */` | 说明：linux-wallpaperengine 不会调 `wallpaperPropertyListener`，因此直接在 JS 里套用原项目属性（tX/tY/DateX/DateY/tSize/DateSize）的等效默认值 |
| 96 | `recenterLinuxClockGroup()` | 让"时间 + 日期"共用同一左边缘，并让**整组文字的实际宽度**居中于 PWCircle 圆心（而不是按容器居中） |
| 118–119 / 197–209 | `style.textAlign = 'left'` | 组内左对齐，保证冒号/位数变化时左侧不跳动 |
| 171 | `applyLinuxDefaultLayout()` | 应用上述默认布局，窗口 resize 后重新计算（226 行） |
| 215 | `// Linux 下继续关闭旧天气接口` | 停用已失效的第三方天气 iframe |
| 369 | `recenterLinuxClockGroup()` | 定时刷新时重新居中，避免数字位数变化后偏移 |

## 3. `js/PWCircle.js` —— 声纹圈兼容

| 行 | 内容 | 作用 |
|---|---|---|
| 242 | `/* ===== Linux PWCircle compatibility ===== */` | 说明：Windows 端由 `wallpaperPropertyListener` 注入的可视化参数，Linux 端没有，这里补默认值（`PolygonAngle = 180` 等） |
| 275–280 | `window.wallpaperRegisterAudioListener = function(cb){ window.__linuxWallpaperEngineAudioListener = cb; }` | 兼容 Wallpaper Engine 的音频注册 API，并把回调存下来，供**引擎侧音频桥**（补丁 0007）调用 |
| 355–365 | 启动时用全 0 的 `silentSpectrum` 调一次 `wallpaperAudioListener()` | Windows 端即使静音也会持续推送音频帧；这里补上，保证**静音时也显示白色圆环** |

## 4. `js/main.js`

`clearT()` / `clearWT()`（174、184 行）里的 `try/catch`：清理定时器时容忍变量未定义，
避免 Linux 端启动顺序与 Windows 不同导致整份脚本中断。

## 5. `project.json` —— 壁纸属性快照

这是**你在 Wallpaper Engine 里调过的全部参数**，也就是壁纸的"设置文件"本体。
相对原始版本的可见差异（`project.json.bak-layout-fix` → 现在）：

| 属性 | 原值 | 现值 | 作用 |
|---|---|---|---|
| `DateY`（日期-Y，%） | 54 | **48** | 日期上移，与时间成组后整体居中 |
| `WratherY`（天气-Y，%） | 57 | **62** | 配合天气块位置（天气已隐藏，仅保留参数） |
| `WeatherFormat` | 3 | **10** | 天气格式（天气已隐藏，仅保留参数） |

另外整份 JSON 被重新整理为 4 空格缩进、并按当前生效值序列化（与 `project.json.bak-before-linux-fix`
相差约 4900 行，主要是格式与天气相关项的差异，不是 4900 处功能改动）。

> 想恢复某个参数：直接改 `884307090/project.json` 里对应的 `"value"`，重启壁纸即可；
> 两个 `.bak-*` 备份在本地仓库目录里（被 `.gitignore` 排除，不会上传公开仓库）。

## 相关备份文件（本机保留，未上传）

| 文件 | 内容 |
|---|---|
| `884307090/project.json.bak-before-linux-fix` | 移植到 Linux 之前的属性快照 |
| `884307090/project.json.bak-layout-fix` | 布局微调（DateY/WratherY/WeatherFormat）之前的值 |
| `linux-wallpaperengine/src/**/*.bak-before-*` | 引擎改动的原始文件，`../patches/` 里的补丁即由它们生成 |
