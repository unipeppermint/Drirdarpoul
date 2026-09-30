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
        case .missingFile: return "The built-in files could not be found. Please reinstall the app."
        case .invalid(let messages): return "File validation failed: " + messages.joined(separator: "; ")
        }
    }
}

enum LevelRepository {
    static let chapters: [Chapter] = [
        Chapter(id: "chapter01", title: "First Traces", subtitle: "Six old letters · 6 files", story: "A box of unsigned game records arrives at the restoration room. Six old notes teach you to follow the traces each card leaves behind."),
        Chapter(id: "chapter02", title: "Missing Records", subtitle: "The last train · 12 files", story: "The last train arrives through the rain. Its conductor brings twelve water-stained score sheets. Recover the missing plays and piece the journey together."),
        Chapter(id: "chapter03", title: "Scattered Pages", subtitle: "Clocktower tea room · 12 files", story: "A gust scatters the tea room's records during a move. Card faces and scattered notes about the winners survive. Restore the order of play."),
        Chapter(id: "chapter04", title: "Conflicting Accounts", subtitle: "Letters from the harbor · 10 files", story: "Old friends from the harbor club send their recollections. Some memories are mistaken. The reliable records hold true; each file states exactly how many witness statements are false.")
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
        if levels.count != 40 { issues.append("The archive must contain 40 files") }
        if Set(levels.map { $0.id }).count != levels.count { issues.append("Duplicate file ID") }
        let expectedCounts = [6, 12, 12, 10]
        for (i, chapter) in chapters.enumerated() {
            let entries = levels.filter { $0.chapterID == chapter.id }
            if entries.count != expectedCounts[i] { issues.append("Unexpected file count in \(chapter.title)") }
        }
        for (index, level) in levels.enumerated() {
            if level.number != index + 1 { issues.append("File numbers are not consecutive at \(level.id)") }
            if !chapters.contains(where: { $0.id == level.chapterID }) { issues.append("Unknown chapter: \(level.chapterID)") }
            issues += RuleEngine.validateStructure(level: level).map { "\(level.id)：\($0)" }
        }
        guard issues.isEmpty else { throw LevelRepositoryError.invalid(issues) }
        return levels
    }
}
