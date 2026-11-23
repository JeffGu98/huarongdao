# 数字华容道

5×5 数字滑动拼图，用 Godot 4.7 写成。

照片上的开局是 23 和 24 对调、空格在右下角。这个排列的逆序数是奇数，靠滑动还原不了。游戏打开时先给一局能玩的简单局；「核对照片」才进入那张图。简单、普通、难都从终态合法打乱，一定能还原。

判定和步骤说明在 `还原步骤.md`。

## 安卓安装

在 [Releases](https://github.com/JeffGu98/huarongdao/releases) 下载 `huarongdao-1.0.4.apk`。安装前允许这个来源的应用。界面按竖屏排，棋盘按屏幕宽度铺开。

打开时若有新版本，底部会提示（点开可到发布页查看，不会自动安装）。打开就是一局能玩的简单局。底部可以换简单、普通、难。点与空格同一行或同一列的数字会连着滑。红边是还没归位的块，按住棋子可以看到英文。提示只标出下一步。自动还原可以在慢速、中速、快速之间改，播放中也能停。核对照片仍是那张不能靠滑动还原的图。浅局走最短步数，难局只保证能还原。

## Android 签名与发布

正式 APK 通过推送与版本号一致的标签发布（例如 `v1.0.4`）。GitHub Actions 会用仓库 Secrets 里的项目密钥签名，并挂到 [Releases](https://github.com/JeffGu98/huarongdao/releases)。同一把密钥也备份在私有仓 `JeffGu98/huarongdao-keystore`（请保持私有，不要删除；GitHub Secrets 无法再读出来）。本仓 `export_presets.cfg` 不放密钥。说明见 [docs/android-signing.md](docs/android-signing.md)。本机构建可运行 `./tools/export_android.sh`。

## 本地运行

需要 Godot 4.7.2。

```bash
godot --path .
```

无界面自测：

```bash
godot --headless --path . -s res://selftest.gd
```
