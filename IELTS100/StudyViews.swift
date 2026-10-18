import SwiftUI
import UniformTypeIdentifiers

struct VocabularyView: View {
    @EnvironmentObject var store: StudyStore
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var vocabularyFilter = "全部"
    @State private var lessonFilter = 0
    @State private var selected: Word?
    var filtered: [Word] {
        let source = lessonFilter == 0 ? store.allWords : (store.course.lessons.first { $0.id == lessonFilter }?.words ?? [])
        return source.filter { word in
            let match = vocabularyFilter == "全部" || (vocabularyFilter == "核心" && word.core) || (vocabularyFilter == "收藏" && store.progress.favoriteWords.contains(word.id)) || (vocabularyFilter == "待复习" && (store.progress.words[word.id]?.due ?? .distantFuture) <= store.now)
            return match && (search.isEmpty || word.word.localizedCaseInsensitiveContains(search) || word.meaning.contains(search) || word.notes.contains(where: { $0.localizedCaseInsensitiveContains(search) }))
        }
    }
    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索单词或中文释义", text: $search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("vocabulary-search").focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                }.padding(.vertical, 6)
                Picker("词库范围", selection: $vocabularyFilter) { ForEach(["全部", "核心", "收藏", "待复习"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Picker("来源课程", selection: $lessonFilter) {
                    Text("全部课程").tag(0)
                    ForEach(store.course.lessons) { Text("第 \($0.id) 课 · \($0.title)").tag($0.id) }
                }
                Text("\(filtered.count) 个词条 · 支持中英文搜索").font(.caption).foregroundStyle(.secondary)
            }
            if filtered.isEmpty { ContentUnavailableView("没有匹配的词条", systemImage: "magnifyingglass", description: Text("可搜索英文、中文或词条中的搭配。")) }
            ForEach(filtered) { word in
                Button { selected = word } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(word.word).font(.system(size: 21, design: .serif)).foregroundStyle(Palette.ink)
                            Text(word.meaning).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        if store.progress.favoriteWords.contains(word.id) { Image(systemName: "star.fill").font(.caption).foregroundStyle(Palette.orange) }
                        Text("\(word.page) 页").font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.accessibilityIdentifier("vocab-\(word.id)")
            }
        }.scrollContentBackground(.hidden).background(Palette.paper).navigationTitle("随身词库")
            .sheet(item: $selected) { word in NavigationStack { WordView(word: word) } }
    }
}
struct ReviewView: View {
    @EnvironmentObject var store: StudyStore
    @EnvironmentObject var speech: SpeechPlayer
    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var started = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Eyebrow(text: "MAKE IT STICK")
                Text("记得住，才算学会。").font(.largeTitle.weight(.semibold)).foregroundStyle(Palette.ink)
                if !started {
                    Text("先复习到期的词，再练习已打开课程中还没记过的核心词。每轮最多 10 个，想起来后再翻答案。")
                        .foregroundStyle(.secondary).lineSpacing(7)
                    HStack(spacing: 20) {
                        metric("\(store.dueWords.count)", "到期词条")
                        metric("\(store.reviewWords.count)", "本轮词条")
                    }
                    Button { queue = store.reviewWords; index = 0; revealed = false; started = true } label: {
                        Label("开始本轮复习", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(store.reviewWords.isEmpty).accessibilityIdentifier("review-start")
                    if store.reviewWords.isEmpty { Text("当前课程的核心词已完成。可以学习新课程，或到词库里学习主题词汇。 ").foregroundStyle(.secondary) }
                } else if index < queue.count {
                    let word = queue[index]
                    ProgressView(value: Double(index), total: Double(queue.count)).tint(Palette.green)
                    Text("\(index + 1) / \(queue.count)").font(.caption).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 24) {
                        Text(word.word).font(.system(size: 36, design: .serif)).foregroundStyle(Palette.ink)
                        PronounceButtons(text: word.word)
                        if revealed {
                            Text(word.meaning).font(.title3).lineSpacing(7).accessibilityIdentifier("review-meaning")
                            if !word.ipa.isEmpty { Text(word.ipa).foregroundStyle(.secondary) }
                            HStack {
                                Button("再学一次") { advance(word, remembered: false) }.buttonStyle(.bordered)
                                Spacer()
                                Button("记住了") { advance(word, remembered: true) }.buttonStyle(.borderedProminent)
                            }
                        } else {
                            Text("先回忆中文含义，再翻开答案。").foregroundStyle(.secondary)
                            Button("显示答案") { revealed = true }.buttonStyle(.bordered).accessibilityIdentifier("review-reveal")
                        }
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 24))
                    Button("结束本轮") { started = false; speech.stop() }.font(.subheadline)
                } else {
                    Image(systemName: "checkmark.seal").font(.system(size: 56)).foregroundStyle(Palette.green)
                    Text(queue.isEmpty ? "暂时没有待复习内容" : "这一轮，完成了。").font(.title2.bold())
                    Text("记住的词按 1、3、6、12 天等间隔复习，最长 30 天；不熟悉的词约 10 分钟后再出现。")
                        .foregroundStyle(.secondary).lineSpacing(6)
                    Button("返回复习首页") { started = false }.buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(maxWidth: 680)
        }.background(Palette.paper).navigationTitle("间隔复习").navigationBarTitleDisplayMode(.inline)
    }
    func advance(_ word: Word, remembered: Bool) { store.mark(word, remembered: remembered); speech.stop(); index += 1; revealed = false }
    func metric(_ n: String, _ caption: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(n).font(.largeTitle).foregroundStyle(Palette.green); Text(caption).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 18)) }
}
struct SettingsView: View {
    @EnvironmentObject var store: StudyStore
    @EnvironmentObject var speech: SpeechPlayer
    @AppStorage("study.dailyGoal") private var dailyGoal = 1
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: Data?
    @State private var confirmImport = false
    @State private var message: String?
    var body: some View {
        Form {
            Section("每天学一点") {
                Stepper("每日目标：\(dailyGoal) 课", value: $dailyGoal, in: 1...10)
                LabeledContent("连续学习", value: "\(store.streak) 天")
                LabeledContent("今日完成", value: "\(store.completedToday) 课")
            }
            Section("发音偏好") {
                Picker("默认口音", selection: $speech.accent) { Text("英国英语").tag("en-GB"); Text("美国英语").tag("en-US") }
                Toggle("慢速朗读", isOn: $speech.slow)
                Picker("重复次数", selection: $speech.repetitions) { Text("1 遍").tag(1); Text("3 遍").tag(3) }
                PronounceButtons(text: "A little progress, every day.")
                voiceRow("英国英语", "en-GB")
                voiceRow("美国英语", "en-US")
                Button(speech.loadingVoices ? "正在刷新声音…" : "刷新声音列表") { speech.refreshVoices() }.disabled(speech.loadingVoices || speech.speaking)
            }
            Section("声音与离线使用") {
                Text("所有发音均为 Apple 系统合成语音，不是人工录音。应用优先使用本机可用的高质量声音。")
                Text("缺少声音时，请到系统设置 → 辅助功能，查找朗读与语音相关设置，下载英国和美国英语声音。不同系统版本的名称可能不同。")
                Text("首次下载需要网络。之后请在飞行模式下测试两种口音；离线可用性取决于本机安装的声音。")
            }.font(.subheadline)
            Section("学习记录") {
                Text("记录保存在本机。更新安装请保留相同的 App 标识；卸载前先导出备份。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("导出学习备份") { exporting = true }
                Button("恢复学习备份") { importing = true }
            }
            Section("关于 100句") {
                LabeledContent("课程", value: "当前 \(store.course.lessons.count) 课")
                LabeledContent("课程词条与短语", value: "\(store.allWords.count) 个")
                LabeledContent("句子练习", value: "\(store.course.lessons.count) 道")
                LabeledContent("版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                Text(store.course.source)
                    .font(.caption).foregroundStyle(.secondary)
                Text("仅供非商业学习交流。按现状提供，不保证学习效果；使用风险与后果由使用者自行承担，法律另有规定的除外。与 Apple、雅思考试机构及出版社无官方关联。")
                    .font(.caption).foregroundStyle(.secondary)
                Link("项目非商业许可", destination: URL(string: "https://polyformproject.org/licenses/noncommercial/1.0.0")!)
                Link("完整免责声明", destination: URL(string: "https://github.com/TimeDetective/ielts100-ios/blob/main/DISCLAIMER.md")!)
            }
            Section("离线词典与许可") {
                Text("演示课程词义由项目编写。若自行添加 ECDICT 数据，请保留其 MIT 许可。第三方资料不受本项目非商业许可重新授权。").font(.caption).foregroundStyle(.secondary)
                Link("ECDICT · skywind3000", destination: URL(string: "https://github.com/skywind3000/ECDICT")!)
                DisclosureGroup("MIT License") {
                    Text((Bundle.main.url(forResource: "ECDICT-LICENSE", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "MIT License · skywind3000/ECDICT")
                        .font(.caption2).textSelection(.enabled)
                }
            }
        }.scrollContentBackground(.hidden).background(Palette.paper).navigationTitle("学习设置")
            .fileExporter(isPresented: $exporting, document: BackupDocument(data: store.export()), contentType: .json, defaultFilename: "100句-学习备份") { result in
                switch result { case .success: message = "备份已保存。"; case .failure(let e): message = e.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    pendingImport = try Data(contentsOf: url); confirmImport = true
                } catch { message = "无法读取备份：\(error.localizedDescription)" }
            }
            .confirmationDialog("用备份替换当前学习记录？", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("恢复备份", role: .destructive) {
                    do { if let data = pendingImport { try store.restore(data); message = "学习记录已恢复。" } }
                    catch { message = "备份格式无效，当前记录未更改。" }
                    pendingImport = nil
                }
                Button("取消", role: .cancel) { pendingImport = nil }
            }
            .alert("学习备份", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") { message = nil } } message: { Text(message ?? "") }
    }
    func voiceRow(_ label: String, _ language: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(speech.voice(language).map { "\($0.name) · \($0.quality.rawValue > 1 ? "高质量" : "标准")" } ?? (speech.loadingVoices ? "正在加载…" : "未安装"))
                .font(.caption).foregroundStyle(speech.voice(language) == nil ? Palette.orange : Palette.green)
        }
    }
}
