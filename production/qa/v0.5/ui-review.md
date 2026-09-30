# v0.5 UI与四方向键独立验收

日期：2026-09-30。工作根E:/吃吃吃，origin EatAll已核实。对象：真实四Button方向键与厚度图片UI；不改变EA-R0.2规则、160ms移动调度或地图。

## 输入与旧测试适配

新增game/tests/test_direction_pad.gd：**75项，0失败**。使用Input.parse_input_event/flush_buffered_events发送真实Godot原生事件链，涵盖四键准确方向、第一触点所有权、模拟鼠标过滤、真鼠标、滑键转向、中心空白/角落不捕获、空白起按拖入不启动、有效触点滑入中心归零、越整个pad取消owner且拖回不复活、二指不能抢占、禁用/隐藏/失焦清理。

main集成测试覆盖短按一步、650ms长按5步（隔离30格走廊）、松开不留队列、转向在动画边界执行、暂停恢复、撤销、重开、焦点丢失。使用隔离QA存档，不修改用户正式进度。

几何在180×180与短屏162×180两种pad尺寸实查：恰四个真实Button，实际get_global_rect互不相交、全部在父范围内、中心空白、每键至少44逻辑像素。不能只用240大夹具得出短屏结论。

旧test_ui.gd只替换摇杆中心+45px等输入坐标为button_center，deadzone/对角测试改为真实中心/角落空白；ownership、原生按钮、暂停、存档、关卡与短屏关键断言未移除。test_motion/test_responsiveness不依赖控制外形，无需改动。历史capture_fall_food/capture_motion/capture_responsiveness仅输入helper改用button_center，没有重跑它们覆盖历史截图。

## 最终完整测试

最终实际执行tools/test.ps1，exit0。完整输出保留test-log.txt。

| 套件 | 检查 | 失败 |
|---|---:|---:|
| Rules | 412 | 0 |
| Independent rules | 539 | 0 |
| UI | 141 | 0 |
| Motion | 73 | 0 |
| Responsiveness | 321 | 0 |
| Fall food | 44 | 0 |
| Direction pad | 75 | 0 |
| 合计 | **1605** | **0** |

没有为通过新控件而放宽移动/规则/下落吃糖断言。

## 实际图形审查

最终命令：`.tools/godot_console.exe --path game --fixed-fps 60 --script res://tests/capture_ui_v5.gd`。Godot4.5.1/Windows/RTX5060Ti OpenGL3.3，退出0、UI_V5_CAPTURE failures=0、完整日志无ERROR/WARNING。详见capture-log.txt。固定步长截图只验证画面，不是性能证据。

逐张实际查看screenshots/01–10，最终微调后再次看03/07/08/09：

- 首页01/02正常与按下对照：橘色主按钮存在真实上表面、侧厚度和按下凹陷，按钮文字可读。原生点击Start实际进入游戏。
- 关卡03/方向键04：四个分离方键、中心空白，上键按下有独立凹陷；未伪装成仍可自由斜移的圆摇杆。按键状态与direction同时断言。
- 暂停05/设置06及短屏设置10：标题和按钮未裁切，没有额外遮挡造成无法操作。
- 选关07：完成/可进入/锁定视觉区分明确，底部提示已加奶油描边，可从花叶背景读出。
- 短屏08/右手09：390×700均可看清方向箭头，实际子按钮≥44px、父范围正确；控制区与棋盘没有交叠。方向键提示已移到操作按钮上方，不压方向键。
- 首轮Hint文字落在深金侧边、低对比，独立QA指出后主理人改44高浅表面与INK文字；最终03/08/09已实际复看，提示可读。HUD标题/食物计数/步数也已上移，未与厚底或暂停按钮重叠。

**结论：通过本轮桌面UI与Dpad输入独立验收。** 真机手指触达、Android成品操作与目标平台性能由主理人后续实际验证，不从75/1605检查或桌面截图推断。人物/身体风格的既有保留项不因本轮UI修订自动关闭。已停止Godot任务并冻结QA文件供主理人构建；未修改main/skin/renderer/Git。
