# v0.2 美术返工与资产记录

2026-09-29，用户指出v0.1实机与批准的效果图差距过大。此次仍沿用烘焙野餐方向，不另换主题。上一版验收只关注可读性/裁切，忽略角色设计、材质和场景层次，不能把那个结论作为风格达标证据。

## 实际资源与使用

| 文件（game/assets/art-v2） | 用途 |
|---|---|
| meadow.png | 9:16绘制背景：树冠、远景草地/围栏、近景叶丛/雏菊/野餐布；中心留玩法空间 |
| home-monster.png | 首页完整角色透明插画，直接在运行时TextureRect中合成 |
| gameplay-atlas.png | 1536×1024，3×2透明精灵表：笑脸、华夫、糖块、闭篮、开篮、尖刺 |
| head-surprised.png | 失败状态惊讶脸，保持角色身份与画风 |

全部由本轮内置 **ImageGen** 根据已批准concept v2生成；没有调用CLI/API fallback，没有从参考游戏提取资源。图集经过一次背景提取编辑；PNG真实alpha已检查，Godot中无背景色块。原图工具输出保留在Codex生成目录，最终被游戏引用的文件全部复制进仓库。已有concept v1/v2仍只是提案图；本轮截图均由Godot或最终安装包运行产生。

图集素材只负责表达，地形仍占整数格；糖块/篮子/尖刺不改变规则与碰撞。角色连续身体使用带珊瑚渐层、奶油腹纹和斑点的程序曲线连接头部，支持任意合法折返；不是拿整张首页角色图移动冒充游戏。它仍不具有首页插画的全部手绘细节，独立审图如实记录差异。

所有图像导入开启mipmap，运行精灵线性采样；alpha主体框与格底锚点明确。界面九宫格材质与轮盘高光由原生代码产生。许可/来源说明已同步game/assets/LICENSES.txt。

## 生成提示词归档

以下为本轮使用的提示词组（英文），参考输入为concept v2；图集编辑参考第一次图集；首页参考concept v2及最终图集；惊讶脸参考最终图集。无额外API参数，内置工具透明参数对后三类设为true，背景为false。

### meadow.png

Use case: stylized-concept. Production game background asset, NOT a mockup. Use the attached Eat All art direction ONLY as visual style reference. Generate a single portrait 9:16 full-bleed hand-painted western cartoon picnic meadow background for this 2D puzzle game. Match the rich soft storybook illustration of the middle phone screen: mint blue sky and fluffy ivory clouds in top 20%, softly layered rolling green meadow and distant trees/fence, warm honey daylight, painterly textured foliage framing top left/right corners and bottom corners, tiny daisies and clover at edges, a modest peach-and-cream gingham picnic cloth entering lower right corner. The CENTRAL 70% WIDTH from y=25% to y=80% must be calm softly textured light sage green meadow with NO objects so a moving worm and grid platforms read clearly. Peripheral detailed foreground leaves, gentle paper grain, soft atmospheric depth. Bottom 20% can have foliage only at corners so UI can overlay. Beautiful polished mobile game production illustration, nuanced organic brushwork and warm-cool color variation, no harsh outlines. No worm, no character, no food, no basket, no platforms, no grid, no lettering, no UI, no phone border, no logo, no signboard. This is the actual clean background texture to import into Godot, not another design presentation.

### gameplay-atlas.png 初次生成

Use case: stylized-concept. Create ONE production sprite atlas PNG with true transparent alpha for the Eat All mobile game. Match the attached art direction precisely: richly hand-painted western storybook cartoon, coral orange, ivory, biscuit gold, plum; soft painted highlights, dimensional shading, clean plum contour, charming expressions. Landscape canvas 1536x1024, exactly 3 columns x 2 rows, 6 equal square 512x512 cells, each sprite centered within its own cell with 50px clear transparent padding all around, nothing crossing cells. No text, no labels, no background, no separators, no checkerboard, no phone, no montage title. Cell top-left: ONLY the head of the reference coral noodle monster, large soft plump rounded face, two organic plum eyebrow horns, two BIG side-by-side ivory eyes with black pupils looking to the right, cheek spots, wide happy open smile showing little teeth and tongue on lower right; three-quarter right-facing, upright face with eyes horizontally side by side, full head fits square, no neck/body. Top-middle: one front-facing square golden baked waffle platform tile, perfectly square usable collision silhouette, rounded scalloped biscuit rim, dimensional bevel edges, diagonal diamond lattice waffles, crumb texture, mostly frontal orthographic view, no perspective distortion of rectangle. Top-right: one puffy ivory sugar cube with subtle peach shadows, visible front/right/top faces, sugar crystal texture, no face. Bottom-left: closed woven wicker picnic basket with rounded rectangular lid, strong sculpted weave texture, tan golden color, plum contour, gold padlock on front, compact square silhouette. Bottom-middle: matching OPEN wicker picnic basket, raised lid, pink cream gingham cloth visible inside, same scale and styling as closed, no lock. Bottom-right: a compact jagged cluster of dark plum thorn crystals with mauve edge highlights, clear dangerous silhouette, fits one square. All six polished game sprites, lighting upper-left consistent; avoid minimalist flat vector geometry. Precisely six sprites in regular grid, plenty of transparent gutter.

### 图集背景提取编辑

Use case: background-extraction. Edit the supplied sprite atlas: REMOVE the entire brown / purple / glowing background and all halo glows. Replace all background and all space between the six objects with genuinely transparent pixels (alpha 0). This MUST be a clean isolated game sprite sheet with real transparency, not a colored backdrop. Preserve exactly the six object shapes and original 3 columns by 2 rows arrangement and the 1536x1024 canvas: monster head, square waffle tile, sugar cube, closed basket, open basket, thorn cluster. Preserve their detailed artwork, facial expression, painted texture, colors, sizes, positions. Only remove background cleanly along their contours. No checkerboard baked into RGB, no new shadows or glow, no surrounding colored rectangles. All gaps and all four corners fully alpha-transparent.

### home-monster.png

Use case: stylized-concept. A production transparent-background character illustration for Eat All homepage. Reference 1 is approved art direction; reference 2 shows exact face and painted material to match. Draw ONE complete adorable coral noodle monster in a playful loose reclining S curve, broad low composition, roughly 4:3 image, full body fits with generous transparent margin. The large raised head on left is looking slightly right toward a hovering tiny sugar cube near nose. Plump coral orange body sweeps down and across to a naturally tapered soft curled tail on the right. Continuous beautiful creamy ivory underside from chin along belly into tail, organic coral freckles, painted buttery highlights, subtle dimensional peach shadows, fine plum contour. Face is expressive: large side-by-side ivory eyes, two organic plum eyebrow horns, joyful toothy open smile and pink tongue as in references. No limbs. Warm hand-painted western storybook cartoon finish, rich brush texture, charming premium casual-game mascot. The worm body must be very smooth and elastic, not segmented discs, not a snake with stiff pipe elbows. Include a few tiny golden crumb sparkles close to character, no platform. Truly alpha-transparent background outside silhouette; no colored background, no glow, no text, no UI, no logo, no frame, no checkerboard pattern. This sprite is to be composited over our actual meadow background in engine, not another concept board.

### head-surprised.png

Use case: identity-preserve. Production sprite, one isolated head only on real alpha transparency, no sheet. Take the exact coral orange monster head in the TOP LEFT of the reference atlas and change only its expression to surprised after a playful mistake: two big ivory eyes looking ahead slightly right, pupils small and widened, plum eyebrow horns raised, tiny rounded O mouth instead of smile/tongue, cheeks soft. Preserve exact original three-quarter right-facing head shape, coral brush texture, light direction, plum contour, cream chin, cheek spots, and proportions. NO body, NO neck, NO other atlas items. Center the complete head at generous size on square canvas, 12% transparent margins. Warm hand-painted western storybook cartoon finish as original. No tears, injuries or distress, just comic surprise. No colored background, no glow, no text, all pixels outside silhouette fully transparent. This is a real alternate facial sprite for our game, not a concept layout.
