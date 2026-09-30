#!/usr/bin/env python3
"""Deterministic author tool. Enumerates legal records, selects public evidence,
and emits forty uniquely constrained puzzles. Runtime never runs this script.
Final release validation MUST also use the shared Swift engine.
"""
import itertools
import json
import random
from english_copy import apply_english_copy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYERS = "ABC"
SUITS = {"S": "黑桃", "H": "红桃", "D": "方块", "C": "梅花"}
SYMBOLS = {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}
META = [
    ("第一张便笺", "从六张牌开始", "修复师在盒底发现一张便笺：第一轮由 A 领出。已有三张牌的位置得到确认，请补回另外三张。"),
    ("同色的回声", "手中有同花色，就必须跟随", "第二封信夹着一小段规则说明。先看领出的花色，再看同一人后来留下的牌，记录的空白就有了边界。"),
    ("大牌未必赢", "只有领出花色可以争胜", "便笺上有人给一张大牌画了圈，却没有写它赢了。离开领出花色，点数再大也不能赢得这一轮。"),
    ("接过领出权", "赢家决定下一轮从谁开始", "前一轮的批注和后一轮的牌面被装进两个信封。把赢家与下一次领出连起来，才能还原真正的顺序。"),
    ("没有跟上的牌", "从缺门反推原来的手牌", "一张异色牌被特别标记。出牌者当时为什么没有跟花色？将来要出的牌此刻也在手里，这条规则会留下证据。"),
    ("第三轮的落款", "完成第一份三轮档案", "最后一封教学信多出一轮。先补最确定的空位；放错也可交换或撤销。还原后逐手复盘，检查三轮如何接续。"),
    ("雨点与车票", "列车档案 01", "车票背面的牌局被雨点打湿。列车员保住了开局的两笔，请找回旅客尚未交出的牌。"),
    ("二号车厢", "列车档案 02", "二号车厢只留下两轮记录。行李标签确认了部分手牌归属，剩余空位必须符合跟花色规则。"),
    ("隧道前的一手", "列车档案 03", "列车驶入隧道前，速记员写下了最后看清的一手。出隧道后的赢家批注，是另一条可靠线索。"),
    ("靠窗的空位", "列车档案 04", "窗缝吹走半张记分纸，留下的人名仍然清晰。花色与持牌记录可以一起恢复这三轮。"),
    ("餐车的茶渍", "列车档案 05", "一圈茶渍遮住了点数。记录员另抄了花色，行李员则证实了几张牌原来属于谁。"),
    ("换轨之后", "列车档案 06", "换轨时的颠簸弄乱了笔迹。第一张牌没有丢，后面的每次领出仍要交给上一轮赢家。"),
    ("夜班检票员", "列车档案 07", "夜班检票员没有记全牌面，只在赢家旁边打了一个钩。那枚钩与手牌容量一样可靠。"),
    ("折起的时刻表", "列车档案 08", "时刻表折痕处缺了一行。虽然看不见那张牌，之后的出牌仍能证明它不可能来自某些人。"),
    ("站台来电", "列车档案 09", "站台打来的电话补充了一条确切记录。将它与车厢中已有的记录交叉检查，不能让同一张牌出现两次。"),
    ("灯灭的一分钟", "列车档案 10", "灯熄灭时，牌局仍按固定座次继续。人名对应的位置没变，只有领出的人可能改变。"),
    ("终点前的三轮", "列车档案 11", "终点站快到了，三位旅客把余下的牌全部打完。纸上不同花色交织，留下的缺门信息尤其有用。"),
    ("末班车归档", "列车档案 12", "十二页记录终于收齐。最后一页需要同时核对持牌、赢家和余牌，让这段旅途有一个完整的落款。"),
    ("钟声之前", "茶馆档案 01", "茶馆的钟声响起前，三段记录已经写好。现在它们次序散乱，请用领出牌与赢家恢复联系。"),
    ("错放的杯垫", "茶馆档案 02", "杯垫下面压着一条领出记录。杯垫摆放的位置不是座次证据，档案中明确的人名与规则才是。"),
    ("从 B 开始", "茶馆档案 03", "这一局从 B 领出。桌边仍然按 A、B、C 顺时针循环，下一轮则要从赢家重新开始。"),
    ("柜台下的纸条", "茶馆档案 04", "柜台下找到的纸条注明了某轮领出的牌，却没有写人名。谁赢得上一轮，谁才有资格领出它。"),
    ("两次交接", "茶馆档案 05", "记录上的箭头被抹掉了。两次领出权交接仍由牌面决定，不能按纸条摆放的先后来推断。"),
    ("逆光的笔迹", "茶馆档案 06", "逆光让几个点数难以辨认，但修复师已确认下面的公开事实。先连起轮次，再补每个人的牌。"),
    ("第三把椅子", "茶馆档案 07", "这次由 C 开局。椅子没有移动，固定座次循环会让每轮的第二、第三手自然确定。"),
    ("梅花印记", "茶馆档案 08", "纸条角上有梅花形的印记。印记只作装饰；真正能确定顺序的是公开记录中的花色、牌面与赢家。"),
    ("没有编号的页", "茶馆档案 09", "这一页没有手写编号。领出记录跨越三轮，必须同时满足才能恢复整场牌局的先后。"),
    ("最后一壶茶", "茶馆档案 10", "最后一壶茶送到时，记录员只写下了第三轮的片段。从已经确认的归属逐步向前推，补齐缺失的交接。"),
    ("钟摆停下以后", "茶馆档案 11", "钟摆停了，牌局没有停。时间不再可靠，规则却仍可靠：先前的赢家领出，手中有同花色必须跟随。"),
    ("风散纸页", "茶馆档案 12", "将茶馆最后一组散页归档。先后顺序必须由公开事实和牌局规则共同确定，不能拿作者的排列作线索。"),
    ("港口第一封信", "证词档案 01", "三位旧友寄来不同的回忆。下面的可信记录已由原稿核对；证词区明确标出了错误条数，请一并推理。"),
    ("记错的花色", "证词档案 02", "来信人记得轮次，却可能认错了花色。证词中的每句话都能由完整牌局判断真假，主观印象不作证据。"),
    ("码头的交接", "证词档案 03", "有人把领出者与赢家混在一起。仔细区分这一轮谁先出，与谁将在下一轮先出。"),
    ("相邻的数字", "证词档案 04", "潮湿的纸上点数容易看错。不要先认定某个人可靠，按题目公开的错误条数核对所有证词。"),
    ("第二位见证人", "证词档案 05", "第二位见证人的来信补全了另一种说法。它仍是待核实证词，不能覆盖经过原稿确认的事实。"),
    ("灯塔来信", "证词档案 06", "灯塔守夜人记下了夜间牌局。几句话互相牵连，某一句暂时不符并不代表整份假设立刻失败。"),
    ("邮戳之间", "证词档案 07", "邮戳证明来信同属一场牌局。将证词与持牌限制放在一起，找出恰好符合错误数量的还原。"),
    ("两处偏差", "证词档案 08", "这一页有两处明确的记忆偏差。错误并非随机惩罚，而是需要由同一个完整牌局同时判定的约束。"),
    ("最后的旁观者", "证词档案 09", "最后一位旁观者寄来的纸条让档案接近完整。检查三轮中的赢家轮转，也检查每条证词的实际含义。"),
    ("封存之前", "证词档案 10", "四十份档案来到最后一页。把可靠事实、待核实证词和自己的假设分清，再让每张牌回到唯一的位置。")
]

# Human-edited reasoning paragraphs. The accompanying machine-readable
# conclusions and their minimal evidence bases are still exhaustively proved.
EDITED_STEPS = {
    9: "第二轮 B 出 ♠4。C 第一轮没有跟梅花，之后也不可能持有梅花。假如 A 用最小的 ♣3 赢了第一轮，B 也不能出或持有梅花，余下两张梅花就全归 A；但 A 还必须领出第二轮的 ♠4，这会让 A 超过三张牌。故只能 B 赢第一轮并领出 ♠4。",
    10: "第二轮 A 出 ♠3。A 该轮确定出黑桃，因此不会是领出 ♦5 的人，第一轮一定由别人赢过 A 的 ♠7。能赢过它的黑桃只有 ♠12，已经用于第一轮赢家；A 第二轮的黑桃便只剩 ♠3。",
    11: "第一轮 C 出 ♠7。C 的全部手牌是 ♣2 与 ♠7；A 已领出黑桃，C 有黑桃就必须跟，不能先打梅花。",
    12: "第二轮 C 出 ♠9。B 第一轮没有跟黑桃，所以他没有黑桃。假如 C 第一轮也不跟，剩余三张黑桃将全归 A，但 A 连同已出的 ♠3 会持有四张牌，超过每人三张的上限。因此 C 必须用更大的黑桃赢第一轮，并领出第二轮的 ♠9。",
    13: "第一轮 C 出 ♠13。B 没有黑桃，♠13 只能属于 A 或 C。若 A 留着 ♠13，用 ♠5 赢第一轮，再领出最大的方块 ♦9 赢第二轮，第三轮便由 A 领 ♠13；没有黑桃的 B 不可能赢第三轮。这与可信赢家记录冲突，所以 C 必须在第一轮出 ♠13。",
    14: "第二轮 A 出 ♦14。A 第一轮领出的 ♣10 是牌池中最大的梅花，不会被其他花色的高点数击败。A 因此赢第一轮，并负责领出第二轮已确认的 ♦14。",
    15: "第二轮 B 出 ♥3。C 没有跟黑桃，不能持有余下的黑桃。若 B 也不跟，A 就必须持有全部三张黑桃；A 虽会赢第一轮，却没有位置再持有第二轮必须领出的 ♥3。故第一轮由 B 以较大的黑桃获胜，第二轮 ♥3 属于 B。",
    16: "第二轮 A 出 ♦3。A 领出的 ♠10 是本局最大的黑桃，因此必定赢第一轮。赢家领出下一轮，第二轮已确认的 ♦3 就落在 A 的位置。",
    17: "第二轮 A 出 ♥4。第一轮 B、C 已分别出 ♦7、♦3：如果 A 领出方块，只剩更大的 ♦11；如果 A 领出其他花色，B、C 都不能争胜。两种情况下赢家都是 A，所以第二轮由 A 领出 ♥4。",
    18: "第一轮 C 出 ♦3。C 第二轮还持有 ♦9，所以第一轮必须跟 A 领出的方块。♦9 留在第二轮不能提前用，剩下的候选是 ♦3、♦13；若 C 第一轮出 ♦13 获胜，他第二轮必须领 ♣5，便与已确认的 ♦9 冲突。因此只能出 ♦3。",
    19: "第一轮 C 出 ♠4。牌池只有 ♠4、♠10 两张黑桃；C 第一轮的花色确定为黑桃，而 ♠10 已确认留到 C 第三轮。同一张牌不能使用两次，所以第一轮只剩 ♠4。",
    20: "第一轮 A 出 ♦5。♦5 的归属已经确定是 A，A 第二轮又已确认出 ♦13。每人只有两张牌，♦5 只能落在 A 第一轮。",
    21: "第二轮 B 出 ♦13。首轮由 B 领出 ♦8，而更大的 ♦13 已确认留到第二轮才领出。第一轮没有其他方块能够超过 ♦8，因此 B 赢第一轮，随后领出 ♦13。",
    22: "第一轮 B 出 ♠5。B 的这一手确定是黑桃，而牌池只有 ♠5 与 ♠10 两张黑桃。♠10 已确认属于 C，不能同时分给 B，故 B 只能出 ♠5。",
    23: "第二轮 C 出 ♠5。这张牌既被确认为第二轮领出牌，也被确认为原本属于 C。它必须落在 C 第二轮，同时证明 C 是第二轮的领出者。",
    24: "第三轮 B 出 ♣13。本局只有 ♣5、♣13 两张梅花。♣5 确定属于 C；B 第三轮却确定出梅花，因此 B 只能出剩下的 ♣13。",
    25: "第一轮 A 出 ♦10。C 领 ♦4，B 出 ♥11，因此 B 没有方块。若 C 赢第一轮，他会连着领出最大的红桃 ♥14，再领第三轮的 ♥5；C 的三张牌随即用满，而 A、B 又都没有方块，剩余的 ♦10 将无人能持有。因此 A 必须用 ♦10 赢第一轮。",
    26: "第二轮 A 出 ♣2。A 第一轮领出 ♠8。唯一更大的黑桃 ♠13 已确认留到第三轮领出，不可能第一轮出现；所以 A 赢第一轮，并领出已确认的第二轮 ♣2。",
    27: "第二轮 A 出 ♠13。该轮领出牌已确认是 ♠13，B 却出红桃，C 已确认出 ♠4；两人都不可能领出 ♠13，因此这张牌只能属于 A 的第二轮。",
    28: "第二轮 C 出 ♠2。B 第一轮领 ♥3。若 B 获胜，另外两人必然没有红桃，剩余 ♥7、♥11 就都属于 B；B 不可能再持有第二轮必须领出的 ♠2。因此赢家是 A 或 C，而 A 第二轮已出 ♦10，只能由 C 领 ♠2。",
    29: "第二轮 B 出 ♦2。B 首轮领出的牌是 ♥9，唯一更大的红桃 ♥13 又确定在 B 自己手中，因此别人无法赢过这手 ♥9。B 赢第一轮，接着领出第二轮的 ♦2。",
    30: "第三轮 A 出 ♣9。本局只有两张梅花：♣3、♣9。♣3 已确认属于 B，而 A 第三轮确定出梅花，因此只能是 ♣9。",
    31: "第一轮 A 出 ♣6。证词 3 与证词 4 把同一张 ♣6 放在两个位置，至少有一句是假。若证词 3 假、证词 4 真，证词 2 又会与证词 4 的 C 第一轮牌面冲突，便出现两句假话。因此唯一的假话只能是证词 4，证词 3 所说的 A 第一轮 ♣6 成立。",
    35: "第一轮 A 出 ♠3。A 的这一手已确认是黑桃，牌池中的另一张黑桃 ♠9 又已确认归 B。牌不能重复，故 A 第一轮只剩 ♠3；证词真假仍需要结合后两轮再核实。",
    36: "第二轮 A 出 ♠5。A 第一轮领出的 ♥10 是本局最大的红桃，其他花色都不能击败它。因此 A 赢第一轮，第二轮已确认的领出牌 ♠5 必须由 A 打出。",
    37: "第三轮 A 出 ♦11。证词 1 与证词 4 对 C 第三轮的花色互相矛盾，恰有一条错误意味着另外两条证词必须成立，所以 A 第二轮出 ♠7。A 第一轮的 ♣13 已固定，♦11 又确定归 A，因此 ♦11 只能留在 A 第三轮。",
    40: "第三轮 A 出 ♠3。该轮已确认领出 ♠3，但 B 的牌确定是梅花，C 已确认出 ♥5；他们都不可能领出黑桃，因此只能由 A 在第三轮出 ♠3。"
}

def label(card):
    return SYMBOLS[card[0]] + card[1:]

def legal_records(cards, first):
    """Exhaustive, independent author-side reference implementation."""
    rounds = len(cards) // 3
    suits = [c[0] for c in cards]
    ranks = [int(c[1:]) for c in cards]
    records = []
    for board in itertools.permutations(range(len(cards))):
        lead = first
        leaders, winners = [], []
        valid = True
        for r in range(rounds):
            leaders.append(lead)
            lead_suit = suits[board[3*r+lead]]
            for p in range(3):
                if suits[board[3*r+p]] != lead_suit:
                    if any(suits[board[3*j+p]] == lead_suit for j in range(r+1, rounds)):
                        valid = False
                        break
            if not valid:
                break
            lead = max((p for p in range(3) if suits[board[3*r+p]] == lead_suit), key=lambda p: ranks[board[3*r+p]])
            winners.append(lead)
        if valid:
            records.append((board, tuple(leaders), tuple(winners)))
    return records

def check(c, record, cards):
    k, r, p, v = c
    board, leaders, winners = record
    if k == "cardPlayed": return cards[board[r*3+p]] == v
    if k == "owner": return board.index(cards.index(v)) % 3 == p
    if k == "roundWinner": return winners[r] == p
    if k == "leadCard": return cards[board[r*3+leaders[r]]] == v
    if k == "playedSuit": return cards[board[r*3+p]][0] == v
    raise ValueError(k)

def all_constraints(cards):
    result = []
    for r in range(len(cards)//3):
        for p in range(3):
            result += [("cardPlayed", r, p, c) for c in cards]
            result += [("playedSuit", r, p, s) for s in sorted({c[0] for c in cards})]
        result += [("roundWinner", r, p, None) for p in range(3)]
        result += [("leadCard", r, None, c) for c in cards]
    result += [("owner", None, p, c) for p in range(3) for c in cards]
    return result

def json_constraint(c):
    k, r, p, v = c
    result = {"kind": k}
    if r is not None: result["round"] = r+1
    if p is not None: result["player"] = PLAYERS[p]
    if k in ("cardPlayed", "owner", "leadCard"): result["card"] = v
    if k == "playedSuit": result["suit"] = v
    return result

def sentence(c):
    k, r, p, v = c
    if k == "cardPlayed": return f"第 {r+1} 轮，{PLAYERS[p]} 出的是 {label(v)}。"
    if k == "owner": return f"{label(v)} 原本在 {PLAYERS[p]} 的手中。"
    if k == "roundWinner": return f"第 {r+1} 轮的赢家是 {PLAYERS[p]}。"
    if k == "leadCard": return f"第 {r+1} 轮领出的牌是 {label(v)}。"
    if k == "playedSuit": return f"第 {r+1} 轮，{PLAYERS[p]} 出的是{SUITS[v]}。"

def evidence(c, i, testimony=False):
    return {"id": ("t" if testimony else "f")+str(i), "text": sentence(c), "constraint": json_constraint(c)}

def unique_fact_set(records, target, cards, chapter, rng, testimony, false_count, preset):
    def policy(rec): return sum(not check(t, rec, cards) for t in testimony) == false_count
    remaining = [x for x in records if policy(x)]
    facts = list(preset)
    for f in facts: remaining = [x for x in remaining if check(f, x, cards)]
    candidates = [x for x in all_constraints(cards) if check(x, target, cards) and x not in facts and x not in testimony]
    rng.shuffle(candidates)
    weights = {"cardPlayed": 1.0, "owner": 1.08, "playedSuit": 1.04, "roundWinner": 1.0, "leadCard": 1.02}
    if chapter == 3: weights.update(cardPlayed=0.73, leadCard=1.3, roundWinner=1.16, owner=1.2)
    if chapter == 4: weights.update(cardPlayed=0.83, owner=1.14)
    while len(remaining) > 1:
        scores = []
        fixed_count = sum(f[0] == "cardPlayed" for f in facts)
        for c in candidates:
            if c[0] == "cardPlayed" and fixed_count >= (3 if len(cards)==6 else 5): continue
            survivors = [x for x in remaining if check(c,x,cards)]
            if len(survivors) == len(remaining): continue
            score = (len(remaining)-len(survivors))*weights[c[0]]
            scores.append((score, -len(survivors), c, survivors))
        if not scores: raise RuntimeError("No separating evidence")
        best = max(scores, key=lambda x: (x[0], x[1]))
        facts.append(best[2]); candidates.remove(best[2]); remaining = best[3]
    assert remaining == [target]
    # Remove redundant non-preset facts, preserving an intelligible tutorial anchor.
    for fact in list(reversed(facts)):
        if fact in preset: continue
        reduced = [f for f in facts if f != fact]
        valid = [x for x in records if policy(x) and all(check(f,x,cards) for f in reduced)]
        if len(valid) == 1: facts.remove(fact)
    return facts

def witness_puzzle(records, target, cards, rng, false_count, preset):
    """Start with genuinely ambiguous reliable evidence. Every chosen testimony
    is individually undecided under that evidence; the exact-count policy then
    selects one global record. Avoid witnesses contradicted by a visible anchor.
    """
    facts = unique_fact_set(records,target,cards,4,rng,[],0,preset)
    remaining=[target]
    for _ in range(3):
        reductions=[]
        for f in facts:
            if f in preset: continue
            trial=[a for a in facts if a!=f]
            matches=[r for r in records if all(check(a,r,cards) for a in trial)]
            if len(remaining)<len(matches)<=24:
                reductions.append((abs(8-len(matches)),trial,matches))
        if not reductions: break
        _,facts,remaining=min(reductions,key=lambda x:x[0])
        if len(remaining)>=5: break
    if len(remaining)<2: raise RuntimeError("Could not retain witness ambiguity")
    useful=[c for c in all_constraints(cards) if c not in facts and 0<sum(check(c,r,cards) for r in remaining)<len(remaining)]
    true=[c for c in useful if check(c,target,cards)]
    false=[c for c in useful if not check(c,target,cards)]
    for _ in range(1200):
        ts=rng.sample(true,4-false_count)+rng.sample(false,false_count)
        if len({(c[0],c[1],c[2]) for c in ts}) < 3: continue
        matches=[r for r in remaining if sum(not check(c,r,cards) for c in ts)==false_count]
        if matches==[target]:
            rng.shuffle(ts)
            return facts,ts
    raise RuntimeError("No separating witness policy")

def make_hints(records, target, cards, facts, testimonies, false_count):
    # Find a not-already-given card conclusion with the smallest sufficient evidence basis.
    nonfixed = [i for i in range(len(cards)) if not any(f[0]=="cardPlayed" and f[1]*3+f[2]==i for f in facts)]
    all_evidence = [("f"+str(i+1), f) for i,f in enumerate(facts)]
    policy_records = [r for r in records if sum(not check(t,r,cards) for t in testimonies)==false_count]
    best = None
    for slot in nonfixed:
        conclusion = ("cardPlayed", slot//3, slot%3, cards[target[0][slot]])
        basis = list(all_evidence)
        for entry in list(reversed(basis)):
            reduced = [x for x in basis if x != entry]
            options = [r for r in policy_records if all(check(c,r,cards) for _,c in reduced)]
            if options and all(check(conclusion,r,cards) for r in options): basis = reduced
        # Prefer a genuine connection between evidence items over simply copying
        # a publicly given first lead into its already-known player's column.
        key = (0 if len(basis) >= 2 else 1, len(basis), slot)
        if best is None or key < best[0]: best = (key, conclusion, basis)
    _, conclusion, basis = best
    ids = [e[0] for e in basis] + ["t"+str(i+1) for i in range(len(testimonies))]
    quoted = "；".join(sentence(c).rstrip("。") for _,c in basis)
    if not quoted:
        quoted = "；".join(f"证词 {i+1}："+sentence(c).rstrip("。") for i,c in enumerate(testimonies))
    # Editorial rule bridge, grounded only in known evidence, never answer comparison.
    bridge = None
    known = {(c[1],c[2]):c[3] for c in facts if c[0]=="cardPlayed"}
    first_lead = target[1][0]
    if (0, first_lead) in known:
        lead = known[(0,first_lead)]
        for (r,p), card in known.items():
            if r==0 and card[0] != lead[0]:
                bridge = f"第一轮由 {PLAYERS[first_lead]} 领出 {label(lead)}，而 {PLAYERS[p]} 出了 {label(card)}。必须跟花色，所以 {PLAYERS[p]} 当时手中没有{SUITS[lead[0]]}，后面也不能再出{SUITS[lead[0]]}。"
                break
    if bridge is None:
        winner = next((c for _,c in basis if c[0]=="roundWinner" and c[1] < len(cards)//3-1), None)
        if winner:
            bridge = f"第 {winner[1]+1} 轮由 {PLAYERS[winner[2]]} 获胜，因此第 {winner[1]+2} 轮也由 {PLAYERS[winner[2]]} 领出。随后仍按 A → B → C 循环出牌；不同花色即使点数更大，也不能夺走这一轮。"
        else:
            own = next((c for _,c in basis if c[0]=="owner"), None)
            if own:
                bridge = f"{label(own[3])} 必须落在 {PLAYERS[own[2]]} 的列内。每人恰有 {len(cards)//3} 张牌；检查它放在较晚轮次时，是否会让这个人较早时明明有领出花色却没有跟。"
            else:
                lead = next((c for _,c in basis if c[0]=="leadCard"), None)
                if lead:
                    bridge = f"{label(lead[3])} 是第 {lead[1]+1} 轮的第一张牌，只能由该轮领出者打出。把这个条件与前轮赢家相连，再检查各人尚未打出的同花色牌。"
                else:
                    bridge = f"先把这些已知花色和牌面放到对应的人与轮次。每张牌只使用一次；某人较晚轮次的牌，在较早轮次仍属于他的手牌，也受必须跟花色的规则约束。"
    if testimonies: bridge += f"证词必须合起来核对：恰有 {false_count} 条为假，而不是每句话都必须为真。"
    destination = f"第 {conclusion[1]+1} 轮 {PLAYERS[conclusion[2]]} 的牌位"
    # A concrete contradiction certificate: without the final premise this slot
    # has several candidates; every alternative loses all legal completions when
    # that particular public premise is restored. No author-answer lookup is used
    # to decide which alternative is impossible.
    if basis:
        final_id, final_fact = basis[-1]
        earlier = basis[:-1]
        before = [r for r in policy_records if all(check(c,r,cards) for _,c in earlier)]
        alternatives = sorted({cards[r[0][conclusion[1]*3+conclusion[2]]] for r in before} - {conclusion[3]}, key=lambda c:(c[0],int(c[1:])))
    else:
        alternatives=[]
    if alternatives:
        rejected = "、".join(label(c) for c in alternatives)
        proof = f"暂时不采用“{sentence(final_fact).rstrip('。')}”时，这里还可能出现 {rejected}；但这些分支都无法在遵守跟花色与赢家领出规则的同时满足这条记录。把该记录放回，留下的只有 {label(conclusion[3])}。"
    else:
        proof = f"{quoted}。对照每人每轮只出一张、每张牌只使用一次的规则，这些记录确定了这个牌位。"
    return [
        {"title":"关注证据", "text":f"先关注{destination}。这一处可以从以下公开记录入手：{quoted}。" + (f"同时保留“恰有 {false_count} 条错误证词”的条件。" if testimonies else ""), "evidenceIDs":ids, "conclusion":None},
        {"title":"连接规则", "text":bridge, "evidenceIDs":["f"+str(i+1) for i in range(len(facts))]+["t"+str(i+1) for i in range(len(testimonies))], "conclusion":None},
        {"title":"给出一步", "text":f"{sentence(conclusion)}{proof}", "evidenceIDs":ids, "conclusion":json_constraint(conclusion)}
    ]

def explanation(target, cards, facts, testimonies):
    lines = []
    board, leaders, winners = target
    for r, leader in enumerate(leaders):
        order = [(leader+i)%3 for i in range(3)]
        seq = " → ".join(PLAYERS[p]+"："+label(cards[board[r*3+p]]) for p in order)
        suit = cards[board[r*3+leader]][0]
        lines.append(f"第 {r+1} 轮 {seq}。领出的是{SUITS[suit]}，同花色中点数最大的牌属于 {PLAYERS[winners[r]]}，因此 {PLAYERS[winners[r]]} 获胜。")
        for p in order:
            if cards[board[r*3+p]][0] != suit and r < len(leaders)-1:
                later = "、".join(label(cards[board[j*3+p]]) for j in range(r+1,len(leaders)))
                lines.append(f"{PLAYERS[p]} 本轮没有跟{SUITS[suit]}，说明其余手牌 {later} 都不是{SUITS[suit]}；这是必须跟花色规则留下的持牌证据。")
    if testimonies:
        false_ids = ["证词 "+str(i+1) for i,t in enumerate(testimonies) if not check(t,target,cards)]
        lines.append("归档核对："+"、".join(false_ids)+"有误，其余证词成立。可信记录全部成立。")
        for i,t in enumerate(testimonies):
            if check(t,target,cards): continue
            k,r,p,v=t
            if k=="cardPlayed": correct=(k,r,p,cards[board[r*3+p]])
            elif k=="playedSuit": correct=(k,r,p,cards[board[r*3+p]][0])
            elif k=="owner": correct=(k,None,board.index(cards.index(v))%3,v)
            elif k=="roundWinner": correct=(k,r,winners[r],None)
            elif k=="leadCard": correct=(k,r,None,cards[board[r*3+leaders[r]]])
            lines.append(f"证词 {i+1} 的更正：{sentence(correct)}")
    return "\n".join(lines)

def make_level(n):
    chapter = 1 if n<=6 else 2 if n<=18 else 3 if n<=30 else 4
    local = n if chapter==1 else n-6 if chapter==2 else n-18 if chapter==3 else n-30
    rng = random.Random(59021+n*337)
    if n==1:
        cards = ["S2","S5","S9","H3","H7","H10"]
        first=0
    else:
        patterns = [
            ["S2","S6","S11","H3","H7","H12"],
            ["S3","S8","H2","H9","D5","D13"],
            ["S2","S5","S10","H4","H8","H13","D3","D7","D12"],
            ["S2","S4","S8","S12","H3","H7","H11","D5","D10"],
            ["S3","S6","S9","S13","H2","H5","H10","H14","C7"],
            ["S2","S7","S12","H3","H9","D4","D10","C5","C13"],
            ["S2","S5","S8","S11","S14","H4","H10","D6","D12"],
            ["H2","H6","H11","D3","D8","D13","C4","C7","C12"]
        ]
        if n in (2,3,4,5,8,11,20,31): pattern=(n+1)%2
        else: pattern=2+((n*7+chapter)%6)
        cards = list(patterns[pattern])
        # Suit permutations change the visual vocabulary, while rank spacings stay explicit.
        if n>6:
            rotate = n%4
            suits="SHDC"; remap={s:suits[(i+rotate)%4] for i,s in enumerate(suits)}
            cards = [remap[c[0]]+c[1:] for c in cards]
        first = 1 if n==21 else 2 if n==25 else (n//4)%3 if chapter>=3 else 0
    records=legal_records(cards,first)
    if n==1:
        target=next(x for x in records if tuple(cards[c] for c in x[0])==("S5","S9","H3","S2","H7","H10"))
        facts=[("cardPlayed",0,0,"S5"),("cardPlayed",0,2,"H3"),("cardPlayed",1,1,"H7"),("roundWinner",0,1,None),("leadCard",1,None,"H7")]
        testimony=[]; false_count=0
    else:
        pool=[x for x in records if len(set(x[2]))>=2 and any(cards[x[0][p]][0]!=cards[x[0][first]][0] for p in range(3))]
        if n==3:
            pool=[x for x in pool if max(range(3),key=lambda p:int(cards[x[0][p]][1:]))!=x[2][0]]
        rng.shuffle(pool)
        for attempt, target in enumerate(pool[:100]):
            testimony=[]; false_count=0
            preset=[]
            if chapter<=2:
                preset=[("cardPlayed",0,first,cards[target[0][first]])]
                off=next(p for p in range(3) if cards[target[0][p]][0]!=cards[target[0][first]][0])
                preset.append(("cardPlayed",0,off,cards[target[0][off]]))
                if n==2:
                    # A concrete later record gives this lesson a forward hand constraint.
                    preset.append(("cardPlayed",1,first,cards[target[0][3+first]]))
            if chapter==3:
                preset=[("leadCard",len(cards)//3-1,None,cards[target[0][3*(len(cards)//3-1)+target[1][-1]]])]
            if chapter==4:
                false_count=2 if local%2==0 else 1
                # One dependable anchor distinguishes evidence from witness memory.
                preset=[("cardPlayed",0,first,cards[target[0][first]])]
            try:
                if chapter==4:
                    facts,testimony=witness_puzzle(records,target,cards,rng,false_count,preset)
                else:
                    facts=unique_fact_set(records,target,cards,chapter,rng,testimony,false_count,preset)
            except RuntimeError:
                continue
            if chapter!=4 or sum(all(check(f,x,cards) for f in facts) for x in records)>1: break
        else: raise RuntimeError(f"Could not make testimony essential: {n}")
    survivors=[x for x in records if all(check(f,x,cards) for f in facts) and sum(not check(t,x,cards) for t in testimony)==false_count]
    assert survivors==[target], (n,len(survivors))
    hints=make_hints(records,target,cards,facts,testimony,false_count)
    if n==1:
        hints=[
            {"title":"关注第一轮", "text":"第一轮 A 出 ♠5，赢家却是 B。先找牌池里哪张牌能够赢过领出的黑桃。", "evidenceIDs":["f1","f4"], "conclusion":None},
            {"title":"只有同花色争胜", "text":"无王牌时，只有领出花色参与争胜。B 要赢过 ♠5，就必须出比 5 更大的黑桃；再检查剩余牌中谁满足这个条件。", "evidenceIDs":["f1","f4"], "conclusion":None},
            {"title":"给出一步", "text":"第一轮 B 出 ♠9，因为它是牌池中唯一能以领出花色赢过 ♠5 的牌。先落实这一手，再用 C 没有跟黑桃的事实推断下一轮。", "evidenceIDs":["f1","f4"], "conclusion":{"kind":"cardPlayed","round":1,"player":"B","card":"S9"}}
        ]
    if 2 <= n <= 8:
        tutorial = {
            2: ("先看 C 第一轮没有跟方块这件事，再看 A 两个已经填好的位置。谁还能持有剩下的方块？", "C 第一轮出红桃，说明他手中没有方块。A 的两张牌也都已经确认，所以剩下的方块只能在 B 手中；第一轮 B 必须跟领出的花色。", "第一轮 B 出 ♦13。C 没有方块，A 的两张牌是 ♦5 和 ♠8，剩下的 ♦13 只能归 B，并且必须在第一轮跟出。", ["f1","f2","f3"], ("cardPlayed",0,1,"D13")),
            3: ("两条可信归属已经告诉你 B 的全部手牌。先决定 B 必须跟什么花色，不要只寻找桌上最大的数字。", "A 领出黑桃，而 B 的两张牌中有黑桃。B 必须先出那张黑桃；C 的红桃点数即使更大，也不能参与黑桃这一轮的争胜。", "第一轮 B 出 ♠11。B 手里只有 ♥3 和 ♠11，必须跟黑桃，所以不能选择 ♥3。", ["f1","f3","f4"], ("cardPlayed",0,1,"S11")),
            4: ("先确定第一轮谁一定获胜，再用“第二轮 B 获胜”倒推第二轮的领出花色。", "A 领出的方块已经是牌池中最大的方块，所以 A 必定领出第二轮。B 要赢第二轮，必须与 A 同花色且更大；在剩余牌中寻找这样的两张牌。", "第一轮 C 出 ♦5。A 用 ♦13 赢第一轮，第二轮要让 B 获胜，A 与 B 只能分别出 ♥2、♥9。B 第一轮没有跟方块，不能持有 ♦5；A 的两张牌已确定，所以 ♦5 必须在 C 第一轮。", ["f1","f2","f3"], ("cardPlayed",0,2,"D5")),
            5: ("关注 C 第二轮的空位。先从 B 没有跟黑桃推断他不能持有什么，再检查 A 的手牌是否已经满额。", "B 第一轮出红桃，说明他没有黑桃。A 第一轮的黑桃已固定，另一张牌的归属也已确定；因此剩余黑桃不能交给 A 或 B。", "第二轮 C 出 ♠2。B 没有黑桃；A 的两张牌是 ♠11、♥3；C 第一轮已出 ♠6，因此剩下的 ♠2 必须留在 C 第二轮。", ["f1","f2","f3","f4"], ("cardPlayed",1,2,"S2")),
            6: ("第一轮的三张牌都能直接看见。比较领出花色中的点数，找出谁会领出第二轮。", "红桃不能赢过领出的黑桃。先确定两张黑桃中较大的那一张属于谁；这个人必须打出已确认的第二轮领出牌。", "第二轮 C 出 ♥3。第一轮 C 的 ♠8 赢过 A 的 ♠2，而 B 的 ♥7 不参与争胜，所以第二轮由 C 领出已确认的 ♥3。", ["f1","f2","f3","f6"], ("cardPlayed",1,2,"H3")),
            7: ("先处理 C 的第三轮：有两条逐轮记录，还有一条明确的手牌归属。", "每人恰好三张牌，分别用于三轮。如果一个人的前两轮已经记录，另一张确定属于他的牌就不能去其他人的列，也不能重复使用。", "第三轮 C 出 ♣7。C 前两轮已经分别出了 ♣12、♣2，而 ♣7 也确定属于 C，因此只剩第三轮这个位置。", ["f2","f5","f6"], ("cardPlayed",2,2,"C7")),
            8: ("先确定第一轮的赢家，再寻找第二轮能够让 C 获胜的同花色组合。", "A 的 ♠8 是牌池中最大的黑桃，所以 A 会领出第二轮。C 要赢第二轮，必须出与 A 相同花色且更大的牌；B 第一轮未跟黑桃，也说明他没有另一张黑桃。", "第一轮 C 出 ♠3。A 赢第一轮；第二轮要让 C 赢，剩余牌中只能由 A 领 ♥2、C 跟 ♥9。B 没有黑桃，而 A 的两张牌已确定，故 ♠3 必须落在 C 第一轮。", ["f1","f2","f3"], ("cardPlayed",0,2,"S3"))
        }[n]
        direction, relation, step, ids, conclusion=tutorial
        hints=[{"title":title,"text":text,"evidenceIDs":ids,"conclusion":json_constraint(conclusion) if i==2 else None} for i,(title,text) in enumerate(zip(["关注证据","连接规则","给出一步"],[direction,relation,step]))]
    if n in EDITED_STEPS:
        hints[2]["text"]=EDITED_STEPS[n]
    if n==31:
        hints[0]["text"]="先把证词 2、3、4 放在一起读：它们是否对同一张牌或同一个牌位给出了不同说法？本页恰有一条错误证词。"
        hints[1]["text"]="同一张 ♣6 不可能同时出现在 A 与 C 的第一轮。因此证词 3、4 至少有一句是假；再检验哪种情况会迫使证词 2 也是假，超过允许的错误数量。"
    title,subtitle,story=META[n-1]
    return {"schemaVersion":1,"contentRevision":1,"id":f"chapter{chapter:02d}.level{local:02d}","chapterID":f"chapter{chapter:02d}","number":n,"title":title,"subtitle":subtitle,"story":story,
        "rules":{"id":"follow_suit_no_trump","version":1,"players":list(PLAYERS),"firstLeader":PLAYERS[first],"roundCount":len(cards)//3},
        "cards":[{"id":c} for c in cards],"facts":[evidence(c,i+1) for i,c in enumerate(facts)],"falseTestimonyCount":false_count,
        "testimonies":[evidence(c,i+1,True) for i,c in enumerate(testimony)],"hints":hints,
        "authorSolution":{"plays":[cards[c] for c in target[0]],"falseTestimonyIDs":["t"+str(i+1) for i,c in enumerate(testimony) if not check(c,target,cards)],"explanation":explanation(target,cards,facts,testimony)}}

if __name__=="__main__":
    levels=[]
    path=ROOT/"Drirdarpoul/Data/levels.json"
    for n in range(1,41):
        level=apply_english_copy(make_level(n)); levels.append(level)
        print(f"{n:02d} {level['title']}: {len(level['cards'])} cards, {len(level['facts'])} facts, {len(level['testimonies'])} testimonies; unique",flush=True)
    path.write_text(json.dumps(levels,ensure_ascii=False,indent=2)+"\n")
