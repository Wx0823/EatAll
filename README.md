# 吃吃吃 · EatAll

独立的新项目，唯一远程仓库为 https://github.com/Wx0823/EatAll 。

本地工作目录：`E:\吃吃吃`。默认分支：`main`。

后续代码、项目文档和版本迭代在本仓库完成并提交。项目与 MiaoSK / 搜打撤相互独立，不复用其 Git 仓库、开发审批或角色方向。

已建立五个项目角色及协作、验收与复盘机制，入口见 [团队工作流](agentteam/WORKFLOW.md)。角色为可读取并派工的本地技能，不是已启动的常驻平台 agent。

当前版本 **v0.5.0**：按用户要求重做欧美烘焙卡通 UI，接入有釉面高光、厚烤边和凹陷按压状态的正式纹理，统一首页、关卡、HUD、控制台及弹窗；四个独立方向按钮组成手柄式十字键，替代轮盘。保留用户已认可的160ms移动节奏、变帧衔接、EA-R0.2下落触食、张嘴吞食与咀嚼、12关和无限撤销。实际插画素材已接入Godot，原提案保留历史，当前执行依据见 [项目决定](production/decisions.md)。

## 试玩

- 本机 Android 安装包：`E:\吃吃吃\dist\EatAll-0.5.0-android.apk`（调试签名，内部试玩）。
- 本机 Windows 辅助试玩：`E:\吃吃吃\dist\EatAll-0.5.0-windows.exe`，可直接双击，无需编辑器。
- 方向按钮短按走一格，持续按住连续走；松手停止。中间和四角空白不启动方向，已按住的手指可滑到另一键，离开整个方向区取消输入。撤销恢复整步，包括增长和连续下落。吃光点心再让头到野餐篮。
- 桌面可用方向键/WASD，Z撤销、R重开、Esc暂停；鼠标可点击或按住四个方向按钮。
- 设置可将方向键移至右手侧、关闭音效。只保存已完成关卡/设置，不保存未完成局面。

构建文件在本机 `dist/`，不放入源代码 Git。没有发布商店版本；真实手机体验和性能仍待验证。[v0.5 UI与方向键交付](production/qa/v0.5/delivery.md)、[v0.4.1下落吞食交付](production/qa/v0.4.1/delivery.md)、[此前绘制优化验收](production/qa/v0.4/delivery.md) 区分功能、画面、目标平台性能和未覆盖范围。运行时身体仍比首页插画规整，不宣称与概念等质复制。

## 开发与构建

用 Godot **4.5.1 standard** 打开 `game/project.godot`，按F6/F5或运行项目。规则在 `game/scripts/rules.gd`，地图和见证解在 `game/data/levels.json`；主程序管理输入、逐帧插值、界面和存档。关卡不是物理引擎模拟，整数状态为唯一玩法事实。

```powershell
# PowerShell，仓库根目录。参数可指向另一台机器的Godot console程序。
.\tools\test.ps1
.\tools\build.ps1 -Target All
# 独立BFS：Python 3，无第三方依赖
python tools/solve_levels.py
```

默认使用本机忽略目录 `.tools/godot_console.exe`；console封装必须与对应主程序 `.tools/godot.exe` 同目录且同名配对。可用 `-Godot C:/path/Godot_v4.5.1-stable_win64_console.exe` 指定官方完整下载。安装同版本导出模板。Android使用JDK17、SDK platform-tools、Android35、build-tools35.0.0，在Godot编辑器设置填写SDK/JDK路径。采用预构建APK模板，无自定义Gradle插件。

`python tools/setup_android.py` 仅下载并校验项目内JDK/SDK命令行工具；之后运行其中的sdkmanager安装上述三个组件并接受SDK许可。它不会自动提供Godot和模板。此机使用Godot自包含 `.tools/_sc_` + `.tools/editor_data/` 配置，不依赖其他项目设置；本机路径及签名文件不入库。参见 [Godot 4.5官方Android导出说明](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html)。

字体与引擎授权见 `game/assets/LICENSES.txt` 及同目录完整许可证，均随构建打包。AI概念图只作为美术参考，不作为碰撞数据或成品截图。正式PNG来源、使用规格及内置ImageGen提示词见 [v0.2素材制作](design/art/production-v02.md)、[v0.4口型制作](design/art/production-v04.md) 与 [v0.5 UI材质](design/art/ui-v05.md)。
