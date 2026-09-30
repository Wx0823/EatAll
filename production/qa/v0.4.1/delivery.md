# v0.4.1 下落触食修正交付

2026-09-30。用户第12关截图“从上面直接落下来吃不到这个块”；旧规则可由RRDRR五步精确复现：头(6,6)与食物重叠，仍显示1/3。不是绘制错位，而是EA-R0.1禁止下落吞食。按该反馈升级EA-R0.2，地图不改。

## 修正行为

- 每安全下落格头部触到方块就收集，张嘴吞入，计数在接触时更新；身体擦过仍不收集，危险先于该行食物，食物不提供支撑。
- 整体下落保持形状，赚得增长通过growth_pending记账，下一有效主动动作保留旧尾展开一节。待增长参与旧尾是否腾空判断、完整撤销快照及独立求解键，不生成重叠/穿墙的幽灵尾格。
- 每次收集有带坐标/下落行号的事件。相邻两糖很快接触时，下一次提前张嘴不能覆盖当前吞入；长帧跨过多个事件不重复入账。

## 验证

| 项目 | 实际证据 |
| --- | --- |
| 全回归 | tools/test.ps1：412规则+539独立规则+141UI+73动作+321变帧/口型+44下落触食=1530检查，0失败；日志无SCRIPT ERROR/WARNING。 |
| 12关与求解 | 原12条见证解Godot重放全部胜利；Python含pending状态的BFS全部可解。新增11关17步UURURRRDRUULLLLLDL、12关13步RRRRDLLULDDLL由Godot重放成功；保留原地图与solution字段。 |
| 独立边界 | fall-food-review.md：多行多糖、危险优先、身体擦过、pending守恒/旧尾碰撞、主动+待增长同时最多展开1、暂停/长帧/完整撤销。 |
| 实际图形 | capture_fall_food.gd正式第12关、隔离存档、原生Input.parse_input_event；exit0/failures0，无图形错误。01–06显示接触前1/3、接触时swallow/2/3、落稳、撤销复原、重吃。阶段手动推进用于核对口型，不作为性能证据。 |
| Android最终包 | LDPlayer14 Android14实际install-r成功，versionCode5/name0.4.1；确认正式第12关0步后原生短拨RRDRR，最终5步/2颗点心，screenshots/21；原生撤销恢复4步/1颗，screenshots/22；再次右拨成功重吃。没有清理原存档。 |
| 原生录像 | native-fall-food.mp4：9秒Android系统screenrecord，真实5步、下落吞食、撤销及重吃；只压缩编码，无补帧或合成效果。 |
| 构建 | tools/build.ps1 All exit0；APK v2/v3验签通过；Windows成品headless启动45帧，显式ExitCode0且日志无错误。 |

多糖动作曾在t=0.273秒由下一糖提前张嘴覆盖第一个swallow。独立41项测试出现1失败后修复，最终44项包含原断言及额外下一接触边界，全部通过，没有削弱验收。过程保留在独立报告。

首次自动Android采集没有等到游戏首页，抓到启动占位画面，作废且不作为游戏验证；重新am start-W后确认实际首页和第12关0步，才重采上述证据。没有证据确认该启动延迟为应用代码缺陷，不伪称修复了模拟器启动问题。

## 产物

- E:/吃吃吃/dist/EatAll-0.4.1-android.apk，106995475字节，内部debug签名。
  SHA256 `62073B5AC4684911D0F90FB291EFDB6137A5D2AD43691A554018FFF95AFB3122`
- E:/吃吃吃/dist/EatAll-0.4.1-windows.exe，118461232字节。
  SHA256 `9B1AEFEB80109B4EDB79597EB157DDB2E26416A8F21CA0F227B1CC1567247FE3`

提交EatAll/main的源码、规则、测试和证据；dist及本机工具不入库。远程同步由主理人核实SHA，项目经验EA-L007已落实到系统策划与QA检查项。

## 边界

没有真实手机手指体验或新全设备性能数据，沿用v0.4的绘制架构，不能把本轮功能通过称为新帧率测量。模拟器既存FeedShaderGLES3错误仍存在；成功试玩路径无SCRIPT ERROR、triangulation或FATAL EXCEPTION。玩家对动作/规则的主观感受待试玩。
