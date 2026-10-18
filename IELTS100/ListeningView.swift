import SwiftUI

struct ListeningView: View {
    @EnvironmentObject var store: StudyStore
    @EnvironmentObject var speech: SpeechPlayer
    @State private var scope = "当前课"
    @State private var includeCore = false
    var lessons: [Lesson] {
        switch scope {
        case "已学": return store.course.lessons.filter { store.progress.completed.contains($0.id) }
        case "收藏": return store.course.lessons.filter { store.progress.favoriteLessons.contains($0.id) }
        case "全部": return store.course.lessons
        default: return store.course.lessons.filter { $0.id == store.progress.lastLesson }
        }
    }
    var texts: [String] { lessons.flatMap { [$0.sentence] + (includeCore ? $0.coreWords.map(\.word) : []) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "LISTEN, AGAIN AND AGAIN")
                Text("让英语陪你走一段。").font(.largeTitle.weight(.semibold)).foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 18) {
                    Picker("播放范围", selection: $scope) { ForEach(["当前课", "已学", "收藏", "全部"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    Toggle("同时听核心词汇", isOn: $includeCore)
                    Picker("口音", selection: $speech.accent) { Text("英国英语").tag("en-GB"); Text("美国英语").tag("en-US") }
                    Toggle("慢速", isOn: $speech.slow)
                    Picker("每项重复", selection: $speech.repetitions) { Text("1 遍").tag(1); Text("3 遍").tag(3) }
                    Text("\(lessons.count) 课 · \(texts.count) 项内容").font(.caption).foregroundStyle(.secondary)
                    Button { speech.playQueue(texts) } label: { Label("开始播放", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 7) }
                        .buttonStyle(.borderedProminent).disabled(texts.isEmpty).accessibilityIdentifier("listening-play")
                    if texts.isEmpty { Text("这个范围还没有课程。先去学习或收藏一句话吧。").font(.caption).foregroundStyle(.secondary) }
                }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 22))
                if speech.speaking {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack { Label(speech.paused ? "已暂停" : "正在播放", systemImage: "waveform").font(.caption); Spacer(); Text("\(speech.itemIndex + 1) / \(max(1, speech.itemCount))").font(.caption) }.foregroundStyle(.secondary)
                        Text(speech.nowPlaying).font(.system(size: 24, design: .serif)).lineSpacing(7).foregroundStyle(Palette.ink)
                        ProgressView(value: Double(speech.itemIndex), total: Double(max(1, speech.itemCount)))
                        HStack(spacing: 28) {
                            Button { speech.previous() } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("上一项")
                            Button { speech.paused ? speech.resume() : speech.pause() } label: { Image(systemName: speech.paused ? "play.circle.fill" : "pause.circle.fill").font(.system(size: 46)) }.accessibilityLabel(speech.paused ? "继续播放" : "暂停播放")
                            Button { speech.next() } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("播放下一项")
                            Spacer()
                            Button { speech.stop() } label: { Image(systemName: "stop.fill") }.accessibilityLabel("停止播放")
                        }.font(.title3).buttonStyle(.plain)
                    }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
                Text("支持顺序播放、暂停和切换。发音为系统合成语音；声音下载完成后可离线听。锁屏后可通过系统播放控件操作，具体后台与耳机体验请在真机上确认。")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(6)
            }.padding(24).frame(maxWidth: 680)
        }.background(Palette.paper).navigationTitle("随身听").navigationBarTitleDisplayMode(.inline)
    }
}
