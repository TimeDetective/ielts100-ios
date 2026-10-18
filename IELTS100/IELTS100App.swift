import SwiftUI

@main struct IELTS100App: App {
    @StateObject private var store = StudyStore()
    @StateObject private var speech = SpeechPlayer()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(speech)
                .tint(Palette.green).preferredColorScheme(.light)
        }
    }
}
enum StudyTab: String, CaseIterable {
    case learn = "学习", vocabulary = "词库", review = "复习", settings = "设置"
    var icon: String {
        switch self { case .learn: return "book.closed"; case .vocabulary: return "character.book.closed"; case .review: return "rectangle.on.rectangle.angled"; case .settings: return "slider.horizontal.3" }
    }
}
struct RootView: View {
    @EnvironmentObject var speech: SpeechPlayer
    @EnvironmentObject var store: StudyStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: StudyTab = .learn
    var body: some View {
        ZStack {
            switch selected {
            case .learn: NavigationStack { HomeView() }
            case .vocabulary: NavigationStack { VocabularyView() }
            case .review: NavigationStack { ReviewView() }
            case .settings: NavigationStack { SettingsView() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if speech.speaking {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform").foregroundStyle(Palette.green)
                        Text(speech.nowPlaying.isEmpty ? "正在准备声音…" : speech.nowPlaying).font(.caption).lineLimit(1)
                        Spacer(minLength: 0)
                        Button { speech.paused ? speech.resume() : speech.pause() } label: { Image(systemName: speech.paused ? "play.fill" : "pause.fill") }
                            .accessibilityLabel(speech.paused ? "继续朗读" : "暂停朗读")
                        if speech.itemCount > 1 {
                            Button { speech.next() } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("下一项")
                        }
                        Button("停止", systemImage: "stop.fill") { speech.stop() }.labelStyle(.iconOnly).accessibilityLabel("停止朗读")
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                }
                Divider()
                HStack(spacing: 0) {
                    ForEach(StudyTab.allCases, id: \.self) { tab in
                        Button { selected = tab } label: {
                            VStack(spacing: 5) {
                                Image(systemName: tab.icon).font(.system(size: 21))
                                Text(tab.rawValue).font(.caption2.weight(selected == tab ? .semibold : .regular))
                            }.frame(maxWidth: .infinity).padding(.vertical, 12)
                                .foregroundStyle(selected == tab ? Palette.green : .secondary)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(tab.rawValue)
                            .accessibilityIdentifier("tab-\(tab)")
                            .accessibilityAddTraits(selected == tab ? .isSelected : [])
                    }
                }
            }.background(.regularMaterial)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in store.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refresh(); speech.refreshVoices() } }
        .alert("发音提示", isPresented: Binding(get: { speech.error != nil }, set: { if !$0 { speech.error = nil } })) {
            Button("知道了") { speech.error = nil }
        } message: { Text(speech.error ?? "") }
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.orange) }
}
struct HomeView: View {
    @EnvironmentObject var store: StudyStore
    @AppStorage("study.dailyGoal") private var dailyGoal = 1
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var filter = "全部"
    var visibleLessons: [Lesson] {
        store.course.lessons.filter { lesson in
            let matchesFilter = filter == "全部" || (filter == "未学" && !store.progress.completed.contains(lesson.id)) || (filter == "已学" && store.progress.completed.contains(lesson.id)) || (filter == "收藏" && store.progress.favoriteLessons.contains(lesson.id))
            return matchesFilter && (search.isEmpty || String(lesson.id) == search || lesson.title.localizedCaseInsensitiveContains(search) || lesson.subtitle.localizedCaseInsensitiveContains(search) || lesson.sentence.localizedCaseInsensitiveContains(search) || lesson.translation.contains(search))
        }
    }
    var resumeLesson: Lesson? {
        let last = store.course.lessons.first { $0.id == store.progress.lastLesson }
        if let last, !store.progress.completed.contains(last.id) { return last }
        return store.course.lessons.first { !store.progress.completed.contains($0.id) } ?? last
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("100句", systemImage: "leaf").font(.headline).foregroundStyle(Palette.green)
                    Spacer()
                    Text("\(store.course.lessons.count) 课 · 原创演示").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "A LITTLE, EVERY DAY")
                    Text("把英语，\n一句句学会。").font(.system(size: 35, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink).lineSpacing(5)
                    Text("从听懂一句话开始，让单词有来处。").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    stat("\(store.progress.completed.count) / \(store.course.lessons.count)", "已学课程")
                    Divider().frame(height: 34)
                    stat("\(store.learnedCount)", "已记住词条")
                    Divider().frame(height: 34)
                    stat("\(store.dueWords.count)", "到期复习")
                }.padding(.vertical, 20).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
                if let lesson = resumeLesson {
                    NavigationLink(destination: LessonView(lesson: lesson)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("继续学习 · 第 \(lesson.id) 课").font(.caption).opacity(0.8)
                                Text(lesson.title).font(.title3.weight(.semibold))
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.title2)
                        }.padding(23).foregroundStyle(.white).background(Palette.green, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityIdentifier("continue-learning")
                }
                NavigationLink(destination: ListeningView()) {
                    HStack { Label("随身听 · 把句子带在身边", systemImage: "headphones"); Spacer(); Image(systemName: "arrow.right") }.font(.subheadline).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).foregroundStyle(Palette.green).accessibilityIdentifier("listening-open")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("今日目标", systemImage: "sun.max").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(store.completedToday) / \(dailyGoal) 课").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(min(store.completedToday, dailyGoal)), total: Double(dailyGoal)).tint(Palette.green)
                    Text("连续学习 \(store.streak) 天 · 每天学一点，也很好。").font(.caption).foregroundStyle(.secondary)
                }.padding(19).background(.white, in: RoundedRectangle(cornerRadius: 18))
                HStack {
                    Text("你的句子课程").font(.title3.weight(.semibold))
                    Spacer()
                    Menu {
                        ForEach(0..<10) { chapter in
                            Menu("第 \(chapter * 10 + 1)–\(chapter * 10 + 10) 课") {
                                ForEach(store.course.lessons.filter { ((chapter * 10 + 1)...(chapter * 10 + 10)).contains($0.id) }) { lesson in
                                    NavigationLink("\(lesson.id). \(lesson.title)", destination: LessonView(lesson: lesson))
                                }
                            }
                        }
                    } label: { Label("跳到", systemImage: "list.number").font(.caption) }
                }
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索课号、主题或句子", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("course-search").focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                    if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("清除课程搜索") }
                }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14))
                Picker("课程范围", selection: $filter) { ForEach(["全部", "未学", "已学", "收藏"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                LazyVStack(spacing: 14) {
                    ForEach(visibleLessons) { lesson in
                        NavigationLink(destination: LessonView(lesson: lesson)) {
                            HStack(alignment: .top, spacing: 17) {
                                Text(String(format: "%02d", lesson.id)).font(.system(size: 31, weight: .light, design: .serif)).foregroundStyle(Palette.orange)
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text(lesson.title).font(.headline).foregroundStyle(Palette.ink)
                                        Spacer()
                                        if store.progress.favoriteLessons.contains(lesson.id) { Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Palette.orange) }
                                        Image(systemName: store.progress.completed.contains(lesson.id) ? "checkmark.circle.fill" : "arrow.right").foregroundStyle(Palette.green)
                                    }
                                    Text(lesson.subtitle).font(.caption).foregroundStyle(.secondary)
                                    Text("\(lesson.coreWords.count) 个核心词条  ·  \(lesson.words.count) 个词条及短语").font(.caption2).foregroundStyle(Palette.green)
                                }
                            }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityIdentifier("lesson-\(lesson.id)")
                    }
                    if visibleLessons.isEmpty { ContentUnavailableView("没有匹配的课程", systemImage: "magnifyingglass", description: Text("试试课号、中文主题或英文关键词。")) }
                }
                Text("原创演示 \(store.course.lessons.count) 课 · \(store.allWords.count) 个词条\n可在本地替换为拥有使用权的课程数据。发音为系统合成语音。")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(5)
            }.padding(24).frame(maxWidth: 680)
        }.background(Palette.paper).toolbar(.hidden, for: .navigationBar)
    }
    func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) { Text(value).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink); Text(label).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
}
