# 视觉升级素材 · v2

## 2026-09-30 全英文展示

- 应用显示名改为 Card Trace，内置界面、章节故事、40 关线索/证词/分层提示/完整复盘、弹窗、错误反馈及辅助功能描述统一为英文。Bundle ID、签名与发布配置未改。
- 英文标题使用系统衬线字体，并调整首页/收藏计数区域的宽度；大字模式下撤销按钮用图标显示，辅助功能名称仍为 Undo。
- 所有关卡 ID、内容修订号、牌组、规则约束、提示结论、解答和证词真值保持原样；已有存档及玩家笔记保留。玩家自行输入的内容不自动翻译。
- `tools/english-level-copy.json` 保存审核后的英文内容，生成工具会应用它并核对关卡结构签名，避免重新生成时恢复中文或将旧译文套入新谜题。`tools/validate-english.py` 检查内置内容无中文及结构完整性。
- Debug / Release 模拟器构建通过；23,821 项规则/求解/复盘检查、162 项会话/存档检查、1,039 项关卡内容检查通过，40 关仍全部唯一解。iPhone 17 Pro 与 SE / iOS 26.5 已检查英文正常及大字界面，确认提示与未完成反馈为英文；未新增 iOS 14 真机验证。
- 英文截图：[首页](../../output/validation/english/home.png)、[收藏](../../output/validation/english/collection.png)、[复盘](../../output/validation/english/replay.png)、[小屏大字](../../output/validation/english/se-large-text.png)。

## 2026-09-30 产品界面打磨

- 首页图片随当前章节切换，清理反复出现的免费说明与手工空格箭头；按钮使用原生图标、按压反馈和禁用态。
- 章节页改为单张主题图与编号目录，明确区分未开始、继续推理和已还原，避免重复缩略图占用阅读空间。
- 设置页按推理体验与档案手册分组；玩法指南和保存说明有真实可访问页面，版本号读取应用元数据。
- 收藏空状态根据是否已有草稿提供对应入口；大字模式的标题、图片和操作区按需纵向排布。
- 成功复盘首次打开即显示完整牌局；回放使用紧凑的图标控制和进度条，修正拖动进度时重建控件的问题。补齐全部完成后的首页文案与末关返回入口。
- 使用现有图片、字体和系统框架，无新增依赖；原型的固定通栏底部导航保持不变。
- 修复导航转场自动偏移裁切首页页头的问题，页面恢复用户实际滚动位置；已验证进入章节并返回首页。
- 验证：Debug / Release 模拟器构建成功；iPhone 17 Pro / iOS 26.5 实测章节进入、第二关摆牌与撤销、验证通关、复盘播放和单步操作、设置手册页面；iPhone SE / iOS 26.5 实测大字设置、触感开关、牌桌和收藏空状态。运行日志未发现布局约束冲突或未捕获异常。全卷完成文案已实现，未在本轮逐关通完 40 关；本次不包含 iOS 14 真机或 App Store 发布验收。
- 截图：[首页](../../output/validation/product-polish/home.png)、[目录](../../output/validation/product-polish/chapter.png)、[设置](../../output/validation/product-polish/settings.png)、[复盘](../../output/validation/product-polish/replay.png)、[收藏](../../output/validation/product-polish/collection.png)、[小屏大字牌桌](../../output/validation/product-polish/se-large-text-game.png)、[小屏收藏空状态](../../output/validation/product-polish/se-empty-collection.png)。

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
