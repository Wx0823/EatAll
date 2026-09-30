# v0.5.0 烘焙野餐 UI 生产皮肤

2026-09-30。用户要求欧美卡通、明显立体感和手柄十字方向键。本轮只重做界面材质，角色、场景与规则不变。使用 imagegen 内置工具生成可直接运行的透明生产 atlas，不把概念截图充当资产。

## 资产与来源

| 项目文件 | 原图 | 导入上限 |
|---|---|---|
| game/assets/ui-v5/baked-buttons-atlas.png | 1254 × 1254 RGBA | 512 |
| game/assets/ui-v5/dpad-keys-atlas.png | 2172 × 724 RGBA | 384 |

两张 PNG 都保留生成原始像素与 alpha，角点 alpha 实测为 0，启用 mipmaps。Godot 导入缩小用于移动端小控件，未重采样修改源文件。生成器绝对源文件分别为：

- C:/Users/Admin/.codex/generated_images/01a0ecc2-46be-7c32-bbb5-bcfa9c132bc2/exec-c29f84a4-9bed-472c-8bd7-0ffda67e0594.png
- C:/Users/Admin/.codex/generated_images/01a0ecc2-46be-7c32-bbb5-bcfa9c132bc2/exec-ed1c2d1c-acee-47d5-9acb-f18aa9a11264.png

源文件已原样复制进仓库资产目录，运行不依赖上述本机路径。

## 运行接口与切片

`UiSkin.button(fill, pressed=false, disabled=false)` 返回缓存 StyleBoxTexture。填色选择奶油、珊瑚、薄荷、葡萄四套生产素材，不在运行时逐像素生成渐变。`UiSkin.panel(kind='cream')` 支持 cream/mint/coral/plum；`controls` 别名选 mint。`UiSkin.dpad_key(pressed=false,disabled=false)` 使用专门方键素材。禁用态优先于按下态。

按钮 atlas 源像素裁切：列 x = [14,426,830]（正常/按下/禁用），行 y = [120,375,635,905]（奶油/珊瑚/薄荷/葡萄），每格 410 × 208。运行按实际导入分辨率换算 Rect2。九宫格固定边距使用导入像素 L22/R22/T16/B24。面板内容边距 L18/R18/T16/B20；按钮 L12/R12，正常 T8/B14，按下 T12/B10，使文字下压 4px。共享裁切顶部保留素材本身的下陷，不把三态重新按可见轮廓对齐。

方向键源裁切 x=[76,768,1442]、y=94、w=656、h=514；共享边界保留按下位置。方向键只用在固定比例方形，左右与顶部完整缩放 sprite（texture margin L0/R0/T0），底部固定 B23 保留厚侧壁。曾试九宫格角部固定，54px 小尺寸会把曲线挤成尖角，已在实际渲染中发现并改成顶部及左右完整缩放、底部固定侧壁。内容 L5/R5，正常 T5/B13，按下 T9/B9。非文本箭头由方向键代码绘制。

材质使用奶酪/糖霜大留白中心、金烤饼干侧壁、明亮上沿、暖色接触阴影；正常明显抬高，按下侧壁压短且有内凹边，禁用降低饱和度但保留材质。纹理与 StyleBoxTexture 按类型/状态缓存；没有每帧像素循环或额外绘图节点。

## 原始生成提示词

### 按钮 atlas（transparent_background=true）

PRODUCTION GAME UI SPRITE ATLAS, not a mockup. Exactly 12 EMPTY rounded-rectangle UI button tiles in an evenly spaced 3-COLUMN x 4-ROW grid on real alpha TRANSPARENT background. Square overall canvas. Every tile's footprint and anchors IDENTICAL, horizontal rounded rectangles about 1.8:1 with roomy transparent separation. Western premium cartoon mobile game 'baked picnic' style: delectable thick cookie base, very rounded generous corners, smooth glossy-but-hand-painted cheesecake/enamel face, warm baked golden/beige sidewalls, substantial visible thickness toward bottom, soft localized cast shadow, bright raised upper lip and warm occlusion below. NOT FLAT: strong physical extrusion and bevel clearly readable at small mobile sizes. All edges facing exactly front, no perspective skew or rotation, centered orthographic-ish front view. Perfectly suitable for NINE SLICE: straight horizontal/vertical middle edges, broad large almost-solid color blank center that stretches cleanly, subtle paint texture mainly on bevel and outer edge, no busy central texture, no holes, no decorative objects, no icons, NO LETTERS, no text, no arrows, no labels, no grid lines.
ROWS in order: row1 warm IVORY CREAM frosting face and honey biscuit edge; row2 rich CORAL ORANGE frosting face and warm red-brown biscuit edge; row3 fresh PALE MINT frosting face and sage/biscuit edge; row4 rich PLUM PURPLE frosting face and dark grape/biscuit edge. Colors match a coral noodle-monster picnic game, cozy painterly, playful, sophisticated Western animation character proportions.
COLUMNS in order: column1 NORMAL raised button with thick 3D sidewall clearly visible at bottom and upper rim highlight; column2 PRESSED same button physically depressed/down 12 pixels, much thinner bottom sidewall and darker inner rim, keep same outside transparent cell boundaries and same width, no diagonal angle; column3 DISABLED same button desaturated pastel muted grey-cream tint retaining tactile shape, no glow and reduced contrast. All three states still opaque faces, transparent outside only. Matching contours and registration between state columns. Every blank text area must be clean, large and completely unobstructed. Deliver only this 12-sprite atlas, original full alpha, polished real game assets.

### 方向键 atlas（transparent_background=true，引用第一张 atlas）

Create a matching production D-PAD KEY sprite atlas for the reference UI. Exactly THREE identical SQUARE rounded-square cream keys in ONE HORIZONTAL ROW on genuine transparent alpha background. Each occupies one equal square cell, same fixed outer size and anchor. These are standalone up/down/left/right game-controller keys, but do NOT draw any arrows or glyphs: center must be completely blank. Match the FIRST ROW ivory cream face / golden honey cookie sidewall of the reference. Western premium cartoon 3D-looking baked picnic style, smooth big cream enamel/cheesecake center, bright top rim, thick golden cookie foundation, warm dark bottom contact shadow, strong tactile bevel. Outer corners generously rounded yet unmistakably SQUARE, not circular. Center is large and visually clean. Left cell NORMAL: raised cream top and substantial thick bottom sidewall. Middle cell PRESSED: cream face physically sunken down, clear inner darker edge, greatly reduced bottom sidewall, same external footprint and style. Right cell DISABLED: grey cream, lower saturation and contrast, still tactile solid shape. Match every key scale and alignment; generous equal transparent margins, nothing cropped. Keep straight mid-edge spans suitable for nine-patch scaling, subtle baked texture at edge only. No perspective rotation, no writing, no labels, no letters, no icons, no grid lines, no extra objects. Output only this three-square-key atlas, wide 3:1 canvas, full original alpha.

## 实际验证

Godot 4.5.1 Compatibility 真图形 fixture：四色三态按钮 144×65、奶油面板 440×148、薄荷面板 440×220、方向键 72×72 与 54×54。已目视检查透明背景、厚度、下陷、禁用态和小尺寸圆角；最终 54px 图无尖角挤压、无切片接缝。日志 UI_SKIN_CAPTURE PASS，无解析/渲染错误。临时凭证 `.tools/ui5-fixture.png`、`.tools/ui5-54-fixture.log`（本机诊断，不作为游戏资产）。整屏布局/触控/Android 性能由集成验收另行记录；不能仅凭此 fixture 声称整屏验收完成。

## 小信息条适配

实屏 03-level12 / 08-short-screen 暴露 30px 细条使用普通大面板时边缘挤占文字；新增 UiSkin.panel('badge')，同薄荷正常态 source，独立复制并缓存，texture margins L12/R12/T6/B8，content L10/R10/T3/B5。用于 30–44px 高 HUD/提示条；普通 panel 的材质和边距不变。方向键代码核对实际 B23，前文已修正，未为了文档改动已通过审稿的键外观。

## v0.5.2 按钮文字位置修正

用户截图反馈文字视觉偏低。按钮整体含下方饼干侧壁，不能以整个外框几何中心作为文字中心。横按钮内容上下边距改为正常/禁用T1/B21、按下T5/B17，相对v0.5.1上移7个逻辑像素；方键改为正常/禁用T2/B16、按下T6/B12，上移3个逻辑像素。横键总留白22、方键18和按下文字4px下陷保持，因此不减少文字容纳空间，不移动触摸范围。SVG撤销图标随文字一起对齐。普通Panel和Badge不套用该修正。三语及英文短屏的实际整屏验收记录在production/qa/v0.5.2。
