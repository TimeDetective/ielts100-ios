import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject var store: StudyStore
    @EnvironmentObject var speech: SpeechPlayer
    @State private var showTranslation = false
    @State private var selectedWord: Word?
    @State private var unknownWord: String?
    @State private var showGrammar = false
    @State private var showExpanded = false
    @State private var showExercise = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Eyebrow(text: String(format: "SENTENCE %02d / %d", lesson.id, store.course.lessons.count))
                Text(lesson.title).font(.largeTitle.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(lesson.subtitle).font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 20) {
                    Text(linkedSentence).font(.system(size: 27, weight: .regular, design: .serif)).lineSpacing(9).tint(Palette.ink)
                        .environment(\.openURL, OpenURLAction { url in
                            if url.scheme == "lookup", let token = url.host?.removingPercentEncoding { lookup(token); return .handled }; return .systemAction
                        })
                        .accessibilityIdentifier("lesson-sentence")
                    Text("轻点英文单词，查看释义与双音").font(.caption2).foregroundStyle(.secondary)
                    PronounceButtons(text: lesson.sentence)
                    Divider()
                    Button { withAnimation { showTranslation.toggle() } } label: {
                        HStack { Text(showTranslation ? "收起中文翻译" : "先听一遍，再看中文"); Spacer(); Image(systemName: showTranslation ? "chevron.up" : "chevron.down") }.font(.subheadline)
                    }.accessibilityIdentifier("translation-toggle")
                    if showTranslation { Text(lesson.translation).font(.body).lineSpacing(7).foregroundStyle(Palette.ink).accessibilityIdentifier("translation-text") }
                    HStack {
                        Toggle("慢速", isOn: $speech.slow).fixedSize()
                        Spacer()
                        Picker("重复次数", selection: $speech.repetitions) { Text("播放 1 遍").tag(1); Text("播放 3 遍").tag(3) }.labelsHidden()
                    }.font(.caption)
                }.padding(23).background(.white, in: RoundedRectangle(cornerRadius: 24))
                if let correction = lesson.correctionNote {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(correction).font(.subheadline).lineSpacing(6)
                            if let original = lesson.originalSentence { Text("原始英文").font(.caption).foregroundStyle(.secondary); EnglishLine(text: original) }
                            if let originalTranslation = lesson.originalTranslation { Text("原始译文：" + originalTranslation).font(.caption).foregroundStyle(.secondary) }
                            if let source = lesson.correctionURL, let url = URL(string: source) { Link("查看校订依据", destination: url).font(.subheadline) }
                        }.padding(.top, 14)
                    } label: { Label("本句有校订说明", systemImage: "text.badge.checkmark").font(.subheadline.weight(.semibold)) }
                    .padding(18).background(Palette.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
                DisclosureGroup(isExpanded: $showGrammar) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text(lesson.grammar).font(.subheadline).lineSpacing(7).textSelection(.enabled)
                        Text("讲解中的英文 · 点按朗读").font(.caption).foregroundStyle(.secondary)
                        ForEach(englishFragments(lesson.grammar), id: \.self) { fragment in
                            EnglishLine(text: fragment)
                        }
                    }.padding(.top, 16)
                } label: { Label("读懂句子结构", systemImage: "text.alignleft").font(.headline) }
                .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text("核心词汇").font(.title3.weight(.semibold)); Spacer(); Text("\(lesson.coreWords.count) 个词条").font(.caption).foregroundStyle(.secondary) }
                    ForEach(lesson.coreWords) { word in wordRow(word) }
                }
                DisclosureGroup(isExpanded: $showExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groups, id: \.self) { group in
                            Text(group).font(.caption.weight(.semibold)).foregroundStyle(Palette.orange).padding(.top, 12)
                            ForEach(lesson.words.filter { !$0.core && $0.group == group }) { word in wordRow(word) }
                        }
                    }.padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("主题词汇 · 按需探索").font(.headline)
                        Text("另外 \(lesson.words.count - lesson.coreWords.count) 个词条与短语").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                Button { speech.playQueue([lesson.sentence] + lesson.coreWords.map(\.word)) } label: { Label("随身听 · 句子与核心词", systemImage: "headphones").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                Button { showExercise = true } label: { Label("练一练 · 句子填空", systemImage: "pencil.line").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    .accessibilityIdentifier("cloze-open")
                Button { store.complete(lesson) } label: {
                    Label(store.progress.completed.contains(lesson.id) ? "本课已学完" : "标记本课已学完", systemImage: "checkmark.circle").frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("complete-lesson")
                if let next = store.course.lessons.first(where: { $0.id == lesson.id + 1 }) {
                    NavigationLink(destination: LessonView(lesson: next)) { Label("下一课 · " + next.title, systemImage: "arrow.right").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).accessibilityIdentifier("next-lesson")
                }
                Text("课程来源：\(store.course.source)\n英美按钮播放对应地区的系统合成语音。")
                    .font(.caption2).foregroundStyle(.secondary).lineSpacing(5)
            }.padding(24).frame(maxWidth: 680)
        }.background(Palette.paper).navigationTitle("第 \(lesson.id) 课").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleLessonFavorite(lesson) } label: { Image(systemName: store.progress.favoriteLessons.contains(lesson.id) ? "bookmark.fill" : "bookmark") }
                    .accessibilityLabel(store.progress.favoriteLessons.contains(lesson.id) ? "取消收藏本课" : "收藏本课")
            } }
            .onAppear { store.visit(lesson) }
            .sheet(item: $selectedWord) { word in NavigationStack { WordView(word: word) } }
            .sheet(isPresented: Binding(get: { unknownWord != nil }, set: { if !$0 { unknownWord = nil } })) {
                NavigationStack { LookupView(word: unknownWord ?? "", lesson: lesson) }
            }
            .sheet(isPresented: $showExercise) { NavigationStack { ClozeView(lesson: lesson) } }
    }
    var groups: [String] { lesson.words.filter { !$0.core }.map(\.group).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } }
    var linkedSentence: AttributedString {
        var result = AttributedString(lesson.sentence)
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z]+(?:'[A-Za-z]+)?") else { return result }
        for match in regex.matches(in: lesson.sentence, range: NSRange(lesson.sentence.startIndex..., in: lesson.sentence)) {
            if let r = Range(match.range, in: lesson.sentence), let ar = Range(r, in: result) {
                let token = String(lesson.sentence[r]).lowercased()
                result[ar].link = URL(string: "lookup://\(token)")
                result[ar].underlineStyle = nil
            }
        }
        return result
    }
    func lookup(_ token: String) {
        let forms = ["interrupted":"interrupt", "stifled":"stifle", "biologists":"biologist", "sorts":"sort", "wars":"world war"]
        let target = forms[token] ?? token
        if let match = lesson.words.first(where: { $0.word.lowercased() == target }) { selectedWord = match }
        else { unknownWord = token }
    }
    func wordRow(_ word: Word) -> some View {
        Button { selectedWord = word } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(word.word).font(.system(size: 21, weight: .medium, design: .serif)).foregroundStyle(Palette.ink)
                    Text(word.meaning).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 5)
                if let p = store.progress.words[word.id], p.interval > 0 { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityIdentifier("word-\(word.id)")
    }
}
struct EnglishLine: View {
    @EnvironmentObject var speech: SpeechPlayer
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(text).font(.system(.body, design: .serif)).textSelection(.enabled)
            PronounceButtons(text: text)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct WordView: View {
    let word: Word
    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: word.core ? "CORE VOCABULARY" : "EXPLORE MORE")
                Text(word.word).font(.system(size: 37, weight: .medium, design: .serif)).foregroundStyle(Palette.ink).textSelection(.enabled)
                if !word.ipa.isEmpty { Text(word.ipa).foregroundStyle(.secondary); Text("课程音标").font(.caption2).foregroundStyle(.secondary) }
                PronounceButtons(text: word.word)
                Text(word.meaning).font(.title3).lineSpacing(7)
                Divider()
                ForEach(Array(word.notes.enumerated()), id: \.offset) { _, note in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(note).font(.subheadline).lineSpacing(6).textSelection(.enabled)
                        ForEach(englishFragments(note), id: \.self) { EnglishLine(text: $0) }
                    }
                }
                if let lesson = store.course.lessons.first(where: { $0.words.contains(where: { $0.id == word.id }) }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("回到语境 · 第 \(lesson.id) 课").font(.caption).foregroundStyle(.secondary)
                        EnglishLine(text: lesson.sentence)
                    }
                }
                if let p = store.progress.words[word.id] {
                    Text(p.interval > 0 ? "下次复习：\(p.due.formatted(date: .abbreviated, time: .shortened))" : "已加入稍后复习，约 10 分钟后再见。")
                        .font(.caption).foregroundStyle(Palette.green)
                }
                HStack {
                    Button("还不熟悉") { store.mark(word, remembered: false) }.buttonStyle(.bordered)
                    Button("记住了") { store.mark(word, remembered: true) }.buttonStyle(.borderedProminent)
                }.accessibilityIdentifier("word-rating")
                Text("来源：\(store.course.source)\n合成发音需结合词性和语境判断。")
                    .font(.caption2).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(24).frame(maxWidth: 680)
        }.background(Palette.paper).navigationTitle("单词详情").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.toggleWordFavorite(word) } label: { Image(systemName: store.progress.favoriteWords.contains(word.id) ? "star.fill" : "star") }
                        .accessibilityLabel(store.progress.favoriteWords.contains(word.id) ? "取消收藏单词" : "收藏单词")
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
    }
}
struct LookupView: View {
    let word: String
    let lesson: Lesson
    var gloss: SentenceGloss? { lesson.glosses[word.lowercased()] }
    @Environment(\.dismiss) var dismiss
    @State private var showDictionary = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "IN THIS SENTENCE")
                Text(word).font(.system(size: 37, weight: .medium, design: .serif)).foregroundStyle(Palette.ink).textSelection(.enabled)
                if let gloss, gloss.lemma.lowercased() != word.lowercased() {
                    Text("原形：\(gloss.lemma)").font(.subheadline).foregroundStyle(.secondary)
                    PronounceButtons(text: gloss.lemma)
                }
                PronounceButtons(text: word)
                if let gloss {
                    Text(gloss.meaning).font(.title3).lineSpacing(7).accessibilityIdentifier("lookup-meaning")
                    Text(gloss.note).font(.subheadline).lineSpacing(7).foregroundStyle(.secondary).accessibilityIdentifier("lookup-context")
                } else {
                    Text("这个词暂未收录，可使用系统词典查看释义。").foregroundStyle(.secondary)
                }
                Divider()
                Text("回到句子 · 第 \(lesson.id) 课").font(.caption).foregroundStyle(.secondary)
                EnglishLine(text: lesson.sentence)
                Text(lesson.translation).font(.subheadline).lineSpacing(7)
                #if os(iOS)
                Button("更多释义 · 系统词典") { showDictionary = true }.buttonStyle(.bordered)
                    .sheet(isPresented: $showDictionary) { DictionaryView(word: gloss?.lemma ?? word) }
                #endif
                Text(gloss?.source ?? "本页词义与用法说明为 App 补充，按当前句子语境编写；可离线查看。").font(.caption2).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 680, alignment: .leading)
        }.background(Palette.paper).navigationTitle("即时查词").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}
#if os(iOS)
struct DictionaryView: UIViewControllerRepresentable {
    let word: String
    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController { UIReferenceLibraryViewController(term: word) }
    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}
#endif
struct ClozeView: View {
    let lesson: Lesson
    @Environment(\.dismiss) var dismiss
    @State private var answer = ""
    @State private var checked = false
    var target: String { lesson.exerciseAnswer }
    var correct: Bool { answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target.lowercased() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Eyebrow(text: "RECALL, THEN REVEAL")
                Text("把句子补完整").font(.title.bold())
                Text(lesson.sentence.replacingOccurrences(of: target, with: "________")).font(.system(size: 26, design: .serif)).lineSpacing(9)
                Text(lesson.translation).foregroundStyle(.secondary).lineSpacing(6)
                TextField("输入缺少的单词", text: $answer).textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("cloze-answer").onChange(of: answer) { _, _ in checked = false }
                Button("检查答案") { checked = true }.buttonStyle(.borderedProminent).disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("cloze-check")
                if checked {
                    Label(correct ? "答对了！" : "再看一眼：\(target)", systemImage: correct ? "checkmark.circle.fill" : "arrow.counterclockwise")
                        .foregroundStyle(correct ? Palette.green : Palette.orange).accessibilityIdentifier("cloze-result")
                    PronounceButtons(text: lesson.sentence)
                }
            }.padding(24)
        }.background(Palette.paper).navigationTitle("句子练习").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}
