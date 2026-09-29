# EatAll v0.1 独立QA记录

2026-09-29。被测工作区：`E:/吃吃吃/game`，实施中的未提交快照；提交标识由主理人交付时关联。本报告作者未编写被测规则或UI实现，独占测试文件并独立构造规则反例。先前参与技术提案不等同于本轮实现作者。

## 规则验收：通过（限已列覆盖）

实际环境：Windows，Godot `4.5.1.stable.official.f62fdbde1`，headless。命令：

```powershell
& 'E:\搜打撤GPT\.tools\godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path 'E:\吃吃吃\game' --script res://tests/test_independent.gd
```

首次执行退出码0，无脚本编译错误；随后自查将危险优先夹具改为合法起点下落中段碰刺且头到出口的场景，替代初始已踩刺的无效前提，针对改动重跑仍为539断言、0失败。实际输出：

```text
QA_LEVEL id=1 steps=3 status=won
QA_LEVEL id=2 steps=5 status=won
QA_LEVEL id=3 steps=4 status=won
QA_LEVEL id=4 steps=5 status=won
QA_LEVEL id=5 steps=8 status=won
QA_LEVEL id=6 steps=5 status=won
QA_LEVEL id=7 steps=5 status=won
QA_LEVEL id=8 steps=7 status=won
QA_LEVEL id=9 steps=10 status=won
QA_LEVEL id=10 steps=5 status=won
QA_LEVEL id=11 steps=18 status=won
QA_LEVEL id=12 steps=15 status=won
INDEPENDENT_QA checks=539 failures=0
```

独立夹具验证了：反向/撞墙/非四向无效输入不改变状态；增长恰好加一；旧尾腾空可入、增长保留尾时不可入、两格身体仍不可反向；仅尾托底可支撑、离开最终支点下落、侧墙不托底；经过和停在果实上不自动吃；逐格下落中段碰刺即停；经过出口不胜且出口不支撑、落稳全清头进才胜；危险优先；边界立即失败；终局阻止继续移动。

快照检查验证调用者状态、关卡果实与返回/动画帧彼此不意外别名；这证明规则层可提供撤销源，不单独证明UI撤销按钮已正确接入。另测重复果实、断裂身体、不稳定出生被数据校验器拒绝。部分边界夹具是运行中间态而非可发布初始地图，明确不交给初始地图合法性验证。

12关实际加载并逐动作调用生产规则：检查唯一ID、地图约束、每步有效/不死、长度守恒、源状态不可变以及完整胜利终态。此为候选解重放，没有穷尽搜索；不能推导最短解、唯一解、完整死局检测或好玩程度。

## UI、输入与进度

实际命令同上，将脚本替换为 `res://tests/test_ui.gd`。最新定向回归执行退出码0，输出 `INDEPENDENT_UI_QA checks=140 failures=0`，日志无ERROR或WARNING。早期132项结果已由补齐原生触摸仿真链后的140项取代。

最终使用 `Input.parse_input_event` 注入原生 InputEventScreenTouch，经引擎触摸转鼠标仿真进入按钮链路；没有把直接Viewport触摸转发当作按钮仿真证据。检验首页开始按钮、轮盘死区、初次对角边界、多指归属、短拨增长、动画期间释放不补走、真实长按节奏直到成功停步、撤销按钮、无效输入历史、暂停/恢复、重开、失焦清空输入。直接经过主程序控制器完成失败后整步撤销和12关全部候选解；每关检查成功面板，检查下一关解锁与重复完成幂等。

存档使用 `user://qa/independent-<进程ID>.json` 及独立恢复夹具路径，退出只删除这些确定路径，不修改正式进度。实际验证通关落盘、12关读回、损坏主文件回退前版备份和无法创建有效父路径时明确失败。

首次快速同帧回放退出出现ObjectDB警告；verbose列出AudioStreamWAV/Playback未排空。测试退出前等待0.7秒让音频回调完成后，复跑警告消失、全部断言通过。原因定位为加速测试生命周期；没有修改产品音频或据此宣称音质通过。

故意写坏JSON的恢复案例原由 `JSON.parse_string` 打印 `Expected key`，功能回退通过；主理人改为JSON实例显式处理parse结果，最终140项回归该错误日志消失，恢复断言仍通过。

触摸按钮补测闭环：项目原先关闭触摸转鼠标仿真，早期测试只证明鼠标按钮和原生轮盘，未覆盖Android按钮输入链。主理人启用仿真并让轮盘忽略仿真鼠标；QA改为 `Input.parse_input_event`。初次夹具错误使用逻辑480×854坐标，headless实际窗口64×64，导致触摸错位；按 `root.get_screen_transform()` 转换后按钮可用，保留失败即退出保护。

原生链随后暴露Start/Resume/Restart在输入派发中同步移出节点的 `can_process !is_inside_tree()` ERROR；已回传主理人，按钮回调改为deferred后最终回归日志干净。原生触摸Start、暂停、继续、撤销、重开成功；轮盘一次触摸只发一步，仿真鼠标不重新夺取触点，多指不偷控，长按和释放仍按原约定工作。

短屏补测使用实际Control矩形：390×700、两种轮盘位置下，轮盘与撤销/重开无交叠、主要控件不越界、棋盘不占手指区，共6项通过。这是布局几何验收，不能代替文字清晰度和图片视觉审看。

覆盖限制：12关控制器回放关闭动画以快速检查流程，单独触摸案例保留真实动画和计时；没有把直接控制器调用写成全部关卡真实手动触摸通关。该桌面headless输入验证不证明真机操作舒适度或屏幕视觉质量。

## 分发与体验边界

主理人最终增补：依据Godot4.5.1源码，关闭SceneTree默认quit_on_go_back，避免Android返回键在自定义暂停逻辑之外直接退出。新增1项配置断言后主理人实际定向复跑UI141/0、exit0、日志干净。此增补为主理人复跑，前述140项才是独立QA本次执行计数；最终分发证据见delivery.md。

本报告当前没有Android安装、真机触达、拇指长按、设备安全区、真实玩家体验或性能结论。桌面headless事件注入即使通过，也只能证明软件输入链路，不等于Android真机触控。APK构建和安装证据由主理人统一关联，未完成项保留。



