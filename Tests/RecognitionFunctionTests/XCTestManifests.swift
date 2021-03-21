import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(devhr_project_swiftTests.allTests),
    ]
}
#endif
