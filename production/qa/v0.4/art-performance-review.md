# v0.4 第三版renderer独立美术与性能边界复核

日期：2026-09-30。对象：本轮第三版renderer，单带状mesh、静态层缓存和新增口型。此评审者不修改renderer/main/probe，不执行Git，也不覆盖v0.3历史截图。

## 实际执行

1. `.tools/godot_console.exe --path game --script res://tests/capture_responsiveness.gd`：exit0、无ERROR/WARNING；五阶段口型截图写本轮v0.4目录。
2. `.tools/godot_console.exe --path game --fixed-fps 60 --script res://tests/capture_cache_v4.gd`：exit0、`CACHE_ART_REVIEW failures=0`、完整输出无ERROR/WARNING/多边形错误。Godot4.5.1、Windows、RTX5060Ti OpenGL3.3；存档user://qa/v04-cache-review.json隔离。

新增capture_cache_v4仅为本轮缓存/长弯回归：真实第一关吃糖、撤销，真实第12关完整15步解法走完；关卡选择和try_move由脚本驱动，因此不冒充第二次原生触摸验收。口型原生触摸证据仍由capture_responsiveness提供。

## 结果

| 检查 | 证据与结论 |
|---|---|
| 静态层缓存 | Idle经过12个实际SceneTree帧，static_draw_calls_total未增加。证明复用命令；不代表AndroidGPU耗时。 |
| 食物与出口变化 | 11-cache-food-closed、12-cache-eaten-open：吃糖后食物移除、篮开盖；13-cache-undo-restored：撤销后方糖与闭篮恢复，无旧缓存残留。逻辑与_static_exit_open均检查，12/13实际打开复看。 |
| 暂停/撤销 | 移动中暂停结算后reaction在12个真实树帧中保持，renderer process关闭；恢复后可撤销，不留旧食物状态。 |
| 长体紧弯 | 真实第12关完整15步以动画运行并成功；15-level12-step-06/10/13实际打开：L/U形与长竖身连续，头尾、剩余糖、紫刺和出口可区分，未见缺面或错位。 |
| Resize | 390×700→480×854后cell增大，16-resize-short/17-resize-restored留证。短屏实看没有UI裁切、静态地形未留在旧坐标。 |
| 口型 | 01–05继续有闭嘴→张口→食物缩入口内→闭嘴；独立面部帧仍有效，没有因性能重构退化成只缩放整张脸。 |
| 风格保留 | 当前身体纹理/截面仍比概念规整，属于已记录保留项；头部插画、连续腹纹、物件和背景风格保留。不能写作与概念完全等质。 |

## 目标平台性能不能由桌面代替

本评审者没有在此任务自行执行Android探针。主理人回报此前候选实测：初版活跃board_draw约95–99ms，混合2秒窗口process/presents约12.5Hz、maxdelta约150ms，而idle60Hz；后续尝试仍约90/75ms。因此已经有**主理人实测证据**把用户录像台阶指向活跃游戏绘制瓶颈，不能继续泛泛归责模拟器录屏，也不能只加快输入步长。详细原始探针、候选对应关系及最终数值应以主理人性能记录为准，本段不冒充独立重测。

之前QA桌面固定帧+功能通过没有覆盖目标平台活跃CPU绘制成本，这是EA-L006后仍存在的覆盖漏洞。防范应是：凡每帧绘制算法或资产管线显著变化，在目标平台分别采idle、持续移动、长体紧弯；记录输入/逻辑、渲染CPU、实际呈现和输出画面边界，不能用桌面0.127ms或固定帧录像替代Android。用户录屏帧率仍不能直接当GPU真实FPS。

**当前结论：第三版renderer桌面功能与视觉回归通过；Android性能验收待主理人的最终第三候选实测。** 本报告没有给尚未观察的真机、Android性能或用户手感盖章。

## 最终冻结版定向复跑

在最后一版renderer冻结（grid批量纹理mesh、粒子纹理、共享斑点缓存、尾端补截面）后，再次顺序执行上述两个v0.4图形capture。两者均exit0，缓存脚本`failures=0`，完整控制台没有ERROR/WARNING；未使用adb、未运行历史capture、未重测无变化的时间轴。

最终重新实际打开02-opening、03-swallow-start、13-cache-undo-restored、15-level12-step-10/13、16-resize-short：张口与口中方糖可见，撤销恢复糖与闭篮，长体U弯与折角连续，短屏地形与UI对应，未见粒子/grid纹理化造成遮挡或旧缓存残留。静态缓存复用、暂停和resize断言仍通过。最终桌面美术/缓存回归结论保持通过；目标平台性能结论继续引用主理人最终Android实测，不由本次桌面运行推断。

## 最终Android依赖完成（来源归属明确）

主理人已完成最终包Android验收，本评审者读取并交叉核对 `delivery.md` 与 `verification.txt`，没有另行执行Android或adb。文档记录本机LDPlayer14/Android14实际输出720×1280、系统录屏开启：第一关四次650ms长按各3步通关；第12关60ms原生短拨后等待650ms，共15步3颗点心通关。

最终动态棋盘CPU_draw：L1采样0.31–2.38ms；L12运动混合窗口0.16–0.21ms，近终局0.76ms、胜利粒子窗口2.43ms。process/present混合窗口约56–58Hz；不是持续运动GPU FPS。对比同环境早期候选95–99ms的绘制成本，主理人的最终实测支持目标模拟器卡顿显著改善。原生视频证据由主理人提供 `native-gameplay.mp4`、`native-long-body.mp4`。

此前本报告的“Android性能等待”依赖已由上述**主理人实测**完成；本人独立性限于源码行为、桌面图形回归与交付文档交叉核对，不写成独立Android重测。真实手机、全设备覆盖、首次资源峰值和主观接受度限制仍然保留。审核发现静态总绘制总范围未包含verification中L1的16–18us，已回报主理人修正文档范围；不影响动态性能对比结论。

最终文档范围复核回执：主理人已采纳静态数字修正，首次grid按最终摘录写0.086ms，静态总CPU绘制写0.016–0.101ms，与现有摘录一致。上述已报静态范围不一致关闭；本轮独立复核完成，无待修文档阻断项。
