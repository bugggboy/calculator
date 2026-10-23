import XCTest
@testable import Core

final class CalculatorTests: XCTestCase {

    /// 按顺序敲一串键，返回最终状态。
    private func run(_ keys: [CalculatorKey]) -> CalculatorEngine {
        var engine = CalculatorEngine()
        for key in keys {
            engine.input(key)
        }
        return engine
    }

    // MARK: - 四则运算

    func testAddition() {
        XCTAssertEqual(run([.digit(2), .operation(.add), .digit(3), .equals]).display, "5")
    }

    func testSubtraction() {
        XCTAssertEqual(run([.digit(9), .operation(.subtract), .digit(4), .equals]).display, "5")
    }

    func testMultiplication() {
        XCTAssertEqual(run([.digit(6), .operation(.multiply), .digit(7), .equals]).display, "42")
    }

    func testDivision() {
        XCTAssertEqual(run([.digit(1), .digit(0), .operation(.divide), .digit(4), .equals]).display,
                       "2.5")
    }

    func testDivisionByZeroEntersErrorState() {
        let engine = run([.digit(5), .operation(.divide), .digit(0), .equals])
        XCTAssertTrue(engine.hasError)
        XCTAssertEqual(engine.display, "错误")
    }

    func testClearRecoversFromError() {
        var engine = run([.digit(5), .operation(.divide), .digit(0), .equals])
        engine.input(.clear)
        XCTAssertFalse(engine.hasError)
        XCTAssertEqual(engine.display, "0")
    }

    // MARK: - 小数精度（用 Double 会失败的那类）

    func testDecimalFractionPrecision() {
        let engine = run([.digit(0), .decimal, .digit(1),
                          .operation(.add),
                          .digit(0), .decimal, .digit(2), .equals])
        XCTAssertEqual(engine.display, "0.3")
    }

    func testDecimalPointIgnoredWhenRepeated() {
        let engine = run([.digit(1), .decimal, .decimal, .digit(5)])
        XCTAssertEqual(engine.display, "1.5")
    }

    func testLeadingZerosAreCollapsed() {
        let engine = run([.digit(0), .digit(0), .digit(5)])
        XCTAssertEqual(engine.display, "5")
    }

    // MARK: - 链式与连按

    func testChainedOperationsEvaluateLeftToRight() {
        // 2 + 3 + 4 = 9（不是带优先级的什么结果，计算器就是从左到右）
        let engine = run([.digit(2), .operation(.add),
                          .digit(3), .operation(.add),
                          .digit(4), .equals])
        XCTAssertEqual(engine.display, "9")
    }

    func testRepeatedEqualsRepeatsLastOperation() {
        var engine = run([.digit(2), .operation(.add), .digit(3), .equals])
        XCTAssertEqual(engine.display, "5")
        engine.input(.equals)
        XCTAssertEqual(engine.display, "8")
        engine.input(.equals)
        XCTAssertEqual(engine.display, "11")
    }

    func testSecondOperatorReplacesTheFirst() {
        // 8 + × 2 = 应当是 16，而不是 8 + 2 之后再乘
        let engine = run([.digit(8), .operation(.add), .operation(.multiply),
                          .digit(2), .equals])
        XCTAssertEqual(engine.display, "16")
    }

    // MARK: - 一元按键

    func testToggleSign() {
        let engine = run([.digit(5), .toggleSign])
        XCTAssertEqual(engine.display, "-5")
    }

    func testNegativeResultViaToggleSign() {
        let engine = run([.digit(5), .toggleSign, .operation(.multiply), .digit(3), .equals])
        XCTAssertEqual(engine.display, "-15")
    }

    func testPercentDividesByHundred() {
        let engine = run([.digit(5), .digit(0), .percent])
        XCTAssertEqual(engine.display, "0.5")
    }

    func testBackspace() {
        let engine = run([.digit(1), .digit(2), .digit(3), .backspace])
        XCTAssertEqual(engine.display, "12")
    }

    func testBackspaceToZero() {
        let engine = run([.digit(7), .backspace])
        XCTAssertEqual(engine.display, "0")
    }

    // MARK: - 边界

    func testZeroDividedByNumberIsZero() {
        let engine = run([.digit(0), .operation(.divide), .digit(5), .equals])
        XCTAssertEqual(engine.display, "0")
    }

    func testResultTrailingZerosAreTrimmed() {
        // 10 ÷ 4 × 2 = 5，不能显示成 5.00
        let engine = run([.digit(1), .digit(0), .operation(.divide),
                          .digit(4), .operation(.multiply),
                          .digit(2), .equals])
        XCTAssertEqual(engine.display, "5")
    }

    func testLongInputIsCapped() {
        // 连续输入超长数字不应无限增长
        var engine = CalculatorEngine()
        for _ in 0..<20 {
            engine.input(.digit(7))
        }
        XCTAssertEqual(engine.display.count, 12)
    }
}
