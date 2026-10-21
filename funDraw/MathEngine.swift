// MathEngine.swift — safe expression parsing, evaluation, and numerical analysis

struct QuadraticAnalysis {
    let a: Double
    let b: Double
    let c: Double
    let vertexX: Double
    let vertexY: Double
    let axisOfSymmetry: Double
    let discriminant: Double
}

struct MathEngine {
    private let root: Node

    /// Exact coefficient extraction for expressions that simplify to a polynomial of degree <= 2.
    var quadraticAnalysis: QuadraticAnalysis? {
        guard let coefficients = root.polynomialCoefficients, coefficients.count <= 3 else { return nil }
        let c = coefficients.indices.contains(0) ? coefficients[0] : 0
        let b = coefficients.indices.contains(1) ? coefficients[1] : 0
        let a = coefficients.indices.contains(2) ? coefficients[2] : 0
        guard a.isFinite, b.isFinite, c.isFinite, abs(a) > 1e-12 else { return nil }
        let vx = -b / (2 * a)
        let vy = c - (b * b) / (4 * a)
        let d = b * b - 4 * a * c
        guard vx.isFinite, vy.isFinite, d.isFinite else { return nil }
        return QuadraticAnalysis(a: a, b: b, c: c, vertexX: vx, vertexY: vy,
                                 axisOfSymmetry: vx, discriminant: d)
    }

    init?(expression: String) {
        guard let normalized = Self.normalize(expression) else { return nil }
        var parser = Parser(source: normalized)
        guard let node = parser.parse(), parser.isAtEnd else { return nil }
        root = node
    }

    static func normalize(_ input: String) -> String? {
        var text = input.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "²", with: "^2")
            .replacingOccurrences(of: "³", with: "^3")
        if text.hasPrefix("y=") { text = String(text.dropFirst(2)) }
        return text.isEmpty ? nil : text
    }

    func value(_ x: Double) -> Double? {
        let result = root.evaluate(x)
        return result.isFinite ? result : nil
    }

    /// Finds approximate real zeros in the requested interval. Sign changes use bisection;
    /// local minima of |f(x)| are also refined to catch common tangent roots such as x^2.
    func approximateZeros(in range: ClosedRange<Double>, samples: Int = 1200) -> [Double] {
        guard range.lowerBound.isFinite, range.upperBound.isFinite,
              range.lowerBound < range.upperBound, samples >= 8 else { return [] }
        let count = min(max(samples, 8), 10000)
        let step = (range.upperBound - range.lowerBound) / Double(count)
        guard step.isFinite, step > 0 else { return [] }

        func finiteValue(_ x: Double) -> Double? {
            guard let y = value(x), y.isFinite else { return nil }
            return y
        }
        func bisect(_ left: Double, _ right: Double, _ leftValue: Double) -> Double? {
            var lo = left, hi = right, flo = leftValue
            for _ in 0..<64 {
                let mid = lo + (hi - lo) / 2
                guard let fm = finiteValue(mid) else { return nil }
                if abs(fm) < 1e-10 || abs(hi - lo) < 1e-9 { return mid }
                if (flo < 0 && fm > 0) || (flo > 0 && fm < 0) {
                    hi = mid
                } else {
                    lo = mid
                    flo = fm
                }
            }
            return lo + (hi - lo) / 2
        }

        var roots: [Double] = []
        var previousX = range.lowerBound
        var previousY = finiteValue(previousX)
        if let y = previousY, abs(y) < 1e-9 { roots.append(previousX) }

        var xs: [Double] = [previousX]
        var ys: [Double?] = [previousY]
        for index in 1...count {
            let x = range.lowerBound + Double(index) * step
            let y = finiteValue(x)
            xs.append(x); ys.append(y)
            if let py = previousY, let cy = y {
                if abs(cy) < 1e-9 {
                    roots.append(x)
                } else if (py < 0 && cy > 0) || (py > 0 && cy < 0),
                          let root = bisect(previousX, x, py) {
                    roots.append(root)
                }
            }
            previousX = x
            previousY = y
        }

        // Refine local minima of |f| to detect roots that touch the axis without crossing it.
        if xs.count >= 3 {
            for index in 1..<(xs.count - 1) {
                guard let leftY = ys[index - 1], let midY = ys[index],
                      let rightY = ys[index + 1],
                      abs(midY) <= abs(leftY), abs(midY) <= abs(rightY) else { continue }
                var lo = xs[index - 1], hi = xs[index + 1]
                for _ in 0..<48 {
                    let m1 = lo + (hi - lo) / 3
                    let m2 = hi - (hi - lo) / 3
                    guard let y1 = finiteValue(m1), let y2 = finiteValue(m2) else { break }
                    if abs(y1) <= abs(y2) { hi = m2 } else { lo = m1 }
                }
                let candidate = lo + (hi - lo) / 2
                if let y = finiteValue(candidate), abs(y) < 1e-7 {
                    roots.append(candidate)
                }
            }
        }

        roots.sort()
        var unique: [Double] = []
        for root in roots where root.isFinite {
            if let last = unique.last, abs(root - last) < max(step * 0.5, 1e-6) { continue }
            unique.append(root)
        }
        return unique
    }

    /// Finds approximate intersections between this function and another sampled function.
    /// The supplied closure returns nil outside the other function's domain.
    func approximateIntersections(
        in range: ClosedRange<Double>,
        withFunction otherValue: (Double) -> Double?,
        samples: Int = 1200
    ) -> [Double] {
        guard range.lowerBound.isFinite, range.upperBound.isFinite,
              range.lowerBound < range.upperBound else { return [] }
        let count = min(max(samples, 16), 10000)
        let step = (range.upperBound - range.lowerBound) / Double(count)
        guard step.isFinite, step > 0 else { return [] }
        func difference(_ x: Double) -> Double? {
            guard let a = value(x), let b = otherValue(x) else { return nil }
            let d = a - b
            return d.isFinite ? d : nil
        }
        var xs: [Double] = []
        var ys: [Double?] = []
        for i in 0...count {
            let x = range.lowerBound + Double(i) * step
            xs.append(x)
            ys.append(difference(x))
        }
        let finiteResiduals = ys.compactMap { $0 }
        // Coincident/overlapping functions have infinitely many intersections; don't emit every sample.
        if !finiteResiduals.isEmpty && finiteResiduals.allSatisfy({ abs($0) < 1e-9 }) {
            return []
        }
        var roots: [Double] = []
        for i in 1...count {
            guard let left = ys[i - 1], let right = ys[i] else { continue }
            if abs(left) < 1e-9 { roots.append(xs[i - 1]); continue }
            guard (left < 0 && right > 0) || (left > 0 && right < 0) else { continue }
            var lo = xs[i - 1], hi = xs[i], flo = left
            for _ in 0..<64 {
                let mid = lo + (hi - lo) / 2
                guard let fm = difference(mid) else { break }
                if abs(fm) < 1e-10 || abs(hi - lo) < 1e-9 { lo = mid; hi = mid; break }
                if (flo < 0 && fm > 0) || (flo > 0 && fm < 0) {
                    hi = mid
                } else {
                    lo = mid
                    flo = fm
                }
            }
            roots.append(lo + (hi - lo) / 2)
        }

        if let lastX = xs.last, let lastY = ys.last, abs(lastY) < 1e-9 {
            roots.append(lastX)
        }

        // Minimize |f-g| near sampled local minima to catch tangential intersections.
        if xs.count >= 3 {
            for i in 1..<(xs.count - 1) {
                guard let l = ys[i - 1], let m = ys[i], let r = ys[i + 1],
                      abs(m) <= abs(l), abs(m) <= abs(r) else { continue }
                var lo = xs[i - 1], hi = xs[i + 1]
                for _ in 0..<48 {
                    let p = lo + (hi - lo) / 3
                    let q = hi - (hi - lo) / 3
                    guard let yp = difference(p), let yq = difference(q) else { break }
                    if abs(yp) <= abs(yq) { hi = q } else { lo = p }
                }
                let x = lo + (hi - lo) / 2
                if let residual = difference(x),
                   abs(residual) < 1e-7 * max(1, max(abs(m), max(abs(l), abs(r)))) {
                    roots.append(x)
                }
            }
        }
        roots.sort()
        var unique: [Double] = []
        for root in roots where root.isFinite {
            if let last = unique.last, abs(root - last) < max(step * 0.35, 1e-6) { continue }
            unique.append(root)
        }
        return unique
    }

    private indirect enum Node {
        case number(Double), variable
        case unary(Character, Node)
        case binary(Character, Node, Node)
        case function(String, Node)

        /// Polynomial coefficients in ascending powers: [c, b, a].
        var polynomialCoefficients: [Double]? {
            switch self {
            case .number(let value):
                return value.isFinite ? [value] : nil
            case .variable:
                return [0, 1]
            case .unary(let op, let node):
                guard var values = node.polynomialCoefficients else { return nil }
                if op == "-" { values = values.map { -$0 } }
                return values
            case .function:
                return nil
            case .binary(let op, let lhs, let rhs):
                guard let a = lhs.polynomialCoefficients,
                      let b = rhs.polynomialCoefficients else { return nil }
                switch op {
                case "+", "-":
                    let count = max(a.count, b.count)
                    var result = Array(repeating: 0.0, count: count)
                    for i in 0..<count {
                        let av = i < a.count ? a[i] : 0
                        let bv = i < b.count ? b[i] : 0
                        result[i] = op == "+" ? av + bv : av - bv
                    }
                    return result.allSatisfy(\.isFinite) ? result : nil
                case "*":
                    guard a.count + b.count - 2 <= 2 else { return nil }
                    var result = Array(repeating: 0.0, count: a.count + b.count - 1)
                    for i in a.indices {
                        for j in b.indices {
                            result[i + j] += a[i] * b[j]
                        }
                    }
                    return result.allSatisfy(\.isFinite) ? result : nil
                case "/":
                    guard b.count == 1, b[0] != 0 else { return nil }
                    let result = a.map { $0 / b[0] }
                    return result.allSatisfy(\.isFinite) ? result : nil
                case "^":
                    guard b.count == 1, b[0].isFinite,
                          b[0] >= 0, b[0] <= 2, b[0].rounded() == b[0] else { return nil }
                    let exponent = Int(b[0])
                    if exponent == 0 { return [1] }
                    if exponent == 1 { return a }
                    guard a.count + a.count - 2 <= 2 else { return nil }
                    var result = Array(repeating: 0.0, count: a.count * 2 - 1)
                    for i in a.indices {
                        for j in a.indices {
                            result[i + j] += a[i] * a[j]
                        }
                    }
                    return result.allSatisfy(\.isFinite) ? result : nil
                default:
                    return nil
                }
            }
        }

        func evaluate(_ x: Double) -> Double {
            switch self {
            case .number(let value): return value
            case .variable: return x
            case .unary(let op, let node): return op == "-" ? -node.evaluate(x) : node.evaluate(x)
            case .binary(let op, let left, let right):
                let a = left.evaluate(x), b = right.evaluate(x)
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return b == 0 ? .nan : a / b
                case "^": return pow(a, b)
                default: return .nan
                }
            case .function(let name, let node):
                let value = node.evaluate(x)
                switch name {
                case "sin": return sin(value)
                case "cos": return cos(value)
                case "tan": return tan(value)
                case "abs": return abs(value)
                case "sqrt": return value < 0 ? .nan : sqrt(value)
                case "exp": return exp(value)
                case "ln": return value <= 0 ? .nan : log(value)
                case "log": return value <= 0 ? .nan : log10(value)
                default: return .nan
                }
            }
        }
    }

    private struct Parser {
        private let characters: [Character]
        private var index = 0
        var isAtEnd: Bool { index == characters.count }

        init(source: String) { characters = Array(source) }

        mutating func parse() -> Node? { parseAddition() }

        private mutating func parseAddition() -> Node? {
            guard var node = parseMultiplication() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                index += 1
                guard let rhs = parseMultiplication() else { return nil }
                node = .binary(op, node, rhs)
            }
            return node
        }

        private mutating func parseMultiplication() -> Node? {
            guard var node = parseUnary() else { return nil }
            while let op = peek, op == "*" || op == "/" {
                index += 1
                guard let rhs = parseUnary() else { return nil }
                node = .binary(op, node, rhs)
            }
            // Accept conventional school notation such as 2x, 3(x + 1), and 2sin(x).
            while startsImplicitMultiplication {
                guard let rhs = parseUnary() else { return nil }
                node = .binary("*", node, rhs)
            }
            return node
        }

        private var startsImplicitMultiplication: Bool {
            guard let char = peek else { return false }
            return char == "x" || char == "(" || char.isLetter
        }

        private mutating func parsePower() -> Node? {
            guard var node = parsePrimary() else { return nil }
            if peek == "^" {
                index += 1
                // Parse the exponent as unary so 2^-2 is valid and powers remain right-associative.
                guard let rhs = parseUnary() else { return nil }
                node = .binary("^", node, rhs)
            }
            return node
        }

        private mutating func parseUnary() -> Node? {
            if peek == "+" { index += 1; return parseUnary() }
            if peek == "-" {
                index += 1
                guard let node = parseUnary() else { return nil }
                return .unary("-", node)
            }
            return parsePower()
        }

        private mutating func parsePrimary() -> Node? {
            guard let char = peek else { return nil }
            if char == "(" {
                index += 1
                guard let node = parseAddition(), peek == ")" else { return nil }
                index += 1
                return node
            }
            if char.isNumber || char == "." {
                let start = index
                while let c = peek, c.isNumber || c == "." { index += 1 }
                return Double(String(characters[start..<index])).map(Node.number)
            }
            if char.isLetter {
                let start = index
                while let c = peek, c.isLetter { index += 1 }
                let name = String(characters[start..<index])
                if name == "x" { return .variable }
                if name == "pi" { return .number(Double.pi) }
                if name == "e" { return .number(exp(1)) }
                let functions: Set<String> = ["sin", "cos", "tan", "abs", "sqrt", "exp", "ln", "log"]
                guard functions.contains(name), peek == "(" else { return nil }
                index += 1
                guard let argument = parseAddition(), peek == ")" else { return nil }
                index += 1
                return .function(name, argument)
            }
            return nil
        }

        private var peek: Character? { index < characters.count ? characters[index] : nil }
    }
}