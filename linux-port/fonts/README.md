# Required fonts

本 Linux 壁纸使用：

- DENGL.TTF
  - DengXian Light
  - 等线 Light

- MSYHL.TTC
  - Microsoft YaHei Light
  - 微软雅黑 Light

本机安装位置：

/usr/local/share/fonts/microsoft/

由于字体授权原因，本公开 GitHub 仓库不包含 Microsoft 字体文件。

安装字体后可使用以下命令检查：

fc-match "DengXian Light"
fc-match "Microsoft YaHei Light"

当前 CSS/JavaScript 会优先使用 DengXian Light，
然后回退到 Microsoft YaHei Light。
