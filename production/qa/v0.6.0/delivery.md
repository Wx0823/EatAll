# v0.6.0 登录与主界面交付

2026-10-01，基线de3b667。用户要求选关页移除提示、封面改为Google/游客登录、增加待机主界面；用户已确认暂没有Google项目，先交付代码与配置清单。

## 功能与边界

- 选关底部提示移除；登录页保留游戏插画、Logo，提供Google品牌按钮和游客入口，登录前可设置语言。
- 游客离线进入待机主界面；怪物呼吸、摇摆、点击轻跳；进入关卡、选关、设置、账户入口可用。
- 独立login.json仅记游客选择；Google身份与token不写入此文件。退出保留progress.json；Google只在服务端验证后进入，取消/失败/迟到回调不会放行。等待时显示可取消弹窗。
- Android包含已编译的PGS v2插件与官方SDK依赖，Google配置为空，不能完成真实登录；Windows本轮只有游客体验。服务端示例未部署，账号/云存档不在本轮交付范围。完整清单见[Google接入](../../../design/technical/google-login.md)。

## 验证

独立QA七套2332项/0失败：登录43、UI162、本地化1614、方向75、下落44、响应321、动作73。实际三语图形捕获40张/0失败，包括390×700短屏、等待与取消、账户、待机前后。Google异步回调测试使用明确的stub，不代表Google实授权。详见[独立报告](login-review.md)。后端10项mock测试通过，主理人复跑日志backend-tests.txt。

最终APK覆盖安装Android14/LDPlayer14实例1（720×1280）成功；原生日志明确EatAllGoogle插件初始化完成，无SCRIPT ERROR/FATAL EXCEPTION/triangulation/can_process。原生触摸验证Google未配置提示、游客进入大厅、选关提示已移除、进入实际L1、冷启动仍为游客、账户退出回登录。8张native图已保存。安装前后正式progress.json逐字比较相同，没有清除用户数据。

最终完整tools/build.ps1 -Target All退出0。Windows成品headless运行45帧退出0；APK签名v2有效，versionCode10/versionName0.6.0。APK内assets/android模板条目为0。

| 产物 | 字节数 | SHA256 |
|---|---:|---|
| dist/EatAll-0.6.0-android.apk | 271619539 | B4A65548870F0F2A742E37B4D3459017BDCA7DDD62E9FEAE1A1C44D7B91F9880 |
| dist/EatAll-0.6.0-windows.exe | 121734496 | 52927D91C1DADB1C43FE005FDAFF66BCC5A3B48C406C247B17CAF568C9AA0127 |

本机调试签名SHA-1：7E:AF:3B:F0:CD:3F:D7:1A:F3:BB:E2:EE:45:04:D6:72:A5:2E:83:7E。此指纹仅供本机调试OAuth登记；上架必须登记实际正式/Play App Signing指纹，不把调试签名作为正式发布身份。安装包、生成AAR、构建模板与凭据不提交源码仓库。

## 构建问题与修复

首次导出APK后Windows console wrapper持续等待，结束本任务Gradle daemon后构建立即继续；改为org.gradle.daemon=false后最后完整构建正常退出。Android模板未隔离曾被Godot扫描生成.import资源，并导致后续导出失败；新增android/.gdignore、导出排除并清除误生成sidecar后复跑成功。源码中固化这些边界，记录EA-L010。Google字体初稿CJK默认字重过细，已设500并重新截图。

遗留：模拟器已有FeedShaderGLES3兼容错误仍存在，二维界面正常；SDK XML版本警告尚在。没有真实Google账号联调、服务端部署、审核/上架或真机覆盖，不作这些通过结论。主理人复核源码、图像和最终包后提交EatAll/main并核实远程SHA。
