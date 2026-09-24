# 视觉升级素材 · v2

使用内置 image_gen 工具生成，2026-09-24。原型仅作风格参考；所有素材均为独立插画，不包含 UI 文字或交互牌面。原图复制至工程 Asset Catalog，各图片为 V2 新资源，原资产保留。

## TrainEngravingV2

Use case: illustration-story. Asset type: finished in-app editorial hero illustration, landscape 4:3. Create a richly detailed antique copperplate engraving for a Chinese card deduction game. Interior of a luxurious 1930s railway compartment: dark velvet curtain left, large window looking over an alpine lake, distant mountains and pine forest; in foreground a polished wood table holding three slightly fanned vintage playing cards with spade and heart motifs and a sealed ivory envelope with a dark burgundy wax seal. Intimate mysterious literary atmosphere, intricate cross-hatching, finely etched ink, tactile warm ivory paper. Almost monochrome charcoal/sepia with only a tiny muted oxblood accent in the wax. Strong elegant composition, full bleed artwork, deep fine detail, no flat geometric illustration, no cartoon. Match the detailed vintage engraving style of the train interior artwork in the supplied reference, but create a standalone illustration only, NOT a screen or mockup. No text, letters, numbers, titles, UI, border frame, phones, watermark, typography. Decorative card motifs need not encode gameplay.

## cards

Use case: illustration-story. Finished decorative asset for vintage literary card puzzle iOS app. Square composition. A beautifully engraved still life of three fanned antique playing cards with ornate spade heart club motifs, a worn closed archive folder beneath them, and a small fountain pen, resting on warm ivory paper. Delicate intricate 19th century copperplate etching, charcoal ink cross-hatching, monochrome warm sepia, tiny muted burgundy detail only. Subjects centered with generous pale paper breathing room around edges, fine detailed tactile objects, lightly faded vignette into the same warm ivory background #F6F2E8. No readable text, numbers, writing, UI, frame, phone, watermark. Not flat vector, not cartoon.

## tea

Use case: illustration-story. Finished decorative asset for vintage literary card puzzle iOS app. Square composition. Exquisite old copper teapot with curved handle, a porcelain teacup on saucer, two playing cards tucked beneath a notebook on a wooden tea table. A soft hint of old Chinese teahouse window lattice in distance. Finely detailed antique copperplate engraving, charcoal ink cross-hatching on warm ivory paper #F6F2E8, mostly monochrome sepia. Centered objects with light fading edges and generous blank ivory margins for use in chapter thumbnail and editorial illustration. Quiet contemplative mystery. No text, numbers, writing, UI, phone, watermark. Not flat vector, not cartoon.

## letters

Use case: illustration-story. Finished decorative asset for vintage literary card puzzle iOS app. Square composition. An evocative archive still life: stack of cream envelopes tied with thin twine, open worn document folder, one envelope sealed with an oxblood wax seal, small brass key, faint harbor lighthouse silhouette in distance. Exceptionally intricate antique copperplate etching with charcoal cross-hatching on warm ivory paper #F6F2E8, monochrome sepia except tiny burgundy wax seal. Centered still life fading into pale paper at edges, ample breathing room, refined quiet mystery. No text, handwriting, numbers, UI, border, phone, watermark. Not flat vector, not cartoon.

## paper

Use case: stylized-concept. Asset type: seamless subtle background texture for a reading and puzzle app. Flat evenly lit warm ivory archival cotton paper, dominant color #F6F2E8, very fine visible organic fibers and tiny grain, extremely low contrast, elegant clean antique stationery. Full bleed square, uniform material across entire canvas. No stains, folds, torn edges, objects, shadows, vignette, text, drawings, border or watermark. Must remain quiet and light so dark small text is perfectly legible over it.


## 素材与字体接入

- 五张生成图片存于 `Drirdarpoul/Assets.xcassets/` 对应 `TrainEngravingV2`、`CardsEngravingV2`、`TeaEngravingV2`、`LettersEngravingV2`、`PaperTextureV2` imageset。
- 标题使用本地思源宋体；系统字体在当前模拟器不包含中文宋体，因此增加字体资源，不增加代码依赖或运行时网络请求。
- 字体来源：[Adobe Source Han Serif 官方项目](https://github.com/adobe-fonts/source-han-serif)，使用官方发布的 `SourceHanSerifSC-SemiBold.otf`，未改字体内容。SIL OFL 1.1 许可证保存在 `Drirdarpoul/Fonts/SourceHanSerif-LICENSE.txt` 并随应用打包。
- 文字、牌面数值、花色、按钮和章节状态仍全部由 UIKit 实时呈现。装饰图片不承载游戏事实。

## 页面与验证

- 底部导航改为原型的固定通栏纸色背景、顶部细分隔线、上图标下文字和酒红选中态。使用 UIKit 容器与独立导航栈，避免 iOS 26 系统悬浮胶囊外观；推理和复盘按页面要求隐藏。Debug 构建成功，iPhone 17 Pro / iOS 26.5 已验证三个入口切换、推理页隐藏及返回恢复。[底栏截图](../../output/validation/navigation-home.png)。

- 首页使用列车版画大图、章节图文行；章节与收藏页使用对应主题图片。
- 全局加入轻纸纹、宋体标题、酒红按钮渐变与细边阴影；牌面加入角标、中心花色、固定证据标记，复盘页增加封蜡装饰。
- 小屏大字模式中首页标题区和摘要改为纵向排列，牌桌保持两列卡牌。
- 最终 Debug、Release 的 generic iOS Simulator 构建均成功。
- iPhone 17 Pro / iOS 26.5 模拟器检查首页、牌桌、成功复盘和收藏；完成首关摆牌、验证、逐手复盘流程。iPhone SE / iOS 26.5 检查大字首页和牌桌。未新增 iOS 14 真机验证。
- 实际运行截图：[首页](../../output/validation/visual-v2/home.png)、[牌桌](../../output/validation/visual-v2/game.png)、[复盘](../../output/validation/visual-v2/replay.png)、[收藏](../../output/validation/visual-v2/collection.png)、[小屏大字](../../output/validation/visual-v2/se-large-text.png)。
