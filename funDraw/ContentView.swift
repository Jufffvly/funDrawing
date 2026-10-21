
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

    @State private var xRange: ClosedRange<Double> = -10.0...10.0
    @State private var yRange: ClosedRange<Double> = -10.0...10.0

    // 缩放手势开始时的坐标范围，避免连续手势累积误差
    @State private var baseXRange: ClosedRange<Double> = -10.0...10.0
    @State private var baseYRange: ClosedRange<Double> = -10.0...10.0

    private let initialRange = -10.0...10.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Text("多函数实时绘图")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                            xRange: xRange,
                            yRange: yRange
                        )
                    }
                    .frame(height: 360)
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
            .navigationTitle("Function Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
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

            // Draw all enabled curves. Bound the work so unusually large canvases
            // cannot trigger an unbounded number of evaluations in a single frame.
            let samples = min(max(Int(size.width * 2), 400), 2400)
            // A large vertical jump between adjacent samples usually indicates a
            // discontinuity or a near-vertical asymptote. Break the path instead
            // of drawing a misleading segment across the graph.
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
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

