import XCTest

extension XMLParsingTests {
    static let __allTests = [
        ("testEmptyElement", testEmptyElement),
        ("testEmptyElementNotEffectingPreviousElement", testEmptyElementNotEffectingPreviousElement),
        ("testListDecodingWithCollapseItemTagStrategy", testListDecodingWithCollapseItemTagStrategy),
        ("testListDecodingWithDefaultStrategy", testListDecodingWithDefaultStrategy),
        ("testSingletonListDecodingWithCollapseItemTagStrategy", testSingletonListDecodingWithCollapseItemTagStrategy),
        ("testSingletonListDecodingWithDefaultStrategy", testSingletonListDecodingWithDefaultStrategy),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(XMLParsingTests.__allTests),
    ]
}
#endif
