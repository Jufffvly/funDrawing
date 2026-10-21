
import SwiftUI

// MARK: - Function Types

enum FunctionKind: String, CaseIterable, Identifiable {
    case sine = "正弦函数"
    case cosine = "余弦函数"
    case quadratic = "二次函数"
    case linear = "一次函数"
    case exponential = "指数函数"
    case absolute = "绝对值函数"

    var id: Self { self }

    var color: Color {
        switch self {
        case .sine:       return .blue
        case .cosine:     return .green
        case .quadratic:  return .orange
        case .linear:     return .purple
        case .exponential:return .red
        case .absolute:   return .pink
        }
    }

    var formula: String {
        switch self {
        case .sine:        return "y = A sin(x + φ)"
        case .cosine:      return "y = A cos(x + φ)"
        case .quadratic:   return "y = ax² + bx + c"
        case .linear:      return "y = kx + b"
        case .exponential: return "y = e^(kx) - 1"
        case .absolute:    return "y = A|x| + c"
        }
    }
}

// MARK: - Function Settings

struct FunctionSettings {
    var isVisible: Bool = false
    var a: Double = 0.5
    var b: Double = 0.0
    var c: Double = 0.0
    var k: Double = 1.0
    var phase: Double = 0.0
}

// MARK: - Main View

private enum AppDestination: Hashable {
    case functionDrawing
    case objectObserver
}

struct ContentView: View {

    @State private var settings: [FunctionKind: FunctionSettings] =
        Dictionary(
            uniqueKeysWithValues: FunctionKind.allCases.map { kind in
                var config = FunctionSettings()
                config.isVisible = (kind == .quadratic)
                return (kind, config)
            }
        )

    @State private var isAnimating = true
    @State private var animationSpeed = 1.0
    @State private var expression = "y = x^2 - 4"
    @State private var comparisonExpression = "y = x"
    @State private var additionalExpression = "y = 2x + 1"
    @State private var isCustomExpressionVisible = false
    @State private var isComparisonVisible = false
    @State private var isAdditionalExpressionVisible = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedDestination: AppDestination = .functionDrawing

    private var parsedExpression: MathEngine? {
        MathEngine(expression: expression)
    }

    private var parsedComparisonExpression: MathEngine? {
        MathEngine(expression: comparisonExpression)
    }

    private var parsedAdditionalExpression: MathEngine? {
        MathEngine(expression: additionalExpression)
    }

    private var quadraticAnalysis: QuadraticAnalysis? {
        parsedExpression?.quadraticAnalysis
    }

    private var detectedIntersections: [Double] {
        guard let first = parsedExpression, let second = parsedComparisonExpression else { return [] }
        return first.approximateIntersections(in: xRange, withFunction: { second.value($0) })
    }

    private var detectedZeros: [Double] {
        parsedExpression?.approximateZeros(in: xRange) ?? []
    }

    private var yIntercept: Double? {
        parsedExpression?.value(0)
    }

    @State private var xRange: ClosedRange<Double> = -10.0...10.0
    @State private var yRange: ClosedRange<Double> = -10.0...10.0

    // 缩放手势开始时的坐标范围，避免连续手势累积误差
    @State private var baseXRange: ClosedRange<Double> = -10.0...10.0
    @State private var baseYRange: ClosedRange<Double> = -10.0...10.0

    private let initialRange = -10.0...10.0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingControls = false
    @State private var showingExpressionEditor = false
    @State private var selectedFunctionIndex = 2
    @FocusState private var focusedExpressionField: ExpressionField?

    private enum ExpressionField: Hashable {
        case custom
        case comparison
        case additional
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone：保留绘图区优先的首屏，通过左上角功能菜单切换页面。
                NavigationStack {
                    Group {
                        if selectedDestination == .functionDrawing {
                            graphPanel
                        } else {
                            ObjectObserverView()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Menu {
                                Button {
                                    selectedDestination = .functionDrawing
                                } label: {
                                    Label("函数绘图", systemImage: "function")
                                }
                                Button {
                                    selectedDestination = .objectObserver
                                } label: {
                                    Label("观察物体", systemImage: "cube.transparent")
                                }
                            } label: {
                                Image(systemName: "sidebar.left")
                            }
                            .accessibilityLabel("切换功能页面")
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if selectedDestination == .functionDrawing {
                                Button {
                                    showingControls = true
                                } label: {
                                    Label("操作", systemImage: "slider.horizontal.3")
                                }
                                .accessibilityLabel("打开绘图操作")
                            } else {
                                Button {
                                    selectedDestination = .functionDrawing
                                } label: {
                                    Label("函数绘图", systemImage: "function")
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingControls) {
                    NavigationStack {
                        VStack(spacing: 0) {
                            destinationSwitcher
                            controlsPanel
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showingControls = false
                                }
                            }
                        }
                    }
                }
            } else {
                // iPad / regular width：左侧功能导航，函数绘图模式下继续显示原有控制面板。
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    VStack(spacing: 0) {
                        destinationSwitcher
                        if selectedDestination == .functionDrawing {
                            controlsPanel
                        } else {
                            Spacer()
                        }
                    }
                    .frame(minWidth: 260)
                } detail: {
                    Group {
                        if selectedDestination == .functionDrawing {
                            graphPanel
                        } else {
                            ObjectObserverView()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                            } label: {
                                Image(systemName: "sidebar.left")
                            }
                            .accessibilityLabel("显示或隐藏功能侧栏")
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
    }

    private var destinationSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("功能切换")
                .font(.headline)
                .padding(.horizontal, 4)

            Button {
                selectedDestination = .functionDrawing
                showingControls = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "function")
                    Text("函数绘图")
                    Spacer()
                    if selectedDestination == .functionDrawing {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(selectedDestination == .functionDrawing ? Color.accentColor.opacity(0.14) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                selectedDestination = .objectObserver
                showingControls = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cube.transparent")
                    Text("观察物体")
                    Spacer()
                    if selectedDestination == .objectObserver {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(selectedDestination == .objectObserver ? Color.accentColor.opacity(0.14) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var controlsPanel: some View {
        ScrollView {
                        VStack(spacing: 16) {
                            // Arbitrary function expression input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("任意函数输入")
                                    .font(.headline)
                                Toggle("显示自定义函数", isOn: Binding(
                                    get: { isCustomExpressionVisible },
                                    set: { isVisible in
                                        isCustomExpressionVisible = isVisible
                                        if !isVisible {
                                            isComparisonVisible = false
                                        }
                                    }
                                ))
                                Toggle("显示比较函数（需先开启自定义函数）", isOn: $isComparisonVisible)
                                    .disabled(!isCustomExpressionVisible)
                                TextField("例如：y = x^2 - 4", text: $expression)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(.body, design: .monospaced))
                                if parsedExpression != nil {
                                    Label("表达式有效，蓝色曲线实时更新", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Label("表达式无效或不完整，请检查运算符、括号和函数名", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                Toggle("显示第二个自定义函数", isOn: $isAdditionalExpressionVisible)
                                TextField("例如：y = 2x + 1", text: $additionalExpression)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(.body, design: .monospaced))
                                Label(parsedAdditionalExpression == nil ? "第二个函数表达式无效" : "第二个函数有效，紫色曲线实时更新", systemImage: parsedAdditionalExpression == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(parsedAdditionalExpression == nil ? .orange : .purple)
                                Text("支持 x、数字、括号、+ − × ÷、幂运算、隐式乘法（2x、2(x+1)）及 sin、cos、tan、abs、sqrt、exp、ln、log、pi、e。")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
        
                            VStack(alignment: .leading, spacing: 8) {
                                Text("交点比较函数")
                                    .font(.headline)
                                TextField("例如：y = x", text: $comparisonExpression)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(.body, design: .monospaced))
                                Label(
                                    parsedComparisonExpression == nil ? "比较表达式无效" : "绿色曲线用于计算两条函数的交点",
                                    systemImage: parsedComparisonExpression == nil ? "exclamationmark.triangle.fill" : "arrow.left.and.right"
                                )
                                .font(.caption)
                                .foregroundStyle(parsedComparisonExpression == nil ? .orange : .secondary)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
        
                            // Numerical key-point analysis for the entered expression
                            VStack(alignment: .leading, spacing: 6) {
                                Text("关键点分析")
                                    .font(.headline)
                                Text("x 轴交点（零点，当前可视范围内）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if detectedZeros.isEmpty {
                                    Text("当前范围内未检测到零点")
                                        .font(.subheadline)
                                } else {
                                    Text(detectedZeros.map { "(\(String(format: "%.4g", $0)), 0)" }.joined(separator: "、"))
                                        .font(.subheadline.monospaced())
                                        .textSelection(.enabled)
                                }
                                Text("y 轴交点")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let intercept = yIntercept {
                                    Text("(0, \(String(format: "%.4g", intercept)))")
                                        .font(.subheadline.monospaced())
                                        .textSelection(.enabled)
                                } else {
                                    Text("x = 0 不在函数定义域内")
                                        .font(.subheadline)
                                }
                                if let q = quadraticAnalysis {
                                    Text("二次函数顶点：(\(String(format: "%.4g", q.vertexX)), \(String(format: "%.4g", q.vertexY)))")
                                        .font(.subheadline.monospaced())
                                        .textSelection(.enabled)
                                    Text("对称轴：x = \(String(format: "%.4g", q.axisOfSymmetry))")
                                        .font(.subheadline.monospaced())
                                    Text("判别式：Δ = \(String(format: "%.4g", q.discriminant))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("与比较函数的交点（当前可视范围内）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if parsedComparisonExpression == nil {
                                    Text("请检查比较函数表达式")
                                        .font(.subheadline)
                                } else if detectedIntersections.isEmpty {
                                    Text("当前范围内未检测到交点")
                                        .font(.subheadline)
                                } else {
                                    Text(detectedIntersections.compactMap { x -> String? in
                                        guard let y = parsedExpression?.value(x) else { return nil }
                                        return "(\(String(format: "%.4g", x)), \(String(format: "%.4g", y)))"
                                    }.joined(separator: "、"))
                                    .font(.subheadline.monospaced())
                                    .textSelection(.enabled)
                                }
                                Text("数值交点为近似值；仅分析当前 x 轴可视范围。")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
        
                            // Main buttons
                            HStack(spacing: 8) {
                                Button {
                                    isAnimating.toggle()
                                } label: {
                                    Label(
                                        isAnimating ? "暂停动画" : "继续动画",
                                        systemImage: isAnimating
                                            ? "pause.fill" : "play.fill"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
        
                                Button("全部显示") {
                                    for kind in FunctionKind.allCases {
                                        updateSetting(kind) {
                                            $0.isVisible = true
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
        
                                Button("重置") {
                                    resetSettings()
                                }
                                .buttonStyle(.bordered)
                            }
        
                            // Animation speed
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("动画速度")
                                    Spacer()
                                    Text(animationSpeed, format: .number.precision(.fractionLength(2)))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
        
                                Slider(value: $animationSpeed, in: 0...3)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
        
                            // Function settings
                            VStack(alignment: .leading, spacing: 16) {
                                Text("函数列表")
                                    .font(.headline)
        
                                ForEach(FunctionKind.allCases) { kind in
                                    functionRow(kind)
        
                                    if kind != FunctionKind.allCases.last {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
        
                        }
                        .padding()
                    }
                    .navigationTitle("绘图操作")
                    .navigationBarTitleDisplayMode(.inline)
    }

    private var graphPanel: some View {
        return VStack(spacing: 10) {
            VStack(spacing: 10) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("函数绘图")
                                    .font(.title2.bold())
                                Text("内置函数与自定义函数 · 参数实时可调")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 4)

                        // 坐标系优先显示，参数控制放在图表下方，方便操作。

                            // Graph
                            TimelineView(
                                .animation(
                                    minimumInterval: 1.0 / 30.0,
                                    paused: !isAnimating
                                )
                            ) { timeline in
                                FunctionCanvas(
                                    settings: settings,
                                    time: timeline.date
                                        .timeIntervalSinceReferenceDate,
                                    animationSpeed: animationSpeed,
                                    expression: isCustomExpressionVisible ? parsedExpression : nil,
                                    comparisonExpression: (isCustomExpressionVisible && isComparisonVisible) ? parsedComparisonExpression : nil,
                                    additionalExpression: (isCustomExpressionVisible && isAdditionalExpressionVisible) ? parsedAdditionalExpression : nil,
                                    zeroes: detectedZeros,
                                    yIntercept: yIntercept,
                                    quadraticAnalysis: quadraticAnalysis,
                                    intersections: detectedIntersections,
                                    xRange: xRange,
                                    yRange: yRange
                                )
                            }
                            .frame(height: horizontalSizeClass == .compact ? 390 : 520)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            // 在图表上双指捏合，即可同时缩放坐标轴和所有函数曲线
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let scale = Double(value)
                                        guard scale > 0 else { return }
        
                                        let centerX = (baseXRange.lowerBound + baseXRange.upperBound) / 2
                                        let centerY = (baseYRange.lowerBound + baseYRange.upperBound) / 2
                                        let halfX = (baseXRange.upperBound - baseXRange.lowerBound) / 2 / scale
                                        let halfY = (baseYRange.upperBound - baseYRange.lowerBound) / 2 / scale
        
                                        // 限制最小/最大可视范围，防止缩放过度
                                        let clampedHalfX = min(max(halfX, 0.05), 500.0)
                                        let clampedHalfY = min(max(halfY, 0.05), 500.0)
        
                                        xRange = (centerX - clampedHalfX)...(centerX + clampedHalfX)
                                        yRange = (centerY - clampedHalfY)...(centerY + clampedHalfY)
                                    }
                                    .onEnded { _ in
                                        baseXRange = xRange
                                        baseYRange = yRange
                                    }
                            )

                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .top)

            Divider()

            HStack {
                Text("函数参数调节")
                    .font(.headline)
                Spacer()
                Text("滑动调参，曲线实时更新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)

            // 独立滚动参数区：滚动时坐标系保持固定可见。
            ScrollView(.vertical) {
                functionParameterControls
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .frame(maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") {
                    focusedExpressionField = nil
                }
            }
        }
        .sheet(isPresented: $showingExpressionEditor) {
            expressionEditorSheet
        }
        .navigationTitle("函数坐标系")
        .navigationBarTitleDisplayMode(.inline)
        
    }

    // Insert a math token at the current cursor position when possible.
    private func expressionShortcut(_ title: String, template: String) -> some View {
        Button {
            let target: ExpressionField = focusedExpressionField ?? .custom
            switch target {
            case .custom:
                expression = insertingExpressionTemplate(template, into: expression)
                focusedExpressionField = .custom
            case .comparison:
                comparisonExpression = insertingExpressionTemplate(template, into: comparisonExpression)
                focusedExpressionField = .comparison
            case .additional:
                additionalExpression = insertingExpressionTemplate(template, into: additionalExpression)
                focusedExpressionField = .additional
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .frame(minWidth: 42, minHeight: 34)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("插入 \(title)")
    }

    private func insertingExpressionTemplate(_ template: String, into current: String) -> String {
        // TextField cursor selection is not exposed on all supported SwiftUI versions.
        // Appending the token is predictable and avoids losing existing expression text.
        current + template
    }

    // MARK: - Custom Function Controls

    private var customExpressionControlsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("自定义函数", systemImage: "function")
                    .font(.headline)
                Spacer()
                Toggle("开启", isOn: Binding(
                    get: { isCustomExpressionVisible },
                    set: { enabled in
                        isCustomExpressionVisible = enabled
                        if !enabled {
                            isComparisonVisible = false
                        }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel("显示自定义函数")
            }

            Button {
                showingExpressionEditor = true
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("编辑函数表达式")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(expression)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.tint)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Label(
                parsedExpression == nil ? "表达式无效，请检查输入" : "表达式有效，曲线会实时更新",
                systemImage: parsedExpression == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(parsedExpression == nil ? .orange : .green)

            Toggle("显示比较函数", isOn: $isComparisonVisible)
                .disabled(!isCustomExpressionVisible)

            if isComparisonVisible {
                Button {
                    showingExpressionEditor = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("编辑比较函数")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(comparisonExpression)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.tint)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(parsedComparisonExpression == nil ? "比较函数表达式无效" : "比较曲线以绿色显示")
                    .font(.caption2)
                    .foregroundStyle(parsedComparisonExpression == nil ? .orange : .secondary)
            }

            Text("支持幂运算、括号、隐式乘法及 sin、cos、tan、abs、sqrt、exp、ln、log 等函数。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var expressionEditorSheet: some View {
        NavigationStack {
            Form {
                Section("自定义函数") {
                    TextField("例如：y = x^2 - 4", text: $expression)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedExpressionField, equals: .custom)
                        .submitLabel(.done)
                        .onSubmit { focusedExpressionField = nil }

                    // 数学函数快捷键：插入函数模板并将光标放入括号内。
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            expressionShortcut("sin", template: "sin(x)")
                            expressionShortcut("cos", template: "cos(x)")
                            expressionShortcut("tan", template: "tan(x)")
                            expressionShortcut("√", template: "sqrt(x)")
                            expressionShortcut("ln", template: "ln(x)")
                            expressionShortcut("log", template: "log(x)")
                            expressionShortcut("eˣ", template: "exp(x)")
                            expressionShortcut("x²", template: "x^2")
                            expressionShortcut("xⁿ", template: "^")
                            expressionShortcut("π", template: "pi")
                            expressionShortcut("e", template: "e")
                            expressionShortcut("abs", template: "abs(x)")
                        }
                        .padding(.vertical, 4)
                    }

                    Label(
                        parsedExpression == nil ? "表达式无效或不完整" : "表达式有效，蓝色曲线实时更新",
                        systemImage: parsedExpression == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(parsedExpression == nil ? .orange : .green)
                }

                Section("第二个自定义函数（紫色曲线）") {
                    Toggle("显示第二个自定义函数", isOn: $isAdditionalExpressionVisible)
                    TextField("例如：y = 2x + 1", text: $additionalExpression)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedExpressionField, equals: .additional)
                        .submitLabel(.done)
                        .onSubmit { focusedExpressionField = nil }
                    Label(parsedAdditionalExpression == nil ? "表达式无效或不完整" : "表达式有效，紫色曲线实时更新", systemImage: parsedAdditionalExpression == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(parsedAdditionalExpression == nil ? .orange : .purple)
                }

                Section("比较函数") {
                    Toggle("显示比较函数", isOn: $isComparisonVisible)
                        .disabled(!isCustomExpressionVisible)

                    if isComparisonVisible {
                        TextField("例如：y = x", text: $comparisonExpression)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedExpressionField, equals: .comparison)
                            .submitLabel(.done)
                            .onSubmit { focusedExpressionField = nil }

                        Label(
                            parsedComparisonExpression == nil ? "比较表达式无效" : "绿色曲线实时更新",
                            systemImage: parsedComparisonExpression == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(parsedComparisonExpression == nil ? .orange : .green)
                    }
                }

                Section {
                    Text("支持 x、数字、括号、+ − × ÷、幂运算、隐式乘法（2x、2(x+1)）及 sin、cos、tan、abs、sqrt、exp、ln、log、pi、e。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("编辑函数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        focusedExpressionField = nil
                        showingExpressionEditor = false
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") {
                        focusedExpressionField = nil
                    }
                }
            }
            .onAppear {
                focusedExpressionField = .custom
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Swipeable Function Parameter Controls

    private var functionParameterControls: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFunctionIndex = max(0, selectedFunctionIndex - 1)
                    }
                } label: {
                    Label("上一个", systemImage: "chevron.left")
                }
                .disabled(selectedFunctionIndex == 0)

                Spacer()

                Text("\(selectedFunctionIndex + 1) / \(FunctionKind.allCases.count + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFunctionIndex = min(FunctionKind.allCases.count, selectedFunctionIndex + 1)
                    }
                } label: {
                    Label("下一个", systemImage: "chevron.right")
                }
                .disabled(selectedFunctionIndex == FunctionKind.allCases.count - 1)
            }

            TabView(selection: $selectedFunctionIndex) {
                ForEach(Array(FunctionKind.allCases.enumerated()), id: \.element.id) { index, kind in
                    Group {
                        if kind == .quadratic {
                            quadraticControlsPanel(settings[.quadratic] ?? FunctionSettings())
                        } else {
                            functionParameterPanel(kind)
                        }
                    }
                    .padding(.horizontal, 2)
                    .tag(index)
                }

                customExpressionControlsPanel
                    .padding(.horizontal, 2)
                    .tag(FunctionKind.allCases.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: horizontalSizeClass == .compact ? 205 : 225)

            Text("左右滑动切换函数；调节参数时，坐标系中的曲线会实时更新。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func functionParameterPanel(_ kind: FunctionKind) -> some View {
        let config = settings[kind] ?? FunctionSettings()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(kind.color)
                    .frame(width: 10, height: 10)
                Text(kind.rawValue)
                    .font(.subheadline.bold())
                Spacer()
                Toggle("显示", isOn: Binding(
                    get: { settings[kind]?.isVisible ?? false },
                    set: { value in
                        updateSetting(kind) { $0.isVisible = value }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel("显示\(kind.rawValue)")
            }

            Text(kind.formula)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            switch kind {
            case .sine, .cosine:
                settingSlider(kind, "振幅 A", value: config.a, range: 0.1...3.0, key: .a)
                settingSlider(kind, "相位 φ", value: config.phase, range: 0...(2 * Double.pi), key: .phase)
                Text(String(format: kind == .sine ? "当前：y = %.2f sin(x + %.2f)" : "当前：y = %.2f cos(x + %.2f)", config.a, config.phase))
                    .font(.caption.monospaced())
                    .foregroundStyle(kind.color)

            case .linear:
                settingSlider(kind, "斜率 k", value: config.k, range: -3...3, key: .k)
                settingSlider(kind, "截距 b", value: config.b, range: -5...5, key: .b)
                Text(String(format: "当前：y = %.2fx %+.2f", config.k, config.b))
                    .font(.caption.monospaced())
                    .foregroundStyle(kind.color)

            case .exponential:
                settingSlider(kind, "指数系数 k", value: config.k, range: -1...1, key: .k)
                Text(String(format: "当前：y = e^(%.2fx) - 1", config.k))
                    .font(.caption.monospaced())
                    .foregroundStyle(kind.color)

            case .absolute:
                settingSlider(kind, "系数 A", value: config.a, range: -3...3, key: .a)
                settingSlider(kind, "常数项 c", value: config.c, range: -5...5, key: .c)
                Text(String(format: "当前：y = %.2f|x| %+.2f", config.a, config.c))
                    .font(.caption.monospaced())
                    .foregroundStyle(kind.color)

            case .quadratic:
                EmptyView()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quadratic Coefficient Controls

    private func quadraticControlsPanel(_ config: FunctionSettings) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("二次函数实验")
                        .font(.headline)
                    Text("y = ax² + bx + c")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("显示", isOn: Binding(
                    get: { settings[.quadratic]?.isVisible ?? false },
                    set: { isVisible in
                        updateSetting(.quadratic) { $0.isVisible = isVisible }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel("显示二次函数")
            }

            HStack(spacing: 12) {
                coefficientSlider("a", value: config.a, range: -3...3) { value in
                    updateSetting(.quadratic) {
                        $0.a = value
                        $0.isVisible = true
                    }
                }
                coefficientSlider("b", value: config.b, range: -5...5) { value in
                    updateSetting(.quadratic) {
                        $0.b = value
                        $0.isVisible = true
                    }
                }
                coefficientSlider("c", value: config.c, range: -5...5) { value in
                    updateSetting(.quadratic) {
                        $0.c = value
                        $0.isVisible = true
                    }
                }
            }

            Text(String(
                format: "当前：y = %.2fx² %+.2fx %+.2f",
                config.a, config.b, config.c
            ))
            .font(.caption.monospaced())
            .foregroundStyle(.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func coefficientSlider(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text("\(title) =")
                    .font(.caption.bold())
                Spacer(minLength: 0)
                Text(value, format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: range)
            .accessibilityLabel("二次函数系数 \(title)")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Safe Settings Update

    // Copy the struct, modify it, and write it back to the dictionary.
    // This avoids the problematic nested dictionary/key-path assignment.
    private func updateSetting(
        _ kind: FunctionKind,
        _ update: (inout FunctionSettings) -> Void
    ) {
        var item = settings[kind] ?? FunctionSettings()
        update(&item)
        settings[kind] = item
    }

    // MARK: - Function Row

    private func functionRow(_ kind: FunctionKind) -> some View {
        let config = settings[kind] ?? FunctionSettings()

        return VStack(alignment: .leading, spacing: 10) {

            Toggle(
                isOn: Binding(
                    get: {
                        settings[kind]?.isVisible ?? false
                    },
                    set: { newValue in
                        updateSetting(kind) {
                            $0.isVisible = newValue
                        }
                    }
                )
            ) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(kind.color)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(kind.rawValue)
                            .font(.subheadline.bold())

                        Text(kind.formula)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if config.isVisible {
                switch kind {
                case .sine, .cosine:
                    settingSlider(
                        kind, "振幅 A",
                        value: config.a,
                        range: 0.1...3.0,
                        key: .a
                    )

                    settingSlider(
                        kind, "相位 φ",
                        value: config.phase,
                        range: 0...(2 * Double.pi),
                        key: .phase
                    )

                case .quadratic:
                    settingSlider(
                        kind, "二次项 a",
                        value: config.a,
                        range: -1.5...1.5,
                        key: .a
                    )

                    settingSlider(
                        kind, "一次项 b",
                        value: config.b,
                        range: -3...3,
                        key: .b
                    )

                    settingSlider(
                        kind, "常数项 c",
                        value: config.c,
                        range: -5...5,
                        key: .c
                    )

                case .linear:
                    settingSlider(
                        kind, "斜率 k",
                        value: config.k,
                        range: -3...3,
                        key: .k
                    )

                    settingSlider(
                        kind, "截距 b",
                        value: config.b,
                        range: -5...5,
                        key: .b
                    )

                case .exponential:
                    settingSlider(
                        kind, "指数系数 k",
                        value: config.k,
                        range: -1...1,
                        key: .k
                    )

                case .absolute:
                    settingSlider(
                        kind, "系数 A",
                        value: config.a,
                        range: -3...3,
                        key: .a
                    )

                    settingSlider(
                        kind, "常数项 c",
                        value: config.c,
                        range: -5...5,
                        key: .c
                    )
                }
            }
        }
    }

    // MARK: - Parameter Slider

    private enum ParameterKey {
        case a, b, c, k, phase
    }

    private func settingSlider(
        _ kind: FunctionKind,
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        key: ParameterKey
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)

                Spacer()

                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: {
                        currentValue(for: kind, key: key)
                    },
                    set: { newValue in
                        updateSetting(kind) { item in
                            item.isVisible = true
                            switch key {
                            case .a: item.a = newValue
                            case .b: item.b = newValue
                            case .c: item.c = newValue
                            case .k: item.k = newValue
                            case .phase: item.phase = newValue
                            }
                        }
                    }
                ),
                in: range
            )
        }
    }

    private func currentValue(
        for kind: FunctionKind,
        key: ParameterKey
    ) -> Double {
        let item = settings[kind] ?? FunctionSettings()

        switch key {
        case .a: return item.a
        case .b: return item.b
        case .c: return item.c
        case .k: return item.k
        case .phase: return item.phase
        }
    }

    // MARK: - Reset

    private func resetSettings() {
        settings = Dictionary(
            uniqueKeysWithValues: FunctionKind.allCases.map { kind in
                var config = FunctionSettings()
                config.isVisible = (kind == .quadratic)
                return (kind, config)
            }
        )

        isCustomExpressionVisible = false
        isComparisonVisible = false
        isAdditionalExpressionVisible = false
        animationSpeed = 1.0
        isAnimating = true
        xRange = initialRange
        yRange = initialRange
        baseXRange = initialRange
        baseYRange = initialRange
    }
}

// MARK: - Canvas

struct FunctionCanvas: View {

    let settings: [FunctionKind: FunctionSettings]
    let time: Double
    let animationSpeed: Double
    let expression: MathEngine?
    let comparisonExpression: MathEngine?
    let additionalExpression: MathEngine?
    let zeroes: [Double]
    let yIntercept: Double?
    let quadraticAnalysis: QuadraticAnalysis?
    let intersections: [Double]
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else {
                return
            }

            let xMid = (xRange.lowerBound + xRange.upperBound) / 2
            let yMid = (yRange.lowerBound + yRange.upperBound) / 2

            let scaleX = size.width /
                (xRange.upperBound - xRange.lowerBound)

            let scaleY = size.height /
                (yRange.upperBound - yRange.lowerBound)

            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(
                    x: size.width / 2 + (x - xMid) * scaleX,
                    y: size.height / 2 - (y - yMid) * scaleY
                )
            }

            // 根据当前可视范围自动选择网格间距
            func niceStep(for span: Double) -> Double {
                let rawStep = max(span / 10.0, 0.0001)
                let magnitude = pow(10.0, floor(log10(rawStep)))
                let normalized = rawStep / magnitude

                let nice: Double
                if normalized < 1.5 {
                    nice = 1
                } else if normalized < 3.5 {
                    nice = 2
                } else if normalized < 7.5 {
                    nice = 5
                } else {
                    nice = 10
                }
                return nice * magnitude
            }

            func ticks(from lower: Double, to upper: Double, step: Double) -> [Double] {
                guard step > 0, step.isFinite else { return [] }
                let first = ceil(lower / step) * step
                guard first <= upper else { return [] }

                var values: [Double] = []
                var value = first
                var count = 0
                while value <= upper + step * 0.000001 && count < 2000 {
                    values.append(abs(value) < step * 0.000001 ? 0 : value)
                    value += step
                    count += 1
                }
                return values
            }

            func label(for value: Double) -> String {
                if abs(value.rounded() - value) < 0.000001 {
                    return String(Int(value.rounded()))
                }
                return String(format: "%.3g", value)
            }

            let stepX = niceStep(for: xRange.upperBound - xRange.lowerBound)
            let stepY = niceStep(for: yRange.upperBound - yRange.lowerBound)
            let xTicks = ticks(from: xRange.lowerBound, to: xRange.upperBound, step: stepX)
            let yTicks = ticks(from: yRange.lowerBound, to: yRange.upperBound, step: stepY)

            // Grid
            var grid = Path()

            for x in xTicks {
                let p = point(x, 0)
                grid.move(to: CGPoint(x: p.x, y: 0))
                grid.addLine(to: CGPoint(x: p.x, y: size.height))
            }

            for y in yTicks {
                let p = point(0, y)
                grid.move(to: CGPoint(x: 0, y: p.y))
                grid.addLine(to: CGPoint(x: size.width, y: p.y))
            }

            context.stroke(
                grid,
                with: .color(.gray.opacity(0.18)),
                lineWidth: 0.7
            )

            // Axes
            let origin = point(0, 0)
            var axes = Path()

            if origin.y >= 0 && origin.y <= size.height {
                axes.move(to: CGPoint(x: 0, y: origin.y))
                axes.addLine(to: CGPoint(x: size.width, y: origin.y))
            }

            if origin.x >= 0 && origin.x <= size.width {
                axes.move(to: CGPoint(x: origin.x, y: 0))
                axes.addLine(to: CGPoint(x: origin.x, y: size.height))
            }

            context.stroke(
                axes,
                with: .color(.secondary),
                lineWidth: 1.2
            )

            // X-axis labels
            if origin.y >= 0 && origin.y <= size.height {
                for x in xTicks where abs(x) > stepX * 0.000001 {
                    let p = point(x, 0)
                    guard p.x >= 12 && p.x <= size.width - 12 else { continue }

                    context.draw(
                        Text(label(for: x))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary),
                        at: CGPoint(
                            x: p.x,
                            y: min(max(origin.y + 12, 10), size.height - 10)
                        )
                    )
                }
            }

            // Y-axis labels
            if origin.x >= 0 && origin.x <= size.width {
                for y in yTicks where abs(y) > stepY * 0.000001 {
                    let p = point(0, y)
                    guard p.y >= 10 && p.y <= size.height - 10 else { continue }

                    context.draw(
                        Text(label(for: y))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary),
                        at: CGPoint(
                            x: min(max(origin.x + 14, 14), size.width - 14),
                            y: p.y
                        )
                    )
                }
            }

            // Draw all enabled curves. Bound the work per frame for predictable rendering cost.
            let samples = min(max(Int(size.width * 2), 400), 2400)
            // Large jumps between adjacent samples can indicate a discontinuity/asymptote.
            // Break the path instead of drawing a misleading segment across the graph.
            let jumpThreshold = max(stepY * 4, (yRange.upperBound - yRange.lowerBound) * 0.35)

            for kind in FunctionKind.allCases {
                let config = settings[kind] ?? FunctionSettings()

                guard config.isVisible else {
                    continue
                }

                var curve = Path()
                var penDown = false
                var previousY: Double?

                for i in 0...samples {
                    let ratio = Double(i) / Double(samples)

                    let x = xRange.lowerBound
                        + ratio * (xRange.upperBound - xRange.lowerBound)

                    let y: Double

                    switch kind {
                    case .sine:
                        y = config.a * sin(x + config.phase)

                    case .cosine:
                        y = config.a * cos(x + config.phase)

                    case .quadratic:
                        y = config.a * x * x
                            + config.b * x
                            + config.c

                    case .linear:
                        y = config.k * x + config.b

                    case .exponential:
                        y = exp(config.k * x) - 1

                    case .absolute:
                        y = config.a * abs(x) + config.c
                    }

                    // Skip invalid values and points far outside the graph.
                    guard y.isFinite,
                          y >= yRange.lowerBound - 2,
                          y <= yRange.upperBound + 2 else {
                        // Invalid/out-of-view values terminate the current segment.
                        penDown = false
                        previousY = nil
                        continue
                    }

                    let p = point(x, y)
                    let isLargeJump: Bool
                    if let previousY {
                        isLargeJump = abs(y - previousY) > jumpThreshold
                    } else {
                        isLargeJump = false
                    }

                    if penDown && !isLargeJump {
                        curve.addLine(to: p)
                    } else {
                        // Start a fresh subpath at discontinuities and after gaps.
                        curve.move(to: p)
                    }

                    penDown = true
                    previousY = y
                }

                context.stroke(
                    curve,
                    with: .color(kind.color),
                    style: StrokeStyle(
                        lineWidth: 2.2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            // Draw the user-entered expression in blue, using the same coordinate
            // transform and discontinuity safeguards as the built-in functions.
            if let expression {
                var curve = Path()
                var penDown = false
                var previousY: Double?

                for i in 0...samples {
                    let ratio = Double(i) / Double(samples)
                    let x = xRange.lowerBound + ratio * (xRange.upperBound - xRange.lowerBound)
                    guard let y = expression.value(x),
                          y >= yRange.lowerBound - 2,
                          y <= yRange.upperBound + 2 else {
                        penDown = false
                        previousY = nil
                        continue
                    }

                    let p = point(x, y)
                    let isLargeJump = previousY.map { abs(y - $0) > jumpThreshold } ?? false
                    if penDown && !isLargeJump {
                        curve.addLine(to: p)
                    } else {
                        curve.move(to: p)
                    }
                    penDown = true
                    previousY = y
                }

                context.stroke(
                    curve,
                    with: .color(.blue),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                )

                // Draw the additional custom function in purple.
            if let additionalExpression {
                var additionalPath = Path()
                var penDown = false
                var previousY: Double?
                for i in 0...samples {
                    let x = xRange.lowerBound + Double(i) / Double(samples) * (xRange.upperBound - xRange.lowerBound)
                    guard let y = additionalExpression.value(x), y >= yRange.lowerBound - 2, y <= yRange.upperBound + 2 else {
                        penDown = false; previousY = nil; continue
                    }
                    let p = point(x, y)
                    let jump = previousY.map { abs(y - $0) > jumpThreshold } ?? false
                    if penDown && !jump { additionalPath.addLine(to: p) } else { additionalPath.move(to: p) }
                    penDown = true; previousY = y
                }
                context.stroke(additionalPath, with: .color(.purple), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Draw the comparison function in green.
            if let comparisonExpression {
                var comparisonPath = Path()
                var penDown = false
                var previousY: Double?
                for i in 0...samples {
                    let x = xRange.lowerBound + Double(i) / Double(samples) * (xRange.upperBound - xRange.lowerBound)
                    guard let y = comparisonExpression.value(x),
                          y >= yRange.lowerBound - 2, y <= yRange.upperBound + 2 else {
                        penDown = false
                        previousY = nil
                        continue
                    }
                    let p = point(x, y)
                    let jump = previousY.map { abs(y - $0) > jumpThreshold } ?? false
                    if penDown && !jump { comparisonPath.addLine(to: p) } else { comparisonPath.move(to: p) }
                    penDown = true
                    previousY = y
                }
                context.stroke(comparisonPath, with: .color(.green),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Mark numerically detected x-axis zeros and the y-axis intercept.
                for zero in zeroes where zero >= xRange.lowerBound && zero <= xRange.upperBound {
                    let p = point(zero, 0)
                    let dot = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dot), with: .color(.blue))
                    context.draw(Text("(\(String(format: "%.3g", zero)), 0)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.blue),
                        at: CGPoint(x: min(max(p.x + 28, 28), size.width - 28),
                                    y: min(max(p.y - 12, 10), size.height - 10)))
                }
                if let intercept = yIntercept,
                   intercept >= yRange.lowerBound, intercept <= yRange.upperBound {
                    let p = point(0, intercept)
                    let dot = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dot), with: .color(.orange))
                    context.draw(Text("(0, \(String(format: "%.3g", intercept)))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange),
                        at: CGPoint(x: min(max(p.x + 32, 32), size.width - 32),
                                    y: min(max(p.y - 12, 10), size.height - 10)))
                }
                if let q = quadraticAnalysis {
                    let vertex = point(q.vertexX, q.vertexY)
                    if q.vertexX >= xRange.lowerBound, q.vertexX <= xRange.upperBound,
                       q.vertexY >= yRange.lowerBound, q.vertexY <= yRange.upperBound {
                        let rect = CGRect(x: vertex.x - 4, y: vertex.y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: rect), with: .color(.red))
                        context.draw(Text("顶点 (\(String(format: "%.3g", q.vertexX)), \(String(format: "%.3g", q.vertexY)))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red),
                            at: CGPoint(x: min(max(vertex.x + 55, 55), size.width - 55),
                                        y: min(max(vertex.y - 14, 10), size.height - 10)))
                    }
                    if q.axisOfSymmetry >= xRange.lowerBound, q.axisOfSymmetry <= xRange.upperBound {
                        let axisX = point(q.axisOfSymmetry, 0).x
                        var axis = Path()
                        axis.move(to: CGPoint(x: axisX, y: 0))
                        axis.addLine(to: CGPoint(x: axisX, y: size.height))
                        context.stroke(axis, with: .color(.red.opacity(0.6)),
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        context.draw(Text("x = \(String(format: "%.3g", q.axisOfSymmetry))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red),
                            at: CGPoint(x: min(max(axisX + 34, 34), size.width - 34), y: 12))
                    }
                }
                for x in intersections {
                    guard let y = expression.value(x),
                          x >= xRange.lowerBound, x <= xRange.upperBound,
                          y >= yRange.lowerBound, y <= yRange.upperBound else { continue }
                    let p = point(x, y)
                    let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(.green))
                    context.draw(Text("(\(String(format: "%.3g", x)), \(String(format: "%.3g", y)))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green),
                        at: CGPoint(x: min(max(p.x + 38, 38), size.width - 38),
                                    y: min(max(p.y + 13, 10), size.height - 10)))
                }
            }
        }
    }
}


// MARK: - 3D Object Observer

private enum ObserverShape: String, CaseIterable, Identifiable, Equatable {
    case cube = "立方体"
    case layeredCubes = "多层正方体"
    case cylinder = "圆柱体"
    case cone = "圆锥体"
    case sphere = "球体"

    var id: Self { self }
}

private struct ObserverTriangle {
    let a: SIMD3<Double>
    let b: SIMD3<Double>
    let c: SIMD3<Double>
    let color: Color?
}

private struct ProjectedTriangle {
    let points: [CGPoint]
    let depth: Double
    let color: Color?
}

private struct LayerCube: Identifiable {
    let id = UUID()
    var row: Int
    var column: Int
}

private struct LayerCubePlacement {
    let id: UUID
    let layer: Int
    let center: SIMD3<Double>
}

private struct ObjectObserverView: View {
    @State private var shape: ObserverShape = .cube
    // Default to a Rubik's-cube-like 3 × 3 × 3 arrangement.
    @State private var layerCubes: [[LayerCube]] = (0..<3).map { _ in
        (0..<9).map { index in LayerCube(row: index / 3, column: index % 3) }
    }
    @State private var isLayersSeparated = false
    @State private var yaw: Double = 0
    @State private var pitch: Double = 0.22
    @State private var dragStartYaw: Double = 0
    @State private var dragStartPitch: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Picker("物体类型", selection: $shape) {
                ForEach(ObserverShape.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            if shape == .layeredCubes {
                layeredCubeControls
            }

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .secondarySystemBackground))
                    Canvas { context, size in
                        let triangles = makeTriangles(for: shape)
                        let scale = projectionScale(in: size)
                        var projected: [ProjectedTriangle] = []
                        projected.reserveCapacity(triangles.count)
                        for triangle in triangles {
                            projected.append(projectTriangle(triangle, scale: scale, in: size))
                        }
                        projected.sort { left, right in
                            left.depth < right.depth
                        }

                        for triangle in projected {
                            guard triangle.points.count == 3 else { continue }
                            var path = Path()
                            path.move(to: triangle.points[0])
                            path.addLine(to: triangle.points[1])
                            path.addLine(to: triangle.points[2])
                            path.closeSubpath()
                            let shade = 0.34 + min(max((triangle.depth + 1.5) / 3.0, 0), 1) * 0.42
                            context.fill(path, with: .color(triangle.color ?? Color.blue.opacity(shade)))
                            context.stroke(
                                path,
                                with: .color(triangle.color == nil ? Color.primary.opacity(0.45) : Color.black.opacity(0.88)),
                                lineWidth: triangle.color == nil ? 0.7 : 1.15
                            )
                        }
                    }
                    .padding(8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                yaw = dragStartYaw + Double(value.translation.width) * 0.012
                                pitch = min(max(dragStartPitch - Double(value.translation.height) * 0.012,
                                                -Double.pi / 2), Double.pi / 2)
                            }
                            .onEnded { _ in
                                dragStartYaw = yaw
                                dragStartPitch = pitch
                            }
                    )
                    .simultaneousGesture(
                        SpatialTapGesture(count: 2)
                            .exclusively(before: SpatialTapGesture(count: 1))
                            .onEnded { result in
                                guard shape == .layeredCubes else { return }
                                let location: CGPoint
                                let isDoubleTap: Bool
                                switch result {
                                case .first(let tap):
                                    location = tap.location
                                    isDoubleTap = true
                                case .second(let tap):
                                    location = tap.location
                                    isDoubleTap = false
                                }
                                let canvasSize = CGSize(width: max(geometry.size.width - 16, 1),
                                                        height: max(geometry.size.height - 16, 1))
                                if isDoubleTap {
                                    addCube(at: location, canvasSize: canvasSize)
                                } else {
                                    removeCube(at: location, canvasSize: canvasSize)
                                }
                            }
                    )
                }
            }
            .frame(minHeight: 280)
            .padding(.horizontal)

            VStack(spacing: 10) {
                Text("标准视角")
                    .font(.headline)
                HStack(spacing: 10) {
                    viewButton("上面", icon: "arrow.up.to.line") {
                        setView(yaw: 0, pitch: Double.pi / 2)
                    }
                    viewButton("正面", icon: "rectangle") {
                        setView(yaw: 0, pitch: 0)
                    }
                    viewButton("左面", icon: "arrow.left.to.line") {
                        setView(yaw: Double.pi / 2, pitch: 0)
                    }
                }
                Button {
                    setView(yaw: 0, pitch: 0.22)
                } label: {
                    Label("恢复默认角度", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Text(shape == .layeredCubes
                 ? "每层按接近正方形的网格排列。单击小立方体删除，双击模型区域添加小立方体；拖动可旋转观察。"
                 : "在模型区域拖动即可自由旋转；选择不同物体可切换几何模型。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer(minLength: 8)
        }
        .padding(.top, 12)
        .navigationTitle("三维物体观察")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: shape) { _ in
            setView(yaw: 0, pitch: 0.22)
        }
    }

    private func gridSide(for cubes: [LayerCube]) -> Int {
        let largestCoordinate = cubes.reduce(0) { current, cube in
            max(max(current, cube.row + 1), cube.column + 1)
        }
        return max(Int(ceil(sqrt(Double(max(cubes.count, 1))))), largestCoordinate, 1)
    }

    private func placements() -> [LayerCubePlacement] {
        let layerCount = layerCubes.count
        var result: [LayerCubePlacement] = []
        for (layer, cubes) in layerCubes.enumerated() {
            let side = gridSide(for: cubes)
            let centeredLayer = Double(layer) - Double(layerCount - 1) / 2
            let layerGap = isLayersSeparated ? 1.85 : 0.96
            for cube in cubes {
                let x = (Double(cube.column) - Double(side - 1) / 2) * 0.96
                let z = (Double(cube.row) - Double(side - 1) / 2) * 0.96
                result.append(LayerCubePlacement(
                    id: cube.id,
                    layer: layer,
                    center: SIMD3<Double>(x, centeredLayer * layerGap, z)
                ))
            }
        }
        return result
    }

    private func projectedCenter(of point: SIMD3<Double>, scale: Double, size: CGSize) -> CGPoint {
        let rotated = rotate(point)
        return CGPoint(x: Double(size.width) / 2 + rotated.x * scale,
                       y: Double(size.height) / 2 - rotated.y * scale)
    }

    private func removeCube(at location: CGPoint, canvasSize: CGSize) {
        let scale = projectionScale(in: canvasSize)
        let candidates = placements().map { placement -> (LayerCubePlacement, CGFloat) in
            let center = projectedCenter(of: placement.center, scale: scale, size: canvasSize)
            return (placement, hypot(center.x - location.x, center.y - location.y))
        }
        guard let nearest = candidates.min(by: { $0.1 < $1.1 }),
              nearest.1 < max(CGFloat(scale * 0.62), 16),
              layerCubes.indices.contains(nearest.0.layer),
              layerCubes[nearest.0.layer].count > 0 else { return }
        layerCubes[nearest.0.layer].removeAll { $0.id == nearest.0.id }
    }

    private func addCube(at location: CGPoint, canvasSize: CGSize) {
        let scale = projectionScale(in: canvasSize)
        let targetLayer = placements().map { placement -> (Int, CGFloat) in
            let center = projectedCenter(of: placement.center, scale: scale, size: canvasSize)
            return (placement.layer, hypot(center.x - location.x, center.y - location.y))
        }.min(by: { $0.1 < $1.1 })?.0 ?? max(layerCubes.count - 1, 0)
        addCube(toLayer: targetLayer)
    }

    private func addCube(toLayer layer: Int) {
        guard layerCubes.indices.contains(layer), layerCubes[layer].count < 64 else { return }
        let side = gridSide(for: layerCubes[layer])
        var row = 0
        var column = 0
        var found = false
        for candidateRow in 0..<side {
            for candidateColumn in 0..<side {
                let occupied = layerCubes[layer].contains {
                    $0.row == candidateRow && $0.column == candidateColumn
                }
                if !occupied {
                    row = candidateRow
                    column = candidateColumn
                    found = true
                    break
                }
            }
            if found { break }
        }
        if !found {
            row = side
            column = 0
        }
        layerCubes[layer].append(LayerCube(row: row, column: column))
    }

    private func projectionScale(in size: CGSize) -> Double {
        guard shape == .layeredCubes else {
            return Double(min(size.width, size.height)) * 0.31
        }

        let widestGrid = Double(max(layerCubes.map { gridSide(for: $0) }.max() ?? 1, 1)) * 1.05
        let layerGap = isLayersSeparated ? 1.85 : 1.05
        let totalHeight = Double(max(layerCubes.count, 1)) * layerGap
        let widthScale = Double(size.width) / widestGrid
        let heightScale = Double(size.height) / max(totalHeight, widestGrid * 0.82)
        return min(widthScale, heightScale) * 0.82
    }

    private func projectTriangle(
        _ triangle: ObserverTriangle,
        scale: Double,
        in size: CGSize
    ) -> ProjectedTriangle {
        let pointA = rotate(triangle.a)
        let pointB = rotate(triangle.b)
        let pointC = rotate(triangle.c)

        let centerX = Double(size.width) / 2
        let centerY = Double(size.height) / 2
        let projectedA = CGPoint(x: centerX + pointA.x * scale, y: centerY - pointA.y * scale)
        let projectedB = CGPoint(x: centerX + pointB.x * scale, y: centerY - pointB.y * scale)
        let projectedC = CGPoint(x: centerX + pointC.x * scale, y: centerY - pointC.y * scale)
        let averageDepth = (pointA.z + pointB.z + pointC.z) / 3

        return ProjectedTriangle(
            points: [projectedA, projectedB, projectedC],
            depth: averageDepth,
            color: triangle.color
        )
    }

    private var layeredCubeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("层数：\(layerCubes.count) · 总数：\(layerCubes.reduce(0) { $0 + $1.count })")
                        .font(.subheadline.weight(.semibold))
                    Text(isLayersSeparated ? "分层编辑模式：各层已拉开" : "整体显示模式：类似标准魔方")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isLayersSeparated.toggle()
                    }
                } label: {
                    Label(isLayersSeparated ? "合并显示" : "分层编辑", systemImage: "square.3.layers.3d")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    guard layerCubes.count < 8 else { return }
                    layerCubes.append((0..<9).map { index in
                        LayerCube(row: index / 3, column: index % 3)
                    })
                } label: {
                    Label("增加一层", systemImage: "plus")
                }
                .disabled(layerCubes.count >= 8)
                Button {
                    guard layerCubes.count > 1 else { return }
                    layerCubes.removeLast()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .disabled(layerCubes.count <= 1)
                .accessibilityLabel("减少一层")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(layerCubes.indices, id: \.self) { index in
                        VStack(spacing: 5) {
                            Text("第\(index + 1)层")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(layerCubes[index].count) 个")
                                .font(.subheadline.monospacedDigit())
                            HStack(spacing: 8) {
                                Button {
                                    guard layerCubes[index].count > 0 else { return }
                                    layerCubes[index].removeLast()
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .disabled(layerCubes[index].count == 0)
                                Button {
                                    addCube(toLayer: index)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .disabled(layerCubes[index].count >= 64)
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            Text(isLayersSeparated
                 ? "各层已分开，单击对应立方体删除，双击对应位置添加；也可用每层卡片上的加减按钮。编辑完成后点“合并显示”。"
                 : "默认按 3×3×3 魔方排列。建议先点“分层编辑”，再单击删除或双击添加，完成后点“合并显示”；也可使用每层卡片上的加减按钮。每层最多 64 个。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func viewButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.borderedProminent)
    }

    private func setView(yaw newYaw: Double, pitch newPitch: Double) {
        withAnimation(.easeInOut(duration: 0.28)) {
            yaw = newYaw
            pitch = newPitch
            dragStartYaw = newYaw
            dragStartPitch = newPitch
        }
    }

    private func rotate(_ point: SIMD3<Double>) -> SIMD3<Double> {
        let x = point.x * cos(yaw) + point.z * sin(yaw)
        let z = -point.x * sin(yaw) + point.z * cos(yaw)
        let y = point.y * cos(pitch) - z * sin(pitch)
        let depth = point.y * sin(pitch) + z * cos(pitch)
        return SIMD3<Double>(x, y, depth)
    }

    private func makeTriangles(for shape: ObserverShape) -> [ObserverTriangle] {
        var result: [ObserverTriangle] = []
        func add(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>, color: Color? = nil) {
            result.append(ObserverTriangle(a: a, b: b, c: c, color: color))
        }

        func addCube(center: SIMD3<Double>, half: Double) {
            let v: [SIMD3<Double>] = [
                SIMD3(center.x - half, center.y - half, center.z - half),
                SIMD3(center.x + half, center.y - half, center.z - half),
                SIMD3(center.x + half, center.y + half, center.z - half),
                SIMD3(center.x - half, center.y + half, center.z - half),
                SIMD3(center.x - half, center.y - half, center.z + half),
                SIMD3(center.x + half, center.y - half, center.z + half),
                SIMD3(center.x + half, center.y + half, center.z + half),
                SIMD3(center.x - half, center.y + half, center.z + half)
            ]
            let faces = [[0,1,2,3], [4,7,6,5], [0,4,5,1],
                         [3,2,6,7], [0,3,7,4], [1,5,6,2]]
            // Rubik's Cube palette: each face has its own vivid color and dark seams.
            // Face order matches the six vertex-index groups above.
            let faceColors: [Color] = [
                Color(red: 0.08, green: 0.30, blue: 0.88), // blue
                Color(red: 0.00, green: 0.62, blue: 0.28), // green
                Color(red: 1.00, green: 0.82, blue: 0.02), // yellow
                Color(red: 0.96, green: 0.96, blue: 0.91), // white
                Color(red: 1.00, green: 0.32, blue: 0.04), // orange
                Color(red: 0.88, green: 0.02, blue: 0.06)  // red
            ]
            for (faceIndex, face) in faces.enumerated() {
                let faceColor = faceColors[faceIndex]
                add(v[face[0]], v[face[1]], v[face[2]], color: faceColor)
                add(v[face[0]], v[face[2]], v[face[3]], color: faceColor)
            }
        }

        switch shape {
        case .cube:
            addCube(center: SIMD3<Double>(0, 0, 0), half: 1)
        case .layeredCubes:
            let half = 0.46
            let spacing = 0.96
            let layerGap = isLayersSeparated ? 1.85 : spacing
            let layerCount = layerCubes.count
            for (layer, cubes) in layerCubes.enumerated() {
                let side = gridSide(for: cubes)
                let centeredLayer = Double(layer) - Double(layerCount - 1) / 2
                let centerY = centeredLayer * layerGap
                for cube in cubes {
                    let centerX = (Double(cube.column) - Double(side - 1) / 2) * spacing
                    let centerZ = (Double(cube.row) - Double(side - 1) / 2) * spacing
                    addCube(center: SIMD3<Double>(centerX, centerY, centerZ), half: half)
                }
            }
        case .cylinder, .cone:
            let segments = 36
            for i in 0..<segments {
                let t0 = Double(i) * 2 * Double.pi / Double(segments)
                let t1 = Double(i + 1) * 2 * Double.pi / Double(segments)
                let p0 = SIMD3<Double>(cos(t0), -1, sin(t0))
                let p1 = SIMD3<Double>(cos(t1), -1, sin(t1))
                let top0: SIMD3<Double>
                let top1: SIMD3<Double>
                if shape == .cylinder {
                    top0 = SIMD3<Double>(cos(t0), 1, sin(t0))
                    top1 = SIMD3<Double>(cos(t1), 1, sin(t1))
                    add(p0, p1, top1)
                    add(p0, top1, top0)
                } else {
                    top0 = SIMD3<Double>(0, 1, 0)
                    top1 = top0
                    add(p0, p1, top0)
                }
                add(SIMD3<Double>(0, -1, 0), p1, p0)
                if shape == .cylinder {
                    add(SIMD3<Double>(0, 1, 0), top0, top1)
                }
            }
        case .sphere:
            let rings = 16
            let segments = 32
            for ring in 0..<rings {
                let lat0 = -Double.pi / 2 + Double(ring) * Double.pi / Double(rings)
                let lat1 = -Double.pi / 2 + Double(ring + 1) * Double.pi / Double(rings)
                for segment in 0..<segments {
                    let lon0 = Double(segment) * 2 * Double.pi / Double(segments)
                    let lon1 = Double(segment + 1) * 2 * Double.pi / Double(segments)
                    func point(_ lat: Double, _ lon: Double) -> SIMD3<Double> {
                        SIMD3<Double>(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
                    }
                    let a = point(lat0, lon0), b = point(lat0, lon1)
                    let c = point(lat1, lon1), d = point(lat1, lon0)
                    add(a, b, c)
                    add(a, c, d)
                }
            }
        }
        return result
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

