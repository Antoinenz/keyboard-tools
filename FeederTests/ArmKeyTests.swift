import XCTest
import CoreGraphics

final class ArmKeyTests: XCTestCase {
    func testRoundTripsThroughJSON() throws {
        let keys: [ArmKey] = [
            .capsLock,
            .combo(keyCode: 40, modifiers: CGEventFlags([.maskCommand, .maskAlternate]).rawValue, label: "K"),
        ]
        for k in keys {
            let data = try JSONEncoder().encode(k)
            XCTAssertEqual(try JSONDecoder().decode(ArmKey.self, from: data), k)
        }
    }

    func testDisplayNameOrdersModifiers() {
        let k = ArmKey.combo(keyCode: 40, modifiers: CGEventFlags([.maskCommand, .maskControl]).rawValue, label: "K")
        XCTAssertEqual(k.displayName, "⌃⌘K")
        XCTAssertEqual(ArmKey.capsLock.displayName, "Caps Lock")
    }

    func testAcceptability() {
        XCTAssertFalse(ArmKey.isAcceptable(keyCode: 0, modifiers: []))              // plain "a"
        XCTAssertFalse(ArmKey.isAcceptable(keyCode: 0, modifiers: .maskShift))      // Shift+a is just a capital
        XCTAssertTrue(ArmKey.isAcceptable(keyCode: 0, modifiers: .maskControl))
        XCTAssertTrue(ArmKey.isAcceptable(keyCode: 0, modifiers: .maskAlternate))
        XCTAssertTrue(ArmKey.isAcceptable(keyCode: 122, modifiers: []))             // F1 alone is fine
    }

    func testLabels() {
        XCTAssertEqual(ArmKey.label(forKeyCode: 49, characters: " "), "Space")
        XCTAssertEqual(ArmKey.label(forKeyCode: 0, characters: "a"), "A")
        XCTAssertEqual(ArmKey.label(forKeyCode: 999, characters: nil), "Key 999")
    }
}
