import Foundation

struct Chapter {
    let id: String
    let title: String
    let subtitle: String
    let story: String
}

enum LevelRepositoryError: LocalizedError {
    case missingFile
    case invalid([String])
    var errorDescription: String? {
        switch self {
        case .missingFile: return "未找到内置档案，请重新安装应用。"
        case .invalid(let messages): return "档案内容校验失败：" + messages.joined(separator: "；")
        }
    }
}

enum LevelRepository {
    static let chapters: [Chapter] = [
        Chapter(id: "chapter01", title: "入门档案", subtitle: "六封旧信 · 6 关", story: "修复室收到一盒没有署名的牌局记录。六张便笺从最简单的空位开始，教你辨认每张牌留下的痕迹。"),
        Chapter(id: "chapter02", title: "缺失记录", subtitle: "末班列车 · 12 关", story: "雨夜的末班列车抵站后，列车员交来十二页被雨水洇湿的记分纸。补回失去的笔迹，让旅途重新连贯。"),
        Chapter(id: "chapter03", title: "错序档案", subtitle: "钟楼茶馆 · 12 关", story: "茶馆搬迁时，一阵风打散了柜中的记录。纸上留下了牌面和零散的赢家批注，真正的先后顺序等你恢复。"),
        Chapter(id: "chapter04", title: "矛盾证词", subtitle: "港口来信 · 10 关", story: "港口俱乐部的旧友各自寄回回忆。有些记忆出了偏差。可信记录始终可靠，每页明确说明恰有多少条证词错误。")
    ]

    static func load(bundle: Bundle = .main) throws -> [Level] {
        guard let url = bundle.url(forResource: "levels", withExtension: "json") else {
            throw LevelRepositoryError.missingFile
        }
        return try load(url: url)
    }

    static func load(url: URL) throws -> [Level] {
        let levels = try JSONDecoder().decode([Level].self, from: Data(contentsOf: url))
        var issues: [String] = []
        if levels.count != 40 { issues.append("关卡总数必须为 40") }
        if Set(levels.map { $0.id }).count != levels.count { issues.append("关卡 ID 重复") }
        let expectedCounts = [6, 12, 12, 10]
        for (i, chapter) in chapters.enumerated() {
            let entries = levels.filter { $0.chapterID == chapter.id }
            if entries.count != expectedCounts[i] { issues.append("\(chapter.title)关卡数异常") }
        }
        for (index, level) in levels.enumerated() {
            if level.number != index + 1 { issues.append("\(level.id)序号不连续") }
            if !chapters.contains(where: { $0.id == level.chapterID }) { issues.append("未知章节 \(level.chapterID)") }
            issues += RuleEngine.validateStructure(level: level).map { "\(level.id)：\($0)" }
        }
        guard issues.isEmpty else { throw LevelRepositoryError.invalid(issues) }
        return levels
    }
}
