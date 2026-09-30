# Google 登录接入与配置清单（v0.6.0）

用户于 2026-10-01 确认尚无 Google Cloud / Firebase 配置，要求先完成界面和接入代码，再列出需配置的内容。此版本不能宣称 Google 真账号联调成功；游客无需联网即可使用，原有进度不删除。

## 已选流程与身份边界

Android 游戏采用官方 Google Play Games Services v2（固定 `play-services-games-v2:22.1.0`），Godot 4.5.1 v2 Android 插件。PGS 的平台 Player ID 与游戏账号分开：不能把客户端 Player ID、邮箱或未经验证的 JWT 内容当成账号。

点击 Google 按钮后，插件检查平台认证，必要时调用 `GamesSignInClient.signIn()`；然后 `requestServerSideAccess(webClientId, false, [AuthScope.OPEN_ID])`。只额外请求 OpenID，不请求姓名、邮箱或离线 refresh token。PGS 自带平台范围由 Google SDK 管理。用户拒绝 OpenID 即返回 `consent_required`，不能用平台登录成功代替游戏登录。

一次性 code 只通过固定 HTTPS 地址交给自有服务器。服务器以 Web client secret 换 token，再用官方 `google-auth` 验证签名、发行方、受众、有效期和 `sub`，返回短期游戏会话。`azp` 如为 Android client 必须在服务器允许列表中。客户端仅在后台响应通过检查后发出成功信号；token 仅在原生内存保留，日志、JSON 存档及 GDScript 都不接触 Google token/code。

未配置时不初始化 PGS SDK；`is_configured()` 为 false。退出仅清除游戏会话并尽力使服务端会话失效；不伪称退出用户的整个 Google/Play Games 账号，也不会撤销用户在系统中的 Google 登录。无网络时本地退出仍可完成，示例服务器会话最长 1 小时过期。

## 项目方需要准备

| 配置 | 获取/填写位置 | 是否可放客户端 |
|---|---|---|
| Google Cloud 项目 ID 与 Play Games Services 游戏项目 ID | Cloud 项目关联 Play Console 游戏；`games_app_id` 填 PGS 数字项目 ID | 项目 ID 可公开 |
| Android OAuth client ID | 同一 Cloud 项目；包名 `org.wx0823.eatall`，正确签名 SHA-1；测试、正式、Play App Signing 证书分别登记 | 可公开；服务器白名单也需要 |
| Web OAuth client ID | 在 PGS 配置中作为 Game server credential 关联；填 `web_client_id` | 可公开 |
| Web OAuth client secret | 仅服务器环境 `GOOGLE_WEB_CLIENT_SECRET` | **禁止**写入 APK/Godot/仓库 |
| HTTPS 后端地址 | 填 `auth_endpoint`，例如自有域名 `/auth/google`；不能用 HTTP、含凭据地址或重定向中转 | 可公开 |
| OAuth 品牌/同意屏幕 | 正式应用名、支持邮箱、域名、隐私政策、服务条款、测试用户及发布/审核状态 | 项目方控制台配置 |
| PGS 测试/发布状态 | 添加测试账号，确认 Android 与 Game server credentials 同属已关联项目 | 控制台配置 |

Firebase 非必需；本方案使用 Cloud + Play Games Services + 自有验证端点，不要求额外建立 Firebase 用户库。Google 登录本身不会自动带来云存档。进度上传、游客合并、多账号存档冲突、账户删除/解绑与撤销 Google 授权，均需接入正式账号服务后设计和验收；本轮不伪造这些功能。

## 本地接入步骤

1. 复制 `android-auth/google.properties.example` 为同目录 `google.properties`，填写三个公开字段。该文件已忽略，不提交；不要加入 secret。
2. 服务器环境配置 `GOOGLE_WEB_CLIENT_ID`、`GOOGLE_WEB_CLIENT_SECRET`、`GOOGLE_ANDROID_CLIENT_IDS`（逗号分隔的本项目 Android OAuth IDs）。第三项用于校验混合 Android/Web token 的授权请求方 `azp`。不要将不属于本项目的 client ID 加入列表。
3. 构建：JDK 17、Android SDK 35、Gradle 8.11.1；运行 `powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_google_plugin.ps1`，或以 `-Gradle` 指定 Gradle 路径。脚本默认 300 秒超时，不自动下载工具，不关闭 TLS 校验。
4. AAR 输出 `game/addons/eatall_google/bin/EatAllGoogle.aar`（生成文件不提交）。启用 Godot `addons/eatall_google/plugin.cfg`，设置 `eatall_google/enabled=true`；Android 导出需开启 Gradle build、安装匹配 4.5.1 的 Android build template。清洁检出应从 Godot 编辑器安装模板，不能用 APK 导出模板代替。
5. 使用自己登记过 SHA-1 的包安装到具备 Google Play services 的 Android 设备。发布前另登记 Play App Signing 的签名证书；上传证书与应用签名证书不是同一概念。发布包不能沿用本地调试签名。
6. Google 真实账号依次验证：首次授权、重复登录、取消、拒绝 OpenID、无 Google Play services、网络中断、服务端拒绝、超时后切游客、退出/切账号；确认未成功验证不进入 Google 会话，也不覆盖游客存档。

Godot 桥接：singleton `EatAllGoogle`；方法 `is_configured() -> bool`、`sign_in()`、`sign_out()`；信号 `sign_in_succeeded(subject: String)`、`sign_in_failed(code: String)`。错误码包括 `not_configured`、`unavailable`、`services_unavailable`、`consent_required`、`cancelled`、`network`、`timeout`、`invalid_response`、`verification_failed`。SDK 操作主线程串行，HTTP 独立线程；90 秒总等待上限，HTTP 连接 10 秒/读取 15 秒。退出使迟到回调失效。

Windows 本轮提供游客体验，不能复用 Android OAuth 客户端冒充桌面 Google 登录。未来若接 Windows，需单独 Desktop OAuth client 与外部浏览器/受保护回调流程。

## 后端契约与示例

`android-auth/backend/server.py` 是可执行的最小身份交换示例，依赖在同目录 `requirements.txt`。本地仅监听 `127.0.0.1:8080`，正式部署必须放在可信 HTTPS 反向代理后并配置限流、请求大小限制、并发/超时；不要开启 Flask debug，也不要记录请求体、Authorization 或 Google token 响应。

`POST /auth/google` 请求 `{ "auth_code": "一次性code", "request_id": "UUID" }`。服务器成功返回 `{ "subject": "已验证Google sub", "session_token": "随机短期会话", "expires_in": 3600, "request_id": "原UUID" }`；失败返回 4xx/5xx 及通用错误，不透传 Google 敏感信息。`POST /auth/google/logout` 使用 `Authorization: Bearer <session_token>` 使游戏会话失效。

示例仅保留会话 token 的 SHA-256 与 subject/到期时间，不保留 Google token。**内存会话表只适合开发验证**，重启即清空；多进程、持久化账号、安全审计、撤销/删号和云进度应由正式后端实现。HTTPS验证结果是游戏账号建立的信任边界；不得把这个示例描述成已部署的生产账号系统。

## 核验记录与已知限制

- 2026-10-01 读取官方 Android 游戏/PGS/OIDC/Godot 插件文档，核对 SDK 22.1.0 中 `AuthResponse` / `GamesSignInClient` 实际字节码 API。
- 从官方发布下载 Gradle 8.11.1 并核验官方 SHA-256；从官方 Godot 4.5.1 模板归档提取 Android source template。本机下载和缓存均在忽略目录。
- 首次 AGP 拒绝中文目录；加入 `android.overridePathCheck=true`。随后 AndroidX compileOnly/runtime 一致性解析冲突；将 fragment 与 Godot 4.5.1 所用 1.8.6 对齐为实现依赖。保留针对实际错误的修复，不改引擎或降低 SDK 验证。
- 后端 10 项测试覆盖失败拒绝、受众校验调用、OpenID 缺失、会话生成/退出、输入限制、错误脱敏、Android/Web azp 白名单与证书获取超时；Google 网络端使用 mock，**不代表真实 OAuth 联调**。
- 原生 `assembleRelease` 实际成功，Godot v2 AAR 输出 SHA-256 `E4A1A1610B3581209935B4F1080496E1131130B0712FD839CABAFD0A67A4185C`。构建脚本曾因 Windows PowerShell 等待进程后返回空 ExitCode 误报失败，改为等待前缓存进程 Handle，再执行脚本退出码为 0、复制 AAR 成功。构建仍有 SDK XML 版本警告；不能把构建成功描述为无警告。
- 最终 APK 插件加载及未配置分支以本版交付记录为准。尚无 OAuth 配置、后端域名和测试账号；真实账号登录、Play Console 审核、正式商店发布未验证。

## 官方依据（核对日期 2026-10-01）

- [Sign in with Google best practices — Android games](https://developers.google.com/identity/siwg/best-practices#android-games)
- [PGS platform / in-game authentication 分离](https://developer.android.com/games/pgs/platform-authentication)
- [PGS Android 平台认证与禁止启动时强制建档](https://developer.android.com/games/pgs/android/android-signin)
- [PGS server-side code 与额外 OpenID 范围](https://developer.android.com/games/pgs/android/server-access)
- [GamesSignInClient API](https://developers.google.com/android/reference/com/google/android/gms/games/GamesSignInClient)
- [Google OpenID Connect token claims / azp](https://developers.google.com/identity/openid-connect/openid-connect)
- [Godot 4.5 Android v2 插件](https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_plugin.html)
