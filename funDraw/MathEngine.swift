// MathEngine.swift — safe expression parsing, evaluation, and numerical analysis

struct MathEngine {
    private let root: Node

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

    private indirect enum Node {
        case number(Double), variable
        case unary(Character, Node)
        case binary(Character, Node, Node)
        case function(String, Node)

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