# v0.5.1 本地化独立 QA

状态：本轮独立桌面验证已完成，详见最终验收。验证环境 Windows / Godot 4.5.1；图形采用本机 Compatibility OpenGL。所有存档使用 user://qa/localization-*，未接触正式进度。未使用 Android/adb，不把桌面截图当作目标平台字形或真人体验证据。

## 首轮发现

- test_localization：1469 项，1 项失败（见 first-pass-missing-glyph.txt）。自带 NotoSansSC 缺少 U+21B6（↶），三个语种的 controls.undo/end.undo 使用该字符。Windows 实画中系统 fallback 恰好显示，不能证明 Android 可移植。
- 已报主理人：撤销改用独立图标并移除缺字文本前缀，保留 font.has_char 正确断言，不放宽覆盖。
- 首轮 29 张图形截图及其原生尺寸/按钮表面空间检查为 0 失败，完整日志无绘图错误。实际审看英文 390×700 首页、设置、语言选择、L12 和暂停，以及繁体 picker/L12、英文胜负，文字没有截断或与厚底重叠。

## 覆盖与限制

- 系统语言脚本 Hans/Hant 优先于地区；CN/SG、TW/HK/MO、英语及非中文回退。实际 OS 自动语言 + 人工输入 locale 映射；没有修改手机系统地区设置。
- 旧 version 1 存档补 language 空字符串；无效字段回退自动且保留 completed/左右手/声音。原生触摸四种语言选项；手动保存读回，后续启动不被 OS 覆写。
- 切换时首页/设置立即更新，关卡标题/提示/工具提示、动态步数及真实 L1 胜利、L7 尖刺失败文本。玩法状态和撤销历史完整保持。
- 三语言目录全键、所有输出字符自带字体覆盖；无空文本和 %s/%d 残留。全 12 关标题/提示。
- 图形为真实游戏场景；失败由 L7 的 RR 实际触发，不是伪造状态。固定场景截图不代表触屏主观手感或运行 FPS。

## 最终验收

结论：本轮桌面独立功能与视觉范围通过；Android 由主理人继续打包/安装验收，本文未替代该证据。

- 主理人移除 ↶ 文本并为两处撤销按钮接入 undo.svg 后，未放宽字体断言。新增原生语言名称/四键符号/选中标记字符覆盖、语言重启恢复与切换后即时标题断言，最终 **1489 / 0**。
- `tools/test.ps1` 全 8 套 **3094 项 / 0 失败**：rules 412、independent 539、UI 141、motion 73、responsiveness 321、fall_food 44、direction_pad 75、localization 1489。退出码 0，完整结果 `full-test.txt`；本轮没有修改旧测试或削弱规则/时序断言。
- `capture_localization.gd` 最终重新生成全部 **29 张** 480×854 / 390×700 真实图形截图，失败数 0、退出码 0。最终 `capture.txt` / `full-test.txt` / `test-localization.txt` 无 ERROR、WARNING、Invalid、failed 匹配。
- 最终复看 `en-12-short-game` / `en-08-failure-ui`，SVG 撤销图标在常驻按钮与失败按钮均可见，不依赖 Windows 字体回退；文字可读、未裁切。复看繁体设置、英文选关和先前短屏各页，新文字与主题材质一致。
- `screenshots/`：每种语言 01 首页、02 设置、03 语言列表、04 选关、05 L12、06 暂停、07 实际胜利、08 实际失败；英文另含 09–13 短屏首页/设置/picker/L12/暂停。
- 本轮停止所有 Godot 进程后交接主理人 Android build；无 Git/adb 操作，无正式存档写入。


交接后文案微调：主理人将英文步数 `%d Steps` 改为 `Steps %d`，参数契约不变。上述最后一轮截图仍记录旧词序；未为该一处文案重复全套测试，最终 Android 图由主理人确认新词序。
