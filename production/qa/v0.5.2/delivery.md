# v0.5.2 按钮文字位置交付

2026-09-30，EatAll，基线14906c9。用户指出语言列表和英文首页按钮文字偏低，本轮统一上调至釉面上表面。

## 修改

横按钮文字/图标上移7个逻辑像素；四向及暂停/返回方键符号上移3px。正常、悬停、按下与禁用共享对应修正；按下仍向下移动4px。覆盖首页、设置、语言列表、选关、撤销/重开、暂停和胜负弹窗，三语同时生效。

仅修改UiSkin上下内容边距及版本。横键总留白22px、方键18px不变，文字容纳尺寸和自适应字号、点击区域保持；普通面板/小提示条不套用。规则、运动调度、地图、翻译与存档无代码变化。生产规格见[说明](../../../design/art/ui-v05.md)。

## 验证

独立QA复用了实际截图流程，新capture_button_alignment.gd只输出本目录：三语480×854、英文390×700，共35张。包括首页、设置、语言、选关、L12、暂停、真实L1胜利/L7尖刺失败，以及原生Input按住首页/语言按钮。未见明显偏高、偏低、上下裁切或文字落入饼干侧壁。详见[报告](button-alignment-review.md)。

相关原测试：UI141、方向键75、本地化1489，合计**1705项/0失败**，日志无ERROR/WARNING，未削弱断言或新增镜像单元测试。没有修改运动/规则，因此本轮未重复未受影响的全部套件，不沿用上版3094数字作为本轮结果。

最终APK覆盖安装Android14/LDPlayer14实例1（720×1280），没有清除应用数据。原生触摸打开设置/语言、进入游戏/暂停；主理人复看以下实际图：

- native-01-home：简体首页，主/次按钮文字位于釉面内。
- native-02-picker：用户反馈对应的语言列表及背后首页按钮已上移。
- native-03-english-home：英文Keep Snacking、Levels、Settings对齐釉面。
- native-04-english-game：实际L1，禁用Undo与SVG图标、Restart、四向符号和暂停键位置正常。
- native-05-english-pause：实际暂停，主/次按钮文字完整。

Android英文由应用级系统locale en-US、游戏跟随系统产生。验证后应用locale恢复原[]，正式进度与手/音效/语言字段比较均保持。Windows最终成品headless运行45帧退出0，日志仅引擎版本。APK签名v2/v3有效。

## 产物与边界

| 产物 | 字节数 | SHA256 |
|---|---:|---|
| dist/EatAll-0.5.2-android.apk | 107406110 | F73AE33AD8F6161D23A6F539259AA76BF78F4B3ABE20E69317FC44EE5AF69FC5 |
| dist/EatAll-0.5.2-windows.exe | 118877936 | A6B0BA96C0BE0FC0CC8B1F44BA6AD5C1AE61637C4333EDBE566050AFCF621129 |

tools/build.ps1 -Target All退出0；Android versionCode8/versionName0.5.2。内部调试APK和Windows成品在本机dist，不加入源码Git。

Android模拟器本轮起初未运行，启动既有实例后安装成功，未改模拟器配置或清存档。仍有旧FeedShaderGLES3环境错误，二维游戏正常；过滤未见SCRIPT ERROR、FATAL EXCEPTION、triangulation failed、can_process。没有宣称该兼容错误根治、真机全部覆盖或新的性能结论。文字视觉已由独立QA和主理人实际图复核，用户主观满意仍需试玩。

EA-L008追加本次放行标准不足的复盘，美术检查项已明确以釉面中心验收，避免只检查不裁切。主理人汇总提交到唯一EatAll/main，完成以远程SHA核验为准。
