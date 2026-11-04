# 数字华容道

5×5 数字滑动拼图，用 Godot 4.7 写成。

照片上的开局是 23 和 24 对调、空格在右下角。这个排列的逆序数是奇数，靠滑动还原不了。游戏打开时先给一局能玩的简单局；「核对照片」才进入那张图。简单、普通、难都从终态合法打乱，一定能还原。

判定和步骤说明在 `还原步骤.md`。

## 安卓安装

在 [Releases](https://github.com/JeffGu98/huarongdao/releases) 下载 `huarongdao-1.0.3.apk`。安装前允许这个来源的应用。界面按竖屏排，棋盘按屏幕宽度铺开。

打开就是一局能玩的简单局。底部可以换简单、普通、难。点与空格同一行或同一列的数字会连着滑。红边是还没归位的块，按住棋子可以看到英文。提示只标出下一步。自动还原可以在慢速、中速、快速之间改，播放中也能停。核对照片仍是那张不能靠滑动还原的图。浅局走最短步数，难局只保证能还原。

## Android 签名

正式 APK 用仓库外的项目 keystore 签名（见 [docs/android-signing.md](docs/android-signing.md)）。密钥在私有仓 `JeffGu98/huarongdao-keystore`，本仓 `export_presets.cfg` 不放密钥。本机构建可运行 `./tools/export_android.sh`。

## 本地运行

需要 Godot 4.7.2。

```bash
godot --path .
```

无界面自测：

```bash
godot --headless --path . -s res://selftest.gd
```
