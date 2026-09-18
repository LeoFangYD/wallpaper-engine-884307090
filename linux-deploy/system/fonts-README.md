# 必备字体（微软雅黑 / 等线）

壁纸的 CSS/JS 优先用 **DengXian Light（等线 Light）**，回退到 **Microsoft YaHei Light（微软雅黑 Light）**。
字体缺失时浏览器会用系统默认字体替换，时间/日期排版会整体移位。

## 需要的文件

| 文件 | 字体名 | 用途 |
|---|---|---|
| `DENGL.TTF` | DengXian Light / 等线 Light | 首选 |
| `MSYHL.TTC` | Microsoft YaHei Light / 微软雅黑 Light | 回退 |
| `DENGB.TTF` | DengXian Bold | 加粗样式 |
| `DENG.TTF` | DengXian Regular | 常规样式 |
| `MSYH.TTC` | Microsoft YaHei | 常规 |
| `MSYHBD.TTC` | Microsoft YaHei Bold | 加粗 |

**最小集合**：只要 `DENGL.TTF` + `MSYHL.TTC` 排版就正确。

## 安装（字体授权原因，仓库不包含字体二进制）

从任意 Windows 机器的 `C:\Windows\Fonts\` 复制上述文件，然后：

```bash
sudo mkdir -p /usr/local/share/fonts/microsoft
sudo cp DENGL.TTF MSYHL.TTC /usr/local/share/fonts/microsoft/
sudo fc-cache -f -v

# 校验（输出的字体名应包含 DengXian / 等线 和 YaHei / 雅黑）
fc-match "DengXian Light"
fc-match "Microsoft YaHei Light"
```

## 校验值

安装后用 `sha256sum` 对比仓库里的 `fonts.sha256`（路径按实际安装位置替换）：

```bash
cd /usr/local/share/fonts/microsoft
sha256sum -c /path/to/repo/linux-deploy/system/fonts.sha256
```
