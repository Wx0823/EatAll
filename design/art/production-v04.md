# v0.4：真实张嘴与吞糖动作

## 素材与来源

- `game/assets/art-v4/mouth-atlas.png`：内置 ImageGen 生成，参考本项目 `game/assets/art-v2/gameplay-atlas.png` 左上角色。2026-09-30 制作；2172×724，三列各724×724，保留原始透明 alpha。未用 Python、图像编辑脚本修改像素。
- 原始生成文件：`C:/Users/Admin/.codex/generated_images/01a0ecc2-46be-7c32-bbb5-bcfa9c132bc2/exec-cf6fdfc1-90ae-4e7c-8371-399a8a3a3526.png`；项目副本独立保存在仓库，不依赖本机原始路径运行。
- 三格依次为闭嘴、半开、大张嘴。同一公共裁切框 `(70,16,638,683)`，每格仅加724的横向偏移；不分别归一化边界，避免眼睛/角随口型跳动。实际 alpha>40 测得三格主体范围相差不超过6px。导入开启 mipmap。
- 原有惊讶脸仍用于下落、受阻和失败，不用它冒充进食口型。

## 原始生成提示词

```text
Create a production animation sprite atlas, transparent PNG, three equal columns in ONE horizontal row. Reference image's TOP LEFT coral orange friendly noodle monster HEAD is the ONLY identity reference. Discard all reference objects. Exactly three large copies of that SAME isolated head facing slightly RIGHT, each centered at precisely the same anchor in its equal cell, with identical scale, outer skull shape, eyes, brows, plum horns, creamy chin, coral watercolor paint texture and dark plum thin outline. Do not redesign character. Each head has two big expressive eyes, plum horns, coral orange freckles. Frame 1 LEFT: completely CLOSED mouth, a single curved cheeky smile line, no visible mouth cavity and no tongue outside. Frame 2 MIDDLE: HALF OPEN mouth, jaw lowered moderately, dark plum mouth cavity, two small ivory teeth and pink tongue INSIDE mouth. Frame 3 RIGHT: mouth VERY WIDE OPEN ready to swallow a sugar cube, hinged lower jaw visibly lowered, large dark plum mouth cavity and pink tongue at bottom inside, playful eager expression. The jaw changes visibly while skull/eyes/horns stay exactly registered across frames. Each mouth opens toward lower-right of face. NO FOOD, no words, no grid lines, no shadows cast onto background. Generous fully transparent padding around each head. Three equal square cells, total canvas wide 3:1. Clean genuine alpha transparency. Render beautiful western storybook game sprite brushwork matching original, high readability at small size. This is a mouth animation atlas, not three different emotions.
```

## 运行接口与时间轴

`anticipate_food(direction, food_cell = Vector2.INF)` 在移动开始预张嘴；100ms由当前口型张大，等待 `react("eat")` 接触事件。传入真实食物格，避免副本凭空从嘴前出现。main负责接触时移除真实food，renderer将其副本在95ms内从真实格中心缩吸至嘴锚点。随后闭嘴、短咀嚼，恢复默认闭嘴。`mouth_animation`公开为idle/opening/holding/swallow/chew，`mouth_openness`为0..1。

实际嘴形通过公共锚点三帧插值变化，原整头挤压式chew已移除，保留很轻的次级点头。头部方向取渲染中头与颈的插值向量；嘴锚点与精灵共享旋转/镜像变换。clear_reactions清除进食副本、口型、朝向反应。关闭process冻结时间，不锁输入。

## 针对性实际检查

使用真实Godot图形后端运行独立夹具 `.tools/mouth-check.gd`，固定60步捕获闭嘴、张开、全开、接触、缩吸、闭嘴及向上进食帧，实际看图调整嘴锚点，避免缩吸终点落在鼻子上。状态及clear断言通过，完整日志无ERROR/WARNING。截图位于本机 `.tools/mouth/`；这些是独立美术夹具，不冒充玩家操作。最终整合后的原生输入截图/录像由QA另验。

## 绘制成本测量与优化边界

同一桌面Godot4.5.1 / OpenGL NVIDIA RTX5060Ti，14节L形身体，440×600绘图区，每组先略去20次，再统计201次真实 `_draw` CPU耗时（最终版本因首次烘焙后重绘多2次，共203次）。禁用vsync以采样；测量不包括GPU完成时间，不能当Android、真机或整帧FPS。

| 样本 | 旧版mean / p95 | 第一轮缓存候选mean / p95 |
| --- | --- | --- |
| 身体静止、头部运动 | 5.97 / 7.21 ms | 4.00 / 4.73 ms |
| 每帧平移身体，强制更新几何 | 5.51 / 6.16 ms | 4.96 / 5.70 ms |

该第一轮桌面优化不能作为最终交付：主理人实际Android探针发现4节身体绘制仍约95–99ms，原生多层polyline候选仍约87.7–90.9ms，加入斑点stamp后仍约75.18ms。不能因桌面有小幅收益就忽略用户设备上的卡顿。

最终实现改为一张带横截面顶点颜色的连续身体mesh，由GPU插值珊瑚、奶油及软边；仅真实转角采样，直线保留端点，尾端额外4个渐细截面与柔尖。原有12斑点/节一次烘焙为透明stamp，每节一次texture调用；GPU反预乘后首次转成共享ImageTexture，后续进入关卡复用，不重新烘焙。地形/网格/出口/危险放到独立静态Canvas；仅状态/布局变化时重绘。网格改为批量quad mesh和共享径向点纹理，出口光晕、圆颗粒复用纹理，避免Android上的慢AA圆API。保留角色素材、斑点、珊瑚/奶油材质；未改碰撞、状态或地图。

最终桌面相同移动体夹具203次：mean **0.116ms**、p95 **0.155ms**。主理人已测上一版单mesh候选Android动态混合窗口，board draw均值**2.76–3.27ms**，process窗口**53.5–58.5Hz**；仍有首次烘焙、静态网格重绘尖峰，不能称全程恒定60FPS。最后的批量dot/跨关共享烘焙针对这些尖峰，最终APK平台数值由交付报告记录。

独立真实图形夹具通过口型、方向、清理检查；第二个Board实际检查已证实不创建烘焙Subviewport、复用16个stamp。首进关仍有一次烘焙与读回成本，不伪称完全没有首帧开销。

`draw_calls_total`、`draw_time_us`提供动态绘制CPU统计；`draw_sections_us`包含static_submit/body_geometry/body_submit/body_spots/body_head/body/food_hazards/particles；`static_draw_calls_total`、`static_draw_time_us`及`static_draw_sections_us`区分静态grid/terrain/exit/hazards。实际Android探针应持续读取这些字段，不把固定步长录像当性能证据。
