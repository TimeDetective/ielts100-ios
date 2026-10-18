import SwiftUI
import UniformTypeIdentifiers

struct Course: Codable { let title: String; let source: String; let lessons: [Lesson]; let dictionaryAttribution: String? }
struct SentenceGloss: Codable {
    let lemma: String
    let meaning: String
    let note: String
    let source: String?
}
struct Lesson: Codable, Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let sentence: String
    let translation: String
    let grammar: String
    let startPage: Int
    let endPage: Int
    let words: [Word]
    let glosses: [String: SentenceGloss]
    let exerciseAnswer: String
    let originalSentence: String?
    let originalTranslation: String?
    let correctionNote: String?
    let correctionURL: String?
    var coreWords: [Word] { words.filter(\.core) }
}
struct Word: Codable, Identifiable {
    let id: String
    let word: String
    let ipa: String
    let meaning: String
    let notes: [String]
    let core: Bool
    let group: String
    let page: Int
}
struct WordProgress: Codable {
    var interval: Int
    var due: Date
    var reviews: Int
}
struct Backup: Codable {
    var version = 1
    var completed: Set<Int> = []
    var words: [String: WordProgress] = [:]
    var lastLesson = 1
    var visited: Set<Int> = [1]
    var favoriteWords: Set<String> = []
    var favoriteLessons: Set<Int> = []
    var activity: [String: Int] = [:]
    var completionDates: [Int: Date] = [:]
    init() {}
    enum CodingKeys: String, CodingKey { case version, completed, words, lastLesson, visited, favoriteWords, favoriteLessons, activity, completionDates }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        completed = try c.decode(Set<Int>.self, forKey: .completed)
        words = try c.decode([String: WordProgress].self, forKey: .words)
        lastLesson = try c.decode(Int.self, forKey: .lastLesson)
        visited = try c.decodeIfPresent(Set<Int>.self, forKey: .visited) ?? completed.union([lastLesson, 1])
        favoriteWords = try c.decodeIfPresent(Set<String>.self, forKey: .favoriteWords) ?? []
        favoriteLessons = try c.decodeIfPresent(Set<Int>.self, forKey: .favoriteLessons) ?? []
        activity = try c.decodeIfPresent([String: Int].self, forKey: .activity) ?? [:]
        completionDates = try c.decodeIfPresent([Int: Date].self, forKey: .completionDates) ?? [:]
    }
}
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
@MainActor final class StudyStore: ObservableObject {
    let course: Course
    let allWords: [Word]
    let wordIndex: [String: Word]
    private let defaults: UserDefaults
    @Published var now = Date()
    @Published var progress: Backup { didSet { persist() } }
    init() {
        defaults = ProcessInfo.processInfo.arguments.contains("--uitesting") ? UserDefaults(suiteName: "IELTS100.UITests")! : .standard
        if ProcessInfo.processInfo.arguments.contains("--reset-progress") { defaults.removeObject(forKey: "study.backup.v1") }
        do {
            guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            course = try JSONDecoder().decode(Course.self, from: Data(contentsOf: url))
        } catch { fatalError("课程数据无法加载：\(error)") }
        allWords = course.lessons.flatMap(\.words)
        wordIndex = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        if let data = defaults.data(forKey: "study.backup.v1"), let decoded = try? JSONDecoder().decode(Backup.self, from: data) { progress = decoded }
        else { progress = Backup() }
    }
    var learnedCount: Int { progress.words.values.filter { $0.interval > 0 }.count }
    var dueWords: [Word] { allWords.filter { if let p = progress.words[$0.id] { return p.due <= now }; return false } }
    var reviewWords: [Word] {
        let due = dueWords.sorted { progress.words[$0.id]!.due < progress.words[$1.id]!.due }
        let fresh = course.lessons.filter { progress.visited.contains($0.id) }.flatMap(\.coreWords).filter { progress.words[$0.id] == nil }
        return Array((due + fresh).prefix(10))
    }
    var completedToday: Int { progress.completionDates.values.filter { Calendar.current.isDate($0, inSameDayAs: now) }.count }
    var recentLessons: [Lesson] { course.lessons.filter { progress.visited.contains($0.id) } }
    func refresh() { now = Date() }
    func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    var streak: Int {
        var date = now; var count = 0
        if progress.activity[dayKey(date), default: 0] == 0 { date = Calendar.current.date(byAdding: .day, value: -1, to: date)! }
        while progress.activity[dayKey(date), default: 0] > 0 {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }
    func mark(_ word: Word, remembered: Bool) {
        refresh()
        let old = progress.words[word.id]
        let interval = remembered ? (old?.interval == 1 ? 3 : (old?.interval ?? 0) >= 3 ? min((old?.interval ?? 3) * 2, 30) : 1) : 0
        let due = remembered ? Calendar.current.date(byAdding: .day, value: interval, to: now)! : now.addingTimeInterval(10 * 60)
        progress.words[word.id] = WordProgress(interval: interval, due: due, reviews: (old?.reviews ?? 0) + 1)
        progress.activity[dayKey(now), default: 0] += 1
    }
    func complete(_ lesson: Lesson) {
        refresh()
        if progress.completed.insert(lesson.id).inserted {
            progress.completionDates[lesson.id] = now
            progress.activity[dayKey(now), default: 0] += 1
        }
        progress.visited.insert(lesson.id)
    }
    func visit(_ lesson: Lesson) {
        refresh(); progress.lastLesson = lesson.id; progress.visited.insert(lesson.id)
    }
    func toggleWordFavorite(_ word: Word) {
        if progress.favoriteWords.contains(word.id) { progress.favoriteWords.remove(word.id) } else { progress.favoriteWords.insert(word.id) }
    }
    func toggleLessonFavorite(_ lesson: Lesson) {
        if progress.favoriteLessons.contains(lesson.id) { progress.favoriteLessons.remove(lesson.id) } else { progress.favoriteLessons.insert(lesson.id) }
    }
    func persist() { if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: "study.backup.v1") } }
    func export() -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return (try? encoder.encode(progress)) ?? Data() }
    func restore(_ data: Data) throws {
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        let ids = Set(allWords.map(\.id)); let lessons = Set(course.lessons.map(\.id))
        guard backup.version == 1,
              backup.completed.isSubset(of: lessons), lessons.contains(backup.lastLesson),
              backup.visited.isSubset(of: lessons), backup.favoriteLessons.isSubset(of: lessons),
              backup.favoriteWords.isSubset(of: ids), Set(backup.words.keys).isSubset(of: ids),
              Set(backup.completionDates.keys).isSubset(of: lessons),
              backup.words.values.allSatisfy({ (0...30).contains($0.interval) && $0.reviews > 0 && $0.due.timeIntervalSince1970.isFinite }),
              backup.activity.values.allSatisfy({ $0 >= 0 && $0 <= 1_000_000 })
        else { throw CocoaError(.coderReadCorrupt) }
        progress = backup; refresh()
    }
}
enum Palette {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let ink = Color(red: 0.13, green: 0.22, blue: 0.20)
    static let green = Color(red: 0.17, green: 0.36, blue: 0.29)
    static let orange = Color(red: 0.73, green: 0.36, blue: 0.20)
}
func englishFragments(_ source: String) -> [String] {
    let text = source.replacingOccurrences(of: #"\b(?:adj|adv|vt|vi|prep|pron|conj|art|num|n|v)\."#, with: "", options: .regularExpression)
    let pattern = "[A-Za-z][A-Za-z’'0-9]*(?:[ \\t.,—…()/-]+[A-Za-z][A-Za-z’'0-9]*)*"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    var seen = Set<String>()
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
        guard let range = Range($0.range, in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !["n", "v", "vi", "vt", "adj", "adv", "prep", "pron", "conj", "art", "num", "Sentence"].contains(value), seen.insert(value).inserted else { return nil }
        return value
    }
}
