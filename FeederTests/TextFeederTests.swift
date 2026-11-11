import XCTest

final class TextFeederTests: XCTestCase {
    func testFeedsCharactersInOrderThenFinishes() {
        var f = TextFeeder()
        f.setText("abc")
        XCTAssertEqual(f.total, 3)
        XCTAssertEqual(f.next(), "a")
        XCTAssertEqual(f.next(), "b")
        XCTAssertFalse(f.isFinished)
        XCTAssertEqual(f.next(), "c")
        XCTAssertTrue(f.isFinished)
        XCTAssertNil(f.next())
    }

    func testGraphemeClustersStayWhole() {
        var f = TextFeeder()
        f.setText("e\u{301}👍🏽🇳🇿")
        XCTAssertEqual(f.total, 3)
        XCTAssertEqual(f.next(), "e\u{301}")
        XCTAssertEqual(f.next(), "👍🏽")
        XCTAssertEqual(f.next(), "🇳🇿")
    }

    func testCRLFIsOneNewlineCharacter() {
        var f = TextFeeder()
        f.setText("a\r\nb")
        XCTAssertEqual(f.total, 3)
        _ = f.next()
        XCTAssertTrue(f.next()!.isNewline)
    }

    func testBackAndResetClamp() {
        var f = TextFeeder()
        f.setText("ab")
        f.back()
        XCTAssertEqual(f.index, 0)
        _ = f.next(); _ = f.next()
        f.back()
        XCTAssertEqual(f.index, 1)
        f.reset()
        XCTAssertEqual(f.index, 0)
    }

    func testSetTextKeepsCursorButClampsToNewLength() {
        var f = TextFeeder()
        f.setText("abcdef")
        for _ in 0..<5 { _ = f.next() }
        f.setText("abc")
        XCTAssertEqual(f.index, 3)
        XCTAssertTrue(f.isFinished)
    }

    func testUpcomingPreview() {
        var f = TextFeeder()
        f.setText("hello world")
        _ = f.next()
        XCTAssertEqual(f.upcoming(4), "ello")
        f.setText("hi")
        XCTAssertEqual(f.upcoming(10), "i")
    }

    func testEmptyText() {
        var f = TextFeeder()
        XCTAssertTrue(f.isFinished)
        XCTAssertNil(f.next())
        XCTAssertEqual(f.upcoming(), "")
    }

    func testLoopingWrapsAround() {
        var f = TextFeeder()
        f.setText("ab")
        XCTAssertEqual(f.nextLooping(), "a")
        XCTAssertEqual(f.nextLooping(), "b")
        XCTAssertEqual(f.index, 0)
        XCTAssertEqual(f.nextLooping(), "a")
    }

    func testLoopingOnEmptyTextReturnsNil() {
        var f = TextFeeder()
        XCTAssertNil(f.nextLooping())
    }
}
