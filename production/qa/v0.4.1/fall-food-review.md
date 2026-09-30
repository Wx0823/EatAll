# EA-R0.2 下落吃食物独立验收

版本目标：v0.4.1。日期：2026-09-30。授权/新契约由主理人传达：安全下落行的头接触食物立即吃，落体形状保持，新增长度存growth_pending并在下一主动步最多展开一节；危险优先，身体擦过不吃。不是沿旧规则维持“落头不吃”的断言。

## 独立规则与UI状态测试

`game/tests/test_fall_food.gd` 为独立新测试，不修改旧地图或共享实现。最小夹具：初始头(2,2)身体向左三节，仅尾支撑(0,3)，主动向右后落三行，头在(3,3)/(3,5)各遇一糖。

初次实际执行：39项/0失败。覆盖：

- 两糖逐安全行即时移除；eat总标记与active_ate分开，事件frame1/frame3及坐标/向下正确。
- 下落body.size保持3，growth_pending累计2；下一主动步body增1/pending减1。
- 主动吃糖同时有pending时只长一节，余量保留；输入快照不被修改。
- 同行尾碰刺且头碰糖时危险先，糖保留，无pending/eat_event；身体擦过不吃。
- 空中通过出口不赢，落稳后再判定；pending保留旧尾，不能使用“旧尾本步会让开”例外。
- 真实第12关RRDRR五步复现：第5步(6,6)糖吃掉，剩余1糖，body.size+pending=5。
- main的长delta、后续idle及暂停不重复入账；undo恢复所有body/food/moves/pending，重吃一次成功。

新增多糖动画精确检查后41项/1失败：首个下落糖在t=0.273秒接触，cursor=1/worldfruit=1，但mouth从swallow同帧变回opening。原因可从helper顺序复现：下一糖接触仅约82ms后，已经进入提前100ms窗口，while循环立刻anticipate下糖并覆盖当前吞入。这属于真实动作时序缺陷，已报告主理人，未削弱断言。

## 原生输入与实际画面

`game/tests/capture_fall_food.gd` 从真实第12关用Input.parse_input_event发送轮盘触摸RRDRR与原生撤销按钮；自动process关闭，按10ms手动推进main/renderer以精确卡接触时刻，实际Godot图形渲染截图。存档隔离user://qa/fall-food-capture.json，不是Android真机，也不是帧率证据。

实际运行exit0、`FALL_FOOD_CAPTURE failures=0`，完整输出无ERROR/WARNING。逐张实际打开screenshots/01–06：

- 01第五步前：4步、HUD1/3，目标糖仍在中层。
- 02落头接触前25ms：HUD1/3，糖仍在，嘴已张开。
- 03接触后10ms：HUD2/3，世界糖移除，swallow口中显示缩入糖副本。
- 04落稳：HUD2/3、5步，pending1，身体形状没有凭空拉伸。
- 05原生撤销：HUD1/3、4步，目标糖恢复，pending0。
- 06重吃：再次2/3、5步、pending1，未双重计数。

当前单糖实际复现与undo通过；多糖相邻动画覆盖问题待修后追加最终结果。未执行Android安装、adb、Git或性能复测。

## 最终边界复测

主理人修正提前准备下一糖时覆盖当前swallow的问题后，原失败断言原样重跑通过；再新增三个邻接边界：到第二糖提前窗口内仍保持第一个食物source(3,3)，到第二个真实接触才换source(3,5)并再次swallow，累计pending恰为2。最终实际执行 **44检查/0失败，exit0**，输出首接触mouth=swallow/cursor1/visible_fruit1。

结论：**通过EA-R0.2本轮下落吃食物独立验收**。用户第12关第五步复现、HUD接触时计数、真实吞入画面、撤销/重吃及多糖危险/增长边界均有对应证据。原生输入图形脚本失败数0、日志无错误；最后修正只影响已新增检查覆盖的多糖时序，单糖截图无变化，未无意义重复拍摄。Android构建、目标设备运行与提交由主理人完成；本评审者不宣称已经独立做过这些步骤。
