import XCTest
import AVFoundation
@testable import IELTS100

final class StudyTests: XCTestCase {
    @MainActor func testBritishAndAmericanSpeechSynthesis() async throws {
        for language in ["en-GB", "en-US"] {
            guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == language }) else {
                throw XCTSkip("Simulator has no voice installed for \(language); verify after downloading voices")
            }
            let synthesizer = AVSpeechSynthesizer()
            let utterance = AVSpeechUtterance(string: "A little progress, every day.")
            utterance.voice = voice
            let rendered = expectation(description: "PCM audio for \(language)")
            rendered.assertForOverFulfill = false
            synthesizer.write(utterance) { buffer in
                if let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 { rendered.fulfill() }
            }
            await fulfillment(of: [rendered], timeout: 30)
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    @MainActor func testEverySentenceWordHasContextualTranslation() throws {
        let store = StudyStore()
        let regex = try NSRegularExpression(pattern: "[A-Za-z]+(?:'[A-Za-z]+)?")
        for lesson in store.course.lessons {
            let sentence = lesson.sentence.lowercased()
            let tokens = Set(regex.matches(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)).compactMap { match -> String? in
                guard let range = Range(match.range, in: sentence) else { return nil }
                return String(sentence[range])
            })
            XCTAssertEqual(tokens, Set(lesson.glosses.keys), "Every tappable word needs a translation")
            for gloss in lesson.glosses.values {
                XCTAssertFalse(gloss.lemma.isEmpty)
                XCTAssertFalse(gloss.meaning.isEmpty)
                XCTAssertFalse(gloss.note.isEmpty)
            }
        }
        XCTAssertTrue(store.course.lessons[0].glosses["every"]!.meaning.contains("每"))
        XCTAssertEqual(store.course.lessons[2].glosses["asking"]!.lemma, "ask")
    }
    func testShortEnglishFragmentsRemainSpeakable() {
        XCTAssertTrue(englishFragments("【同义】go v. 去").contains("go"))
        XCTAssertTrue(englishFragments("I 我").contains("I"))
        XCTAssertFalse(englishFragments("adj. 形容词").contains("adj"))
    }
    @MainActor func testCourseIntegrity() throws {
        let store = StudyStore()
        XCTAssertEqual(store.course.lessons.count, 3)
        XCTAssertEqual(store.allWords.count, 18)
        XCTAssertEqual(Set(store.allWords.map(\.id)).count, 18)
        XCTAssertEqual(store.course.lessons.flatMap(\.coreWords).count, 18)
        for word in store.allWords {
            XCTAssertFalse(word.meaning.isEmpty, word.word)
            XCTAssertFalse(word.word.contains("  "), word.word)
            XCTAssertTrue(word.page == 0)
        }
    }
    @MainActor func testReviewScheduleAndBackupRoundtrip() throws {
        let store = StudyStore()
        let original = store.export()
        defer { try? store.restore(original) }
        store.progress = Backup()
        let word = store.allWords[0]
        XCTAssertEqual(store.reviewWords.count, 6)
        store.mark(word, remembered: true)
        XCTAssertEqual(store.progress.words[word.id]?.interval, 1)
        XCTAssertFalse(store.reviewWords.contains(where: { $0.id == word.id }))
        store.mark(word, remembered: true)
        XCTAssertEqual(store.progress.words[word.id]?.interval, 3)
        store.mark(word, remembered: true)
        XCTAssertEqual(store.progress.words[word.id]?.interval, 6)
        let exported = store.export()
        store.progress = Backup()
        try store.restore(exported)
        XCTAssertEqual(store.progress.words[word.id]?.interval, 6)
        store.mark(word, remembered: false)
        XCTAssertEqual(store.progress.words[word.id]?.interval, 0)
        XCTAssertEqual(store.learnedCount, 0)
        XCTAssertEqual(store.dueWords.count, 0)
        store.progress.words[word.id]?.due = Date().addingTimeInterval(-1)
        XCTAssertEqual(store.dueWords.first?.id, word.id)
    }
    @MainActor func testFavoritesGoalsAndLegacyBackup() throws {
        let store = StudyStore()
        let original = store.export()
        defer { try? store.restore(original) }
        store.progress = Backup()
        let first = store.course.lessons[0]
        let last = store.course.lessons[2]
        let word = first.words[0]
        store.toggleWordFavorite(word)
        store.toggleLessonFavorite(last)
        store.complete(first)
        XCTAssertEqual(store.completedToday, 1)
        XCTAssertEqual(store.streak, 1)
        store.complete(first)
        XCTAssertEqual(store.completedToday, 1)
        let data = store.export()
        store.progress = Backup()
        try store.restore(data)
        XCTAssertTrue(store.progress.favoriteWords.contains(word.id))
        XCTAssertTrue(store.progress.favoriteLessons.contains(3))
        // Original sample backups did not have favorites, visited lessons or activity.
        let legacy = Data(#"{"version":1,"completed":[1],"words":{"1-1":{"interval":1,"due":800000000,"reviews":1}},"lastLesson":3}"#.utf8)
        try store.restore(legacy)
        XCTAssertEqual(store.progress.lastLesson, 3)
        XCTAssertEqual(store.progress.words["1-1"]?.reviews, 1)
        XCTAssertTrue(store.progress.visited.contains(3))
        XCTAssertTrue(store.progress.favoriteWords.isEmpty)
    }
    @MainActor func testAllExercisesAndCorrections() throws {
        let store = StudyStore()
        XCTAssertEqual(store.course.lessons.map(\.id), Array(1...3))
        for lesson in store.course.lessons {
            XCTAssertFalse(lesson.exerciseAnswer.isEmpty)
            XCTAssertTrue(lesson.sentence.contains(lesson.exerciseAnswer), "Lesson \(lesson.id)")
            XCTAssertTrue(lesson.startPage <= lesson.endPage)
            XCTAssertFalse(lesson.grammar.isEmpty)
            XCTAssertFalse(lesson.translation.isEmpty)
            XCTAssertFalse(lesson.coreWords.isEmpty)
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "ECDICT-LICENSE", withExtension: "txt"))
    }
    @MainActor func testPlaybackQueuePauseAndCancellation() async throws {
        let player = SpeechPlayer()
        for _ in 0..<100 {
            if !player.loadingVoices { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard player.voice("en-GB") != nil else { throw XCTSkip("British voice unavailable") }
        player.playQueue(["A little practice every day can build lasting confidence.", "We compare two voices and listen for small differences."])
        XCTAssertTrue(player.speaking)
        XCTAssertEqual(player.itemCount, 2)
        player.pause()
        XCTAssertTrue(player.paused)
        player.resume()
        XCTAssertFalse(player.paused)
        player.next()
        XCTAssertEqual(player.itemIndex, 1)
        player.previous()
        XCTAssertEqual(player.itemIndex, 0)
        player.stop()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(player.speaking, "A stale speech callback must not restart the player")
        XCTAssertEqual(player.itemCount, 0)
    }
    @MainActor func testRejectInvalidBackupWithoutChangingProgress() throws {
        let store = StudyStore()
        let original = store.export()
        var invalid = Backup()
        invalid.words["not-a-word"] = WordProgress(interval: 1, due: Date(), reviews: 1)
        XCTAssertThrowsError(try store.restore(JSONEncoder().encode(invalid)))
        XCTAssertEqual(store.export(), original)
    }
}
