# 牌局档案 · iOS 原型生成提示词

生成方式：内置 image_gen 工具。

Use case: ui-mockup
Asset type: A single high-resolution presentation board of FOUR polished iPhone app screens for a Chinese card-deduction puzzle app. Generate an actual raster image, a shippable high-fidelity UI design, not a sketch.
Primary request: Design “牌局档案” (CARD TRACE), a premium offline game about reconstructing the chronology of a card game from clues. Show the complete product journey: archive home, deduction workspace, solved replay, archive collection.
Composition: landscape board approximately 3200×2000, four equally sized upright iPhone screen mockups in ONE horizontal row. Straight-on flat front views, very thin dark frames, subtly rounded corners, small Dynamic Island and accurate iOS status bar. Each phone must show its entire screen and bottom safe area. Large enough to read Chinese UI text. Wide, tidy gutters. No perspective tilt, no overlapping devices. The board background is warm light stone. A restrained header at upper left reads “牌局档案” with smaller “CARD TRACE / iOS 产品原型”. Small captions below phones respectively read “01 档案首页”, “02 推理桌面”, “03 牌局复盘”, “04 档案收藏”.
Design system: sophisticated contemporary editorial design inspired by a private paper archive. Warm ivory #F6F2E8 backgrounds, deep ink #252B27 text, burgundy #833D46 accents and primary buttons, very restrained muted sage for verified information. Delicate paper grain, fine hairline dividers, restrained rounded cards, occasional stamped case numbers, generous whitespace. Chinese Song-style serif only for big headings; crystal clear modern Chinese sans serif for body, controls, and navigation. Monospaced case numbers. Card faces are ivory, exceptionally legible, black spades and red hearts, small corner indices and a large central suit. Mature, calm, tactile and premium. No casino furniture, chips, gold gradients, neon, avatars, fantasy gaming art, dashboard analytics, or overwhelming decoration. Layout should feel implementable in native UIKit with comfortable touch targets.

PHONE 1 — archive home:
Status bar 9:41, a small four-suit archive emblem and large title “牌局档案”. Subheading “每张牌，都留下了线索”.
Hero case card containing a beautiful restrained monochrome ink illustration of a vintage train window, an envelope and two playing cards, with a small burgundy “档案 03” stamp. Text “遗失的记录”, smaller “列车档案 · 第 3 关”. Case progress “2 / 12 已完成”. Wide burgundy CTA “继续推理” and a right arrow.
Below: heading “探索档案”, two compact tasteful chapter rows with small archive thumbnails: “列车档案” and “茶馆来信”. The second has a small lock icon.
Bottom tab bar: “档案” selected, “收藏”, “设置”. Use simple thin native-style icons.

PHONE 2 — unsolved deduction workspace, the most important screen:
Back chevron top left, centered title “遗失的记录”, small “03” case badge right. Subtitle “6 张牌 · 2 轮”.
Compact rule pill “须跟花色 · 无王牌”.
Main board heading “出牌时间线”. Show TWO ROUND ROWS, with each row exactly THREE card slots.
Round 1 label “第一轮”, player labels left to right A, B, C. A has a face-up ♠5, B has a dashed empty slot with ?, C has a face-up ♥3. Small evidence tag “B 获胜”.
Round 2 label “第二轮”, player labels left to right B, C, A, because first round winner B leads the second round. B has a face-up ♥7, C has a dashed empty ? slot, A has a dashed empty ? slot.
Below, “待归位的牌” shows exactly THREE distinct draggable cards: ♠2, ♠9, ♥10. Cards already placed above do NOT also appear in this pool.
A pinned evidence panel “线索” contains legible lines “第一轮 B 获胜” and “第二轮领出 ♥7”. A small secondary text link “查看规则”.
Bottom controls: small undo icon with “撤销”, light “提示” button, and a dominant burgundy “验证推理” button. No global tab bar in the puzzle screen. Show all controls without crowding.

PHONE 3 — solved reconstruction replay:
Back chevron, title “牌局复盘”. Elegant small seal/checkmark and large serif “真相已还原”, subheading “遗失的记录”.
A clean vertical replay timeline showing the exact solved card sequence, TWO ROUND ROWS of exactly THREE cards with clear player labels:
First round: A ♠5 → B ♠9 → C ♥3. Caption “第一轮 · B 获胜”.
Second round: B ♥7 → C ♥10 → A ♠2. Caption “第二轮 · C 获胜”.
The suits and ranks and order MUST match exactly. No other cards.
Below a play/pause control and a delicate progress scrubber with six tick marks.
An explanation note heading “关键推理”, text “C 没有跟黑桃，因此 ♠2 属于 A。” Visually link its burgundy accent to the ♠2 card.
Bottom primary button “下一份档案”, secondary text “再看一次”. No global tab bar.

PHONE 4 — archive collection, after solving the pictured puzzle:
Status bar. Title “我的档案”, understated subtitle “收藏每一次恍然大悟”.
A compact typographic statistic “03” with label “已解档案”, not a noisy dashboard.
Three stacked archival folder cards with subtle line illustrations, case numbers and fine paper edges. Titles “初识花色”, “谁先出牌”, “遗失的记录”. Each has a modest “已还原” mark. The third shows a miniature timeline motif and “查看复盘”.
Below a slim bordered personal note card with small pen icon, heading “推理笔记”, one line “没有跟出的花色，也是一条线索。”
Bottom tab bar matching home: “档案”, “收藏” selected, “设置”.

Text accuracy: render Chinese copy precisely and legibly. All playing-card indices and suits must be correct. Keep the four screens visually consistent. Favor clear hierarchy and fewer exact words over tiny dense illegible copy. The result is a beautiful cohesive product prototype board, with real information architecture and functional UI, not a promotional poster. No watermarks or extra explanatory annotations.
