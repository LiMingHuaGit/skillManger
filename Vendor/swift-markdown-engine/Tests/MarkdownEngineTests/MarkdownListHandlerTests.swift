import AppKit
import XCTest
@testable import MarkdownEngine

@MainActor
final class MarkdownListHandlerTests: XCTestCase {
    func testTaskListContinuationKeepsTopLevelIndentation() {
        let textView = makeTextView("- [ ] first")

        let shouldApplyDefaultInsertion = MarkdownLists.handleInsertion(
            textView: textView,
            affectedCharRange: textView.selectedRange(),
            replacementString: "\n"
        )

        XCTAssertFalse(shouldApplyDefaultInsertion)
        XCTAssertEqual(textView.string, "- [ ] first\n- [ ] ")
    }

    func testTaskListContinuationKeepsNestedIndentation() {
        let textView = makeTextView("  - [ ] nested")

        _ = MarkdownLists.handleInsertion(
            textView: textView,
            affectedCharRange: textView.selectedRange(),
            replacementString: "\n"
        )

        XCTAssertEqual(textView.string, "  - [ ] nested\n  - [ ] ")
    }

    private func makeTextView(_ text: String) -> NSTextView {
        let textView = NSTextView()
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        return textView
    }
}
