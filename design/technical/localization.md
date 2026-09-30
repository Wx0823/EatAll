# v0.5.1 本地化契约

授权范围为简体中文、繁体中文、英文界面，以及首次按手机系统语言选择默认语言。文本保存在 `game/data/translations.json`，由 `game/scripts/localization.gd` 离线读取；不联网翻译，不改12张地图、EA-R0.2或动作时间轴。

## 语言选择与归一化

支持码为 `zh_CN`、`zh_TW`、`en`，公开常量为 `SUPPORTED_LOCALES`。`normalize_locale(raw)` 接受连字符/下划线及大小写变体：中文显式 Hant→繁体、Hans→简体，优先于地区；没有脚本时 TW/HK/MO→繁体，CN/SG、裸 zh 及其他中文地区→简体。其他语言与空原始 locale→英文。`system_locale()` 每次读取 `OS.get_locale()` 后归一化；它不缓存系统语言。

服务的 `text(key, locale, args=[])` 中，空 `locale` 表示跟随系统，不表示英文。手动覆盖保存与首次默认由主界面和进度模块管理；空字符串持久化为跟随系统。`language_name(code)` 始终返回固定的自称“简体中文”“繁體中文”“English”，避免切换后找不到另一语言。

## 目录与接口

JSON按语言码分组，每种语言包含相同83个字符串键：首页、选关、HUD、四向tooltip、撤销与动作提示、阻挡提示、胜负与保存失败、暂停、设置与语言选择，以及12关标题/提示。简体关卡文本源自当前 `levels.json`；翻译改变表达，不改变关卡数据或机制。

- `text(key, locale="", args=[])`：取得字符串，有参数时按 Godot `% args` 格式化。
- `level_title(id, locale="")`、`level_hint(id, locale="")`：分别读取 `level.%02d.title`、`level.%02d.hint`，关卡ID为1–12。
- 参数键：`levels.completed`、`hud.chapter`、`hud.moves`各1个整数；`hud.food`、`hud.food_open`各2个整数；`settings.hand`、`settings.sound`、`settings.language`各1个字符串。其他键无参数。

JSON目录在首次访问时只加载一次，包含失败时的明确错误。缺少当前语言键时警告一次并回退到简体同键；简体也缺失则返回键名，使遗漏在界面与测试中可见。没有静默自动翻译或运行时补写。

## 实际验证与边界

程序侧以 PowerShell UTF-8解析确认三语各83键；Godot 4.5.1无界面编辑器扫描退出0，无脚本错误。独立QA完成1489项本地化检查，覆盖归一化、完整目录、格式参数、字体字形、原生按钮切换和存档；另有29张桌面实画及英文390×700短屏检查。最终Android包实测系统zh-CN、应用系统语言zh-TW/en-US的自动选择，手动英文重启优先与原进度保留，详见[交付](../../production/qa/v0.5.1/delivery.md)。模拟器验证不代表真实手机覆盖。

撤销图标使用独立SVG，避免U+21B6不在内置字体中的跨平台回退差异。文字尺寸按控件可用表面自适应，保留基础字号，切换回中文或扩大窗口时可恢复；不通过裁掉完整英文提示适配短屏。

## v0.5.3 显示范围调整

按用户六图要求，首页caption/description/footer、关卡hint和临时hint、controls.tip、pause.description不再创建显示节点；翻译目录保留历史键，不作为当前屏幕必须显示的元素。HUD计数改为语言无关的`已吃/总数`，如`0/3`，在翻译后的关卡标题后同行显示现有食物方块纹理。HUD不再显示hud.food/hud.food_open文案；可用出口由棋盘真实出口外观表达，规则不变。切换语言仍只刷新现有文字，不能重新创建已退休的说明。
