# v0.2 美术返工交付

2026-09-29。用户指出v0.1实机与批准效果图差距过大，本轮按原方向直接返工。独立美术评审明确旧版风格验收不通过；本轮结论为有保留通过，见art-review.md末节。

## 已进入运行包的改动

- 多层手绘草地/树叶/野餐布背景，首页完整角色插画，六格玩法精灵表与失败惊讶脸。
- 连续珊瑚身体、奶油腹纹、斑点与软转角；保留真实格子规则，绝不使用整张效果图充当棋盘。
- 更紧凑HUD与控制区，扩大棋盘；材质按钮和轮盘高光，PNG mipmap改善小尺寸采样。
- 修正左向头图镜像偏移，碰撞格加入角标，独立四向/折返/动态截图复核。

完整资产与提示词在 `design/art/production-v02.md`；正式资源在 `game/assets/art-v2/`。均使用内置ImageGen，未用CLI fallback。背景/物件没有改变关卡或碰撞规则。

## 实际验证

| 证据 | 结果 |
|---|---|
| 功能回归 | tools/test.ps1：410规则+539独立规则+141UI=1090断言，0失败。规则/地图逻辑未改。 |
| 桌面图形 | capture_art_v2.gd --fixed-fps60：最终exit0，13张新图含5连续运动帧；图14为明确标识的视觉夹具，不是关卡。 |
| 最终打包 | tools/build.ps1 All成功，APK versionName0.2.0 / versionCode2；签名v2/v3校验通过。 |
| Windows成品 | 最终EXE headless启动45帧exit0，stderr空；图形表现另以真实Godot截图核对。 |
| Android安装 | 最终APK在现有Android14 / LDPlayer实例1实际adb install -r Success，启动成功，dumpsys确认versionCode2/versionName0.2.0。 |
| Android操作 | 根据真实截图定位菜单/轮盘，进入第7关；点击R、U看到2步/全收集/开篮；点撤销回1步/食物恢复，系统Back出现暂停；继续后U、R、R、D到5步成功面板。不是直接调用状态或跳关。 |
| 保存 | 覆盖升级后旧11/12通关记录仍可见；没有清除应用数据。未据此声称v0.2全部关卡手动试玩。 |

`screenshots/15-android-home.png`、`16-android-level07.png`、`17-android-pause.png`、`18-android-level07-won.png` 均来自此最终APK的Android模拟器画面。首次截图800ms仍是引擎启动页，等待实际首页后重新采集，没有把启动页当作成功界面。

## 本地产物

- `E:\吃吃吃\dist\EatAll-0.2.0-android.apk`，调试签名内部试玩。
  SHA256 `DA41F5AF78900E60FB1A749E1822E1154CF8250BFBCC54AD1597880649246C59`
- `E:\吃吃吃\dist\EatAll-0.2.0-windows.exe`，Windows x64辅助试玩。
  SHA256 `D9D17B6765A32326254DA6C648DF91B3710CE7E83D039FF6A7B2B0E44E2C433A`

旧0.1包保留，新0.2包另名生成。产物在本机dist，不提交Git二进制、不宣称已发布商店；源码、生产素材和报告提交EatAll。

## 保留项

程序生成身体截面/纹理比首页插画规整，上下头方向主要靠颈部连接表达，390短屏密关的表情细节仍小。独立QA的有保留结论不转换成“完全还原效果图”。Android只覆盖当前模拟器，真机手指遮挡、安全区、多GPU和性能未验收；模拟器启动时已知FeedShaderGLES3外部采样器错误未根治，当前二维绘制和操作正常。
