# v0.5.1 三语设置交付

2026-09-30，EatAll，基线6974d4c / v0.5.0。范围为简体中文、繁体中文、英文及设备语言默认选择；没有修改规则、地图、运动调度或角色绘制。

## 成品

| 产物 | 字节数 | SHA256 |
|---|---:|---|
| `dist/EatAll-0.5.1-android.apk` | 107406110 | 1C8CBEC5D8F9C5706DC614A09FE250E6F33B1F953FD8301833546F421AD6F455 |
| `dist/EatAll-0.5.1-windows.exe` | 118877920 | C6F7E3E81AE2AD69EEF8CAC8947E81256B7A25608B1F748824A967BF80813904 |

tools/build.ps1 -Target All成功；Android versionCode7/versionName0.5.1，内部调试签名，apksigner验证v2/v3有效、退出0。Windows最终成品headless运行45帧退出0，日志仅有引擎版本。构建产物在本机dist，不加入源码Git。摘要见[verification.txt](verification.txt)。

## 行为与验证

- 设置 → 语言：跟随系统、简体中文、繁體中文、English；固定原生语言名称便于切回。首次/旧存档没有偏好时跟随系统；手动选择立即刷新并保存，重启优先；选择跟随系统恢复自动，应用重新获得焦点时再次读取系统语言。
- 中文显式Hans/Hant脚本优先；无脚本时TW/HK/MO为繁体，其他中文为简体，非中文回退英文。每语83个键，含12关标题/提示、菜单、动态HUD、暂停、实际胜负与保存失败提示。英文自适应字号；撤销改为SVG图标，避免依赖系统字体回退。
- 独立QA使用隔离存档完成本地化1489项/0失败，全部8套3094项/0失败。原规则、运动、变帧、下落吞食和方向键检查继续通过，没有削弱断言。29张480×854/390×700真实桌面截图通过，实际胜负由L1通关、L7尖刺触发；完整证据见[独立报告](localization-review.md)及本目录txt日志。
- 最终APK覆盖安装LDPlayer14实例1，Android14、720×1280；真实adb触摸与画面已由主理人检查。原有12关完成、右手方向键和音效开保持；未清除正式存档。语言测试前后只比较存档字段，不发布用户存档。

最终Android截图（本目录screenshots）：

| 图 | 实际验证 |
|---|---|
| native-01-auto-zh-CN、02-settings-auto、03-picker | 旧v1存档无语言字段，设备zh-CN默认简体，设置与四个语言选项可用 |
| native-04-manual-en | 点English后设置与背后首页立即英文 |
| native-05-manual-en-restart-zh-TW | 将Android应用系统语言设zh-TW后冷启动，手动英文仍优先 |
| native-06-auto-zh-TW、07-auto-zh-TW-levels | 点跟随系统立即繁体，设置、首页、选关均更新 |
| native-08-auto-en-US、09-auto-en-US-game | 应用系统语言en-US，自动英文首页/L12；新词序Steps 0，完整提示与撤销图标可见 |
| native-10-english-one-step | 原生右键60ms短按：Steps 1、Treats 1/3，英文HUD及SVG撤销正常 |
| native-11-auto-zh-TW-game | 再次zh-TW冷启动，L12标题/提示/操作说明繁体，无缺字或裁切 |
| native-12-auto-restored-picker | Android应用语言恢复[]、全局zh-CN保持，游戏恢复跟随系统；实际简体picker选中且原进度/手/音效字段保留 |

Android自动语言测试使用cmd locale的**应用级**系统语言覆盖，不修改全局手机语言；测试结束恢复原[]。应用读取实际OS.get_locale，不注入游戏变量模拟手机自动选择。全球地区/语言组合另由独立映射边界测试覆盖，未逐台真机验证。

## 环境问题与限制

覆盖安装后的首次普通am start -W未完成启动，ActivityManager日志确认新进程被“remove task”终止。force-stop后以NEW_TASK|CLEAR_TASK (`am start -f 0x10008000`)重新启动成功，所有最终原生截图来自实际游戏界面；这清理Activity任务而非应用数据。首次原因只确认到模拟器任务移除，未定位系统内部根因，不把最早占位屏当通过截图。

桌面测试/捕获及最终构建没有ERROR/WARNING。Android过滤未见SCRIPT ERROR、FATAL EXCEPTION、triangulation failed、can_process；此前已知模拟器FeedShaderGLES3报错仍存在，实际二维界面正常，未宣称环境错误根治。没有新增FPS结论，真实手机兼容性、真人触达和主观体验仍待试玩。

主理人复核实现差异、实际原生图及产物hash后汇总Git；唯一远程Wx0823/EatAll/main，同步以推送后远程SHA核验为准。经验EA-L009已落实程序/QA检查项，无跨项目记忆或模型修改。
