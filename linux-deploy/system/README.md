# 本机配套设置备份（GNOME / 显示器 / 字体）

这里记录的是「让这套动态壁纸看起来和原机器一致」所需的桌面侧设置。

## 文件

| 文件 | 内容 |
|---|---|
| `system.txt` | 系统、内核、桌面会话、GPU 驱动、编译器、显示器、字体解析结果 |
| `gnome-desktop-settings.txt` | GNOME Shell 已启用扩展 + `dconf` 里桌面背景与桌面图标(DING)扩展的设置 |
| `fonts.sha256` | 所需微软字体的 SHA256 校验值 |
| `fonts-README.md` | 字体来源与安装步骤 |

## 新机器上怎么用

### 1. 桌面图标扩展（必须）

壁纸要“压在图标下面”，就必须有桌面图标扩展：

```bash
gnome-extensions list --enabled | grep ding     # Ubuntu 默认已启用 ding@rastersoft.com
# 若没有：
sudo apt-get install -y gnome-shell-extension-desktop-icons-ng
gnome-extensions enable ding@rastersoft.com
```

### 2. 背景设为纯黑（可选，但推荐）

动态壁纸是不透明的，理论上盖住了背景；把背景设成黑色可以避免切换过程/壁纸崩溃时闪出别的图片：

```bash
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background picture-uri-dark ''
gsettings set org.gnome.desktop.background primary-color '#000000'
gsettings set org.gnome.desktop.background secondary-color '#000000'
gsettings set org.gnome.desktop.background color-shading-type 'solid'
```

### 3. 桌面图标大小

原机器设置为 `large`：

```bash
gsettings set org.gnome.shell.extensions.ding icon-size 'large'
```

### 4. 显示器

原机器：单屏 `HDMI-0`，`2560x1440@59.95`，主显示器，位于 `+0+0`。

分辨率/输出名不同没关系，`linux-deploy` 的脚本会自动探测；只是**几何尺寸不同会让壁纸布局按新分辨率渲染**，如需与原来完全一致，请把显示器设为 2560x1440。

### 5. 字体

见 `fonts-README.md`。

## 一次性恢复命令

```bash
# 桌面图标扩展 + 纯黑背景 + 图标大小
gnome-extensions enable ding@rastersoft.com
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background primary-color '#000000'
gsettings set org.gnome.desktop.background secondary-color '#000000'
gsettings set org.gnome.desktop.background color-shading-type 'solid'
gsettings set org.gnome.shell.extensions.ding icon-size 'large'
```

这些设置不影响其它应用，随时可以用 `gsettings reset <key>` 回退。
