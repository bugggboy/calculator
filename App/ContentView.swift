import SwiftUI
import Core

/// 计算器界面。
///
/// 这一层只做两件事：把点击翻译成 `CalculatorKey`，把 `engine.display` 画出来。
/// 所有运算逻辑都在 Core 里——那边 Windows 上能跑单元测试，这边只能靠 CI 编译。
///
/// 兼容 iOS 15：没有用 NavigationStack(iOS 16)、Grid(iOS 16)、foregroundStyle 之类的新 API。
struct ContentView: View {

    @State private var engine = CalculatorEngine()

    private let spacing: CGFloat = 12
    private let padding: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            // 按键是正方形，边长同时受宽度和高度约束：
            // 只按宽度算，在 iPhone SE 这种矮屏上会溢出。
            let usableWidth = geo.size.width - padding * 2
            let widthBased = (usableWidth - spacing * 3) / 4
            let heightBased = (geo.size.height - 176) / 5.6
            let side = max(44, min(widthBased, heightBased))
            let wideSide = side * 2 + spacing

            VStack(spacing: 8) {
                Spacer(minLength: 4)
                display(side: side)
                Spacer(minLength: 4)
                keypad(side: side, wideSide: wideSide)
            }
            .padding(.horizontal, padding)
            .padding(.bottom, 10)
        }
        .background(
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - 显示区

    private func display(side: CGFloat) -> some View {
        Text(engine.display)
            .font(.system(size: side * 0.92, weight: .light))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.25)   // 输到 12 位也塞得下
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 6)
    }

    // MARK: - 键盘

    private func keypad(side: CGFloat, wideSide: CGFloat) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                key("AC", .function, side) { send(.clear) }
                key("±", .function, side) { send(.toggleSign) }
                key("%", .function, side) { send(.percent) }
                key("÷", .accent, side) { send(.operation(.divide)) }
            }
            HStack(spacing: spacing) {
                key("7", .digit, side) { send(.digit(7)) }
                key("8", .digit, side) { send(.digit(8)) }
                key("9", .digit, side) { send(.digit(9)) }
                key("×", .accent, side) { send(.operation(.multiply)) }
            }
            HStack(spacing: spacing) {
                key("4", .digit, side) { send(.digit(4)) }
                key("5", .digit, side) { send(.digit(5)) }
                key("6", .digit, side) { send(.digit(6)) }
                key("−", .accent, side) { send(.operation(.subtract)) }
            }
            HStack(spacing: spacing) {
                key("1", .digit, side) { send(.digit(1)) }
                key("2", .digit, side) { send(.digit(2)) }
                key("3", .digit, side) { send(.digit(3)) }
                key("+", .accent, side) { send(.operation(.add)) }
            }
            HStack(spacing: spacing) {
                Text("0")
                    .font(.system(size: side * 0.4, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: wideSide, height: side)
                    .background(KeyStyle.digit.background)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture { send(.digit(0)) }

                key(".", .digit, side) { send(.decimal) }
                key("=", .accent, side) { send(.equals) }
            }
        }
    }

    private func key(_ title: String,
                     _ style: KeyStyle,
                     _ side: CGFloat,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: side * 0.4, weight: .medium))
                .foregroundColor(.white)
                .frame(width: side, height: side)
                .background(style.background)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 状态更新

    /// 显式做「读出 -> 修改 -> 写回」。
    /// 直接写 `engine.input(...)` 依赖 @State 的写时复制行为，
    /// 显式赋值更稳，也更容易看出状态确实变了。
    private func send(_ key: CalculatorKey) {
        var next = engine
        next.input(key)
        engine = next
    }
}

private enum KeyStyle {
    case digit
    case function
    case accent

    var background: Color {
        switch self {
        case .digit:
            return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .function:
            return Color(red: 0.40, green: 0.40, blue: 0.43)
        case .accent:
            return Color(red: 1.00, green: 0.58, blue: 0.10)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
