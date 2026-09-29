# 吃吃吃 · EatAll

独立的新项目，唯一远程仓库为 https://github.com/Wx0823/EatAll 。

本地工作目录：`E:\吃吃吃`。默认分支：`main`。

后续代码、项目文档和版本迭代在本仓库完成并提交。项目与 MiaoSK / 搜打撤相互独立，不复用其 Git 仓库、开发审批或角色方向。

已建立五个项目角色及协作、验收与复盘机制，入口见 [团队工作流](agentteam/WORKFLOW.md)。角色为可读取并派工的本地技能，不是已启动的常驻平台 agent。

用户已批准首版方案，v0.1.0 已实现：竖屏四向轮盘、吃点心增长、整体重力/身体支撑、尖刺与边界失败、吃光后进出口、无限撤销、12关、本地解锁和音效设置。欧美卡通烘焙野餐主题采用运行时二维绘图。原提案保留历史，当前执行依据见 [项目决定](production/decisions.md)。

## 试玩

- 本机 Android 安装包：`E:\吃吃吃\dist\EatAll-0.1.0-android.apk`（调试签名，内部试玩）。
- 本机 Windows 辅助试玩：`E:\吃吃吃\dist\EatAll-0.1.0-windows.exe`，可直接双击，无需编辑器。
- 轮盘短拨走一格，持续按住连续走；松手停止。撤销恢复整步，包括增长和连续下落。吃光点心再让头到野餐篮。
- 桌面可用方向键/WASD，Z撤销、R重开、Esc暂停。鼠标拖轮盘也可操作。
- 设置可将轮盘移至右手侧、关闭音效。只保存已完成关卡/设置，不保存未完成局面。

构建文件在本机 `dist/`，不放入源代码 Git。没有发布商店版本；真实手机体验和性能仍待验证。[首版交付与验收](production/qa/v0.1/delivery.md) 区分自动测试、桌面画面和Android模拟器证据。

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

字体与引擎授权见 `game/assets/LICENSES.txt` 及同目录完整许可证，均随构建打包。AI概念图只作为美术参考，不作为碰撞数据或成品截图。
