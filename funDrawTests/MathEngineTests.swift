import XCTest
@testable import funDraw

final class MathEngineTests: XCTestCase {
    func testValidExpressionsAndImplicitMultiplication() throws {
        let linear = try XCTUnwrap(MathEngine(expression: "y = 2x + 1"))
        XCTAssertEqual(try XCTUnwrap(linear.value(3)), 7, accuracy: 1e-10)

        let quadratic = try XCTUnwrap(MathEngine(expression: "x² − 4"))
        XCTAssertEqual(try XCTUnwrap(quadratic.value(3)), 5, accuracy: 1e-10)

        let implicit = try XCTUnwrap(MathEngine(expression: "2(x + 1)"))
        XCTAssertEqual(try XCTUnwrap(implicit.value(2)), 6, accuracy: 1e-10)

        let trig = try XCTUnwrap(MathEngine(expression: "sin(pi / 2)"))
        XCTAssertEqual(try XCTUnwrap(trig.value(0)), 1, accuracy: 1e-10)
    }

    func testInvalidExpressionsAreRejected() {
        XCTAssertNil(MathEngine(expression: ""))
        XCTAssertNil(MathEngine(expression: "y = "))
        XCTAssertNil(MathEngine(expression: "(x + 1"))
        XCTAssertNil(MathEngine(expression: "x +"))
        XCTAssertNil(MathEngine(expression: "unknown(x)"))
        XCTAssertNil(MathEngine(expression: "x @ 2"))
        XCTAssertNil(MathEngine(expression: "sin x"))
    }

    func testOperatorPrecedenceAndAssociativity() throws {
        let negativePower = try XCTUnwrap(MathEngine(expression: "-x^2"))
        XCTAssertEqual(try XCTUnwrap(negativePower.value(3)), -9, accuracy: 1e-10)

        let negativeExponent = try XCTUnwrap(MathEngine(expression: "2^-2"))
        XCTAssertEqual(try XCTUnwrap(negativeExponent.value(0)), 0.25, accuracy: 1e-10)

        let rightAssociative = try XCTUnwrap(MathEngine(expression: "2^3^2"))
        XCTAssertEqual(try XCTUnwrap(rightAssociative.value(0)), 512, accuracy: 1e-10)

        let multiplicationBeforeAddition = try XCTUnwrap(MathEngine(expression: "2 + 3 * 4"))
        XCTAssertEqual(try XCTUnwrap(multiplicationBeforeAddition.value(0)), 14, accuracy: 1e-10)
    }

    func testDomainBoundariesAndNonFiniteResults() throws {
        let squareRoot = try XCTUnwrap(MathEngine(expression: "sqrt(x)"))
        XCTAssertNil(squareRoot.value(-0.001))
        XCTAssertEqual(try XCTUnwrap(squareRoot.value(0)), 0, accuracy: 1e-10)

        let logarithm = try XCTUnwrap(MathEngine(expression: "ln(x)"))
        XCTAssertNil(logarithm.value(0))
        XCTAssertNil(logarithm.value(-1))

        let reciprocal = try XCTUnwrap(MathEngine(expression: "1/x"))
        XCTAssertNil(reciprocal.value(0))
        XCTAssertEqual(try XCTUnwrap(reciprocal.value(2)), 0.5, accuracy: 1e-10)
    }

    func testNumericalZerosIncludeCrossingsAndTangentRoots() throws {
        let crossing = try XCTUnwrap(MathEngine(expression: "x^2 - 4"))
        let roots = crossing.approximateZeros(in: -5...5)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], -2, accuracy: 1e-5)
        XCTAssertEqual(roots[1], 2, accuracy: 1e-5)

        let tangent = try XCTUnwrap(MathEngine(expression: "x^2"))
        let tangentRoots = tangent.approximateZeros(in: -1.7...2.3)
        XCTAssertTrue(tangentRoots.contains { abs($0) < 1e-4 })
    }

    func testYInterceptCanBeUndefined() throws {
        let reciprocal = try XCTUnwrap(MathEngine(expression: "1/x"))
        XCTAssertNil(reciprocal.value(0))

        let linear = try XCTUnwrap(MathEngine(expression: "2x + 3"))
        XCTAssertEqual(try XCTUnwrap(linear.value(0)), 3, accuracy: 1e-10)
    }
    func testQuadraticAnalysisExtractsVertexAndAxis() throws {
        let upward = try XCTUnwrap(MathEngine(expression: "y = x^2 - 4x + 1").quadraticAnalysis)
        XCTAssertEqual(upward.a, 1, accuracy: 1e-10)
        XCTAssertEqual(upward.b, -4, accuracy: 1e-10)
        XCTAssertEqual(upward.c, 1, accuracy: 1e-10)
        XCTAssertEqual(upward.vertexX, 2, accuracy: 1e-10)
        XCTAssertEqual(upward.vertexY, -3, accuracy: 1e-10)
        XCTAssertEqual(upward.axisOfSymmetry, 2, accuracy: 1e-10)
        XCTAssertNil(MathEngine(expression: "x^3 + x").quadraticAnalysis)
        XCTAssertNil(MathEngine(expression: "2x + 1").quadraticAnalysis)
    }

    func testCoincidentFunctionsDoNotProduceThousandsOfIntersections() throws {
        let first = try XCTUnwrap(MathEngine(expression: "x^2 + 1"))
        XCTAssertTrue(first.approximateIntersections(in: -5...5, withFunction: { x in x * x + 1 }).isEmpty)
    }

    func testTangentRootsAndTangentialIntersections() throws {
        let fourthPower = try XCTUnwrap(MathEngine(expression: "x^4"))
        XCTAssertTrue(fourthPower.approximateZeros(in: -1.3...2.1).contains { abs($0) < 1e-4 })

        let aboveAxis = try XCTUnwrap(MathEngine(expression: "x^2 + 0.01"))
        XCTAssertTrue(aboveAxis.approximateZeros(in: -2...2).isEmpty)

        let parabola = try XCTUnwrap(MathEngine(expression: "x^2"))
        let roots = parabola.approximateIntersections(in: -2...2, withFunction: { _ in 0 })
        XCTAssertTrue(roots.contains { abs($0) < 1e-4 })
    }

}
