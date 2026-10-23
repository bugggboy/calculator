import Foundation

/// 四则运算。放在 Core 层，所以不能引用 UIKit / SwiftUI。
public enum CalculatorOperation: String, Equatable {
    case add
    case subtract
    case multiply
    case divide

    public var symbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }
}

/// 按键事件。界面层只负责把点击翻译成这个枚举。
public enum CalculatorKey: Equatable {
    case digit(Int)                      // 0...9
    case decimal                         // 小数点
    case operation(CalculatorOperation)  // + − × ÷
    case equals                          // =
    case clear                           // AC
    case toggleSign                      // ±
    case percent                         // %
    case backspace                       // 退格
}

/// 计算器状态机。
///
/// 刻意用 `Decimal` 而不是 `Double`：0.1 + 0.2 用 Double 会得到 0.30000000000000004，
/// 界面上就是一行乱码。Decimal 是十进制表示，能给出干净的 0.3。
///
/// 求值顺序是「从左到右、无优先级」，和 iOS 自带计算器一致：
/// 2 + 3 × 4 = 20，不是 14。
public struct CalculatorEngine {

    /// 当前要显示在屏幕上的文本。
    public private(set) var display: String = "0"

    /// 是否处于错误态（除零）。错误态下除 AC 之外的按键无效。
    public private(set) var hasError: Bool = false

    /// 已按下但还没求值的运算符，界面可以用来高亮那个键。
    public private(set) var pendingOperation: CalculatorOperation?

    /// 正在输入的原始文本；nil 表示当前数字来自上一次运算结果。
    private var entry: String?
    /// 已确定的左操作数。
    private var accumulator: Decimal = 0
    /// 上一次等号用过的运算符和右操作数，用于「连按等号重复上一次运算」。
    private var lastOperation: CalculatorOperation?
    private var lastOperand: Decimal?

    public init() {}

    /// 把当前显示值解析成数值，供界面读取。
    public var value: Decimal {
        currentValue()
    }

    // MARK: - 输入入口

    public mutating func input(_ key: CalculatorKey) {
        switch key {
        case .digit(let digit):
            pressDigit(digit)
        case .decimal:
            pressDecimal()
        case .operation(let operation):
            pressOperation(operation)
        case .equals:
            pressEquals()
        case .clear:
            reset()
        case .toggleSign:
            toggleSign()
        case .percent:
            pressPercent()
        case .backspace:
            pressBackspace()
        }
    }

    public mutating func reset() {
        display = "0"
        hasError = false
        pendingOperation = nil
        entry = nil
        accumulator = 0
        lastOperation = nil
        lastOperand = nil
    }

    // MARK: - 各类按键

    private mutating func pressDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        if hasError { reset() }

        var text = entry ?? "0"
        if text == "0" {
            text = String(digit)
        } else if text == "-0" {
            text = "-" + String(digit)
        } else if significantDigits(text) < 12 {
            text.append(String(digit))
        }
        entry = text
        display = text
    }

    private mutating func pressDecimal() {
        if hasError { reset() }
        var text = entry ?? "0"
        if !text.contains(".") {
            text.append(".")
        }
        entry = text
        display = text
    }

    private mutating func pressOperation(_ operation: CalculatorOperation) {
        guard !hasError else { return }

        if let pending = pendingOperation, entry != nil {
            // 链式运算：先把上一步算出来，结果作为新的左操作数
            guard let result = apply(pending, accumulator, currentValue()) else {
                fail()
                return
            }
            accumulator = result
        } else if entry != nil {
            accumulator = currentValue()
        }
        // entry == nil 且没有待处理运算，说明用户连按运算符，直接替换

        entry = nil
        pendingOperation = operation
        lastOperation = nil
        lastOperand = nil
        display = format(accumulator)
    }

    private mutating func pressEquals() {
        guard !hasError else { return }

        if let pending = pendingOperation {
            let rhs = currentValue()
            guard let result = apply(pending, accumulator, rhs) else {
                fail()
                return
            }
            accumulator = result
            lastOperation = pending
            lastOperand = rhs
            pendingOperation = nil
            entry = nil
            display = format(result)
            return
        }

        if let operation = lastOperation, let operand = lastOperand {
            // 连按等号：用上一次的运算符和右操作数再算一次
            guard let result = apply(operation, currentValue(), operand) else {
                fail()
                return
            }
            accumulator = result
            entry = nil
            display = format(result)
            return
        }

        // 没有任何待处理运算，只是把输入定格
        accumulator = currentValue()
        entry = nil
        display = format(accumulator)
    }

    private mutating func toggleSign() {
        if hasError { reset(); return }

        if let text = entry {
            let next = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
            entry = next
            display = next
        } else {
            accumulator = -accumulator
            display = format(accumulator)
        }
    }

    private mutating func pressPercent() {
        guard !hasError else { return }

        let value = currentValue() / 100
        if entry != nil {
            let text = format(value)
            entry = text
            display = text
        } else {
            accumulator = value
            display = format(accumulator)
        }
    }

    private mutating func pressBackspace() {
        if hasError { reset(); return }
        guard var text = entry else { return }

        text.removeLast()
        if text.isEmpty || text == "-" {
            text = "0"
        }
        entry = text
        display = text
    }

    private mutating func fail() {
        display = "错误"
        hasError = true
        pendingOperation = nil
        entry = nil
        accumulator = 0
        lastOperation = nil
        lastOperand = nil
    }

    // MARK: - 数值处理

    private func currentValue() -> Decimal {
        if let text = entry, let parsed = Decimal(string: text, locale: CalculatorEngine.posix) {
            return parsed
        }
        return accumulator
    }

    private func apply(_ operation: CalculatorOperation, _ lhs: Decimal, _ rhs: Decimal) -> Decimal? {
        switch operation {
        case .add: return lhs + rhs
        case .subtract: return lhs - rhs
        case .multiply: return lhs * rhs
        case .divide:
            // 除零没有可显示的结果，进入错误态
            return rhs == 0 ? nil : lhs / rhs
        }
    }

    /// 保留最多 10 位小数，并去掉尾部多余的 0（2.50 -> 2.5，5.00 -> 5）。
    private func format(_ value: Decimal) -> String {
        if value == 0 { return "0" }

        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 10, .plain)

        var text = NSDecimalString(&rounded, CalculatorEngine.posix)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text == "-0" ? "0" : text
    }

    private func significantDigits(_ text: String) -> Int {
        text.filter { $0.isNumber }.count
    }

    private static let posix = Locale(identifier: "en_US_POSIX")
}
