import XCTest

/// Covers the last thing that touches a transcript before it is typed into the
/// user's app. A bug here silently deletes words the user actually said.
final class TranscriptionOutputFilterTests: XCTestCase {
    private func filter(_ s: String) -> String { TranscriptionOutputFilter.filter(s) }
    private func removeFillers(_ s: String) -> String {
        TranscriptionOutputFilter.removeStandaloneFillers(s)
    }

    /// Mirrors `AppState.cleanupWithRawFallback` after a successful LLM pass:
    /// trim, then `transcriptWithoutStandaloneFillers`.
    private func liveCleanupOutput(_ s: String) -> String {
        let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = TranscriptionOutputFilter.removeStandaloneFillers(cleaned)
        return filtered.isEmpty ? cleaned : filtered
    }

    func testRemovesStandaloneFillerVocalizations() {
        XCTAssertEqual(
            removeFillers("Um, this is uh a test. Ugh! It works erm now."),
            "this is a test. It works now."
        )
        XCTAssertEqual(removeFillers("AH... well, hmm, yes."), "well, yes.")
    }

    func testFillerRemovalDoesNotDamageMeaningfulWords() {
        XCTAssertEqual(
            removeFillers("The U-Haul reached Birmingham and Ahmet said ahoy."),
            "The U-Haul reached Birmingham and Ahmet said ahoy."
        )
    }

    func testFillerRemovalPreservesBlankLinesBetweenBullets() {
        let dictated = """
        - First item

        - Second item

        - Third item
        """
        XCTAssertEqual(removeFillers(dictated), dictated)
        XCTAssertEqual(
            liveCleanupOutput(dictated),
            dictated
        )
    }

    func testFillerRemovalPreservesBlankLinesBetweenBlocks() {
        let dictated = """
        First paragraph.

        Second paragraph.

        Third paragraph.
        """
        XCTAssertEqual(removeFillers(dictated), dictated)
        XCTAssertEqual(liveCleanupOutput(dictated), dictated)
    }

    func testFillerRemovalCollapsesHorizontalWhitespaceWithoutTouchingNewlines() {
        XCTAssertEqual(removeFillers("hello    world"), "hello world")
        XCTAssertEqual(removeFillers("hello\t\tworld"), "hello world")
        XCTAssertEqual(
            removeFillers("hello  \n\n  world"),
            "hello \n\n world"
        )
    }

    func testFillerRemovalKeepsBlankLinesAfterDeletingFillers() {
        let dictated = """
        - First um item

        - Second uh item
        """
        let expected = """
        - First item

        - Second item
        """
        XCTAssertEqual(removeFillers(dictated), expected)
        XCTAssertEqual(liveCleanupOutput(dictated), expected)
    }

    // MARK: - Hallucination artifacts it exists to remove

    func testRemovesBracketedHallucinations() {
        XCTAssertEqual(filter("[BLANK_AUDIO] hello there"), "hello there")
        XCTAssertEqual(filter("hello [inaudible] there"), "hello there")
        XCTAssertEqual(filter("{noise} hello"), "hello")
    }

    func testRemovesPairedTagBlocks() {
        XCTAssertEqual(filter("<thinking>ignore me</thinking>hello"), "hello")
        XCTAssertEqual(filter("before <b class=\"x\">bold</b> after"), "before after")
    }

    func testCollapsesWhitespaceAndTrims() {
        // `.filter` is not the production post-cleanup path. It still collapses
        // every run of Foundation \s, including newlines.
        XCTAssertEqual(filter("  hello    world  "), "hello world")
        XCTAssertEqual(filter("hello\n\n\nworld"), "hello world")
    }

    func testPlainSpeechIsUntouched() {
        XCTAssertEqual(filter("Let's ship it on Friday."), "Let's ship it on Friday.")
        XCTAssertEqual(filter("email me at a@b.com"), "email me at a@b.com")
    }

    func testEmptyAndWhitespaceOnlyInput() {
        XCTAssertEqual(filter(""), "")
        XCTAssertEqual(filter("   \n  "), "")
        XCTAssertEqual(filter("[BLANK_AUDIO]"), "")
    }

    // MARK: - Speech that must survive

    func testParentheticalSpeechIsNotDeleted() {
        // KNOWN BUG: the filter strips every (...) span, so a dictated aside is
        // silently deleted. Remove the XCTExpectFailure once the rule is tightened
        // to non-speech annotations only.
        XCTExpectFailure("TranscriptionOutputFilter deletes legitimate parenthetical speech")
        // A user dictating an aside gets parentheses from the STT model.
        XCTAssertEqual(
            filter("the meeting (which ran long) went well"),
            "the meeting (which ran long) went well"
        )
    }

    func testMathAndCodeSpokenAloudSurvive() {
        // KNOWN BUG: same indiscriminate stripping of (...) and [...].
        XCTExpectFailure("TranscriptionOutputFilter deletes parenthesised and bracketed speech")
        XCTAssertEqual(filter("call foo(bar) then baz"), "call foo(bar) then baz")
        XCTAssertEqual(filter("the array is items[0]"), "the array is items[0]")
    }

    func testComparisonOperatorsAreNotTreatedAsTags() {
        XCTAssertEqual(filter("if x < 5 and y > 3 then stop"), "if x < 5 and y > 3 then stop")
    }

    func testUnmatchedBracketIsNotGreedy() {
        // An opening bracket with no closer must not eat the rest of the line.
        XCTAssertEqual(filter("hello [world"), "hello [world")
    }
}
