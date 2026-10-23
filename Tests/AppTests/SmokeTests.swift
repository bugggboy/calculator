import XCTest
import Core
@testable import MyApp

final class SmokeTests: XCTestCase {

    // 只是确认测试 target 被正确挂进 scheme。
    func testTargetIsWired() {
        XCTAssertTrue(true)
    }

    // 这条比上面那条有用：它验证 Core 这个本地包确实被 App target 链接上了。
    // 如果 project.yml 里的 package 依赖写错，这里会先红。
    func testCorePackageIsLinked() {
        var engine = CalculatorEngine()
        for key in [CalculatorKey.digit(2), .operation(.add), .digit(3), .equals] {
            engine.input(key)
        }
        XCTAssertEqual(engine.display, "5")
    }
}
