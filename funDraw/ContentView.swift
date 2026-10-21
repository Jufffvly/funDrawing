
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
    var isVisible: Bool = true
    var a: Double = 0.5
    var b: Double = 0.0
    var c: Double = 0.0
    var k: Double = 1.0
    var phase: Double = 0.0
}

// MARK: - Main View

struct ContentView: View {

    @State private var settings: [FunctionKind: FunctionSettings] =
        Dictionary(
            uniqueKeysWithValues: FunctionKind.allCases.map {
                ($0, FunctionSettings())
            }
        )

    @State private var isAnimating = true
    @State private var animationSpeed = 1.0
    @State private var expression = "y = x^2 - 4"
    @State private var comparisonExpression = "y = x"
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    private var parsedExpression: MathEngine? {
        MathEngine(expression: expression)
    }

    private var parsedComparisonExpression: MathEngine? {
        MathEngine(expression: comparisonExpression)
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

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ScrollView {
                VStack(spacing: 16) {
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
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("函数绘图")
                            .font(.title2.bold())
                        Text(expression)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 4)

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
                            expression: parsedExpression,
                            comparisonExpression: parsedComparisonExpression,
                            zeroes: detectedZeros,
                            yIntercept: yIntercept,
                            quadraticAnalysis: quadraticAnalysis,
                            intersections: detectedIntersections,
                            xRange: xRange,
                            yRange: yRange
                        )
                    }
                    .frame(height: 500)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("函数坐标系")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingControls = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("打开操作侧边栏")
                }
            }
            .sheet(isPresented: $showingControls) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                    // Arbitrary function expression input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("任意函数输入")
                            .font(.headline)
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


            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("函数坐标系")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityLabel("显示或隐藏操作侧栏")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
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
                        settings[kind]?.isVisible ?? true
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
            uniqueKeysWithValues: FunctionKind.allCases.map {
                ($0, FunctionSettings())
            }
        )

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
                        y = config.a * sin(
                            x + config.phase + animationSpeed * time
                        )

                    case .cosine:
                        y = config.a * cos(
                            x + config.phase + animationSpeed * time
                        )

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

// MARK: - Preview

#Preview {
    ContentView()
}

