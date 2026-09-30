# v0.5.0 UI 与十字方向键交付

2026-09-30，EatAll 独立项目，EA-R0.2。用户认可现有流畅度，本轮改变 UI 与控制器样式，不修改移动调度、玩法规则或地图布局。

## 成品

| 产物 | 字节数 | SHA256 |
|---|---:|---|
| `dist/EatAll-0.5.0-android.apk` | 107393392 | BF023A918BE6CCCC3C0BD8A2F096F499B1B62A2E99AD571CEE68B4FE74C44681 |
| `dist/EatAll-0.5.0-windows.exe` | 118857560 | DAE8ED4B8EBD05A5BA8ABEED4F324EF1346B27673E5706DA300420D443129BAB |

Android versionCode 6/versionName 0.5.0，内部调试签名。apksigner verify 退出0，v2/v3签名有效。Windows最终成品headless启动45帧退出0，无脚本/运行警告。构建成功且最终hash已重新核对，不只复用首轮候选包。

## 界面与输入

- 正式ImageGen透明图册接入：奶油、珊瑚、薄荷、葡萄釉面及厚烤边/投影/按压下陷，来源与切片规格见[美术制作](../../../design/art/ui-v05.md)。大面板、小信息条、固定比例方键分别定切片；暂停与返回也使用方键，避免横条九宫格挤方形。
- 首页、选关、HUD、底部控制台、提示和弹窗统一。字体加重，提示放在浅表面且用深葡萄文字，禁用标签保留可读性。控制区扩大，棋盘和提示避开四键。
- 四真实Button十字布局，中央和角落空白。短按一步、长按连走，滑到另一键可转向，第一触点拥有、模拟鼠标不双发；离开整个方向区/释放/失焦/禁用复位。左右手设置保留，输入契约见[说明](../../../design/technical/dpad-contract.md)。

## 实际验证

独立QA完成75项新方向键检查并适配旧UI坐标，原规则/动画断言没有削弱。主理人在最后禁用字色、小方键及选关标题位置调整后重新完整执行tools/test.ps1：**1605项/0失败，exit0**。最终10张桌面图重新捕获，UI_V5_CAPTURE failures=0；完整输出为test-log.txt/capture-log.txt。原12关见证解、连续/变帧运动及下落吞食仍通过。独立美术另只读审看最终首页/游戏/暂停/选关/短屏，无明显切片缝或文字压侧壁；横按钮文字稍靠下面缘但完整可读。

最终APK实际安装覆盖LDPlayer14实例1（Android14、720×1280竖屏），没有清除正式存档。以实际截图确认界面完成启动后再操作；首轮立即截图仍在Godot splash，等待后获得完整首页，未拿启动页当游戏验收。

原生adb触摸行为与截图：

- `21-native-home` 首页；`22-native-play` 左手十字键、最终方形暂停及灰化撤销。
- `23-native-short-press` 60ms右键短按后恰1步、点心1/1；`24-native-undo` 恢复0步、点心0/1。
- `25-native-held-win` 650ms右键长按后L1三步通关，四键禁用，新的实体材质胜利面板可操作。
- `26-native-levels` 最终选关标题和完成计数均在奶油面内；已有12关完成进度保留。
- `27-native-settings` 方向键位置文本正确；实际切到左手后得到22–31的左手布局，验证后在`32-native-hand-restored`恢复原右手设置及原音效开状态。
- `28-native-level12` 最终Android完整关卡界面；原生四键输入RRDRR后`29-native-fall-food`显示5步/点心2/3，原下落触食修正保持。
- `30-native-pause` 暂停材质与禁用键；点继续后`31-native-resume`仍5步/2颗，没有重放旧输入。

`native-controls.mp4` 是最终APK的真实原生录屏，约8.60秒、720×1280，覆盖短按、撤销、长按与胜利。重编码使用fps_mode passthrough，保留350帧、无插帧；录像容器帧数不当作游戏FPS。主理人看过截图和录像采样联系图。未启用frame_probe标记，默认诊断保持关闭。

## 日志与边界

最终桌面测试、图形捕获、构建和Windows成品日志没有ERROR/WARNING。Android未见SCRIPT ERROR、can_process、triangulation或FATAL EXCEPTION；模拟器仍有此前已知FeedShaderGLES3外部相机采样shader错误（undefined variable OESTex669887sourceFeed），并非本次纹理生成或UI脚本错误，实际2D游戏照常渲染。未宣称该环境问题根治。

本轮不报新的目标平台FPS结论；移动调度代码保持，时序回归和原生实际移动均已检查。真实手机拇指触达、用户对欧美风格的最终接受仍待试玩；角色身体比首页插画规整的既有美术限制保留。材料fixture、桌面固定帧截图和自动断言不替代真人体验。工作流经验落实见EA-L008。

主理人完成最终差异/证据复核并汇总提交，唯一远程为Wx0823/EatAll，默认main；同步完成以本轮推送后远程SHA核对为准。APK/EXE在本机dist，不加入源码Git。
