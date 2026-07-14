import Foundation

@main
struct DomainLogicTests {
    static func main() {
        var failures = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures += 1; print("FAIL: \(message)") }
        }

        expect(DomainLogic.budgetProgress(spent: 500, budget: 1000) == 0.5, "budget progress")
        expect(DomainLogic.budgetProgress(spent: 1500, budget: 1000) == 1, "progress clamps at one")
        expect(DomainLogic.budgetProgress(spent: 100, budget: 0) == 0, "zero budget")
        expect(DomainLogic.budgetRemaining(spent: 1200, budget: 1000) == 0, "remaining clamps at zero")
        expect(DomainLogic.parseAmount("12.50", decimalSeparator: ".") == 12.5, "decimal amount")
        expect(DomainLogic.parseAmount("12,50", decimalSeparator: ",") == 12.5, "localized decimal amount")
        expect(DomainLogic.parseAmount("0", decimalSeparator: ".") == nil, "zero amount rejected")
        expect(DomainLogic.parseAmount("1.2.3", decimalSeparator: ".") == nil, "invalid amount rejected")
        expect(DomainLogic.sanitizedText("  hello  ", maximumLength: 10) == "hello", "text trimming")
        expect(DomainLogic.sanitizedText("123456", maximumLength: 4) == "1234", "text length cap")
        expect(DomainLogic.csvField("Cafe, \"Central\"") == "\"Cafe, \"\"Central\"\"\"", "CSV escaping")
        expect(DomainLogic.csv(rows: [["a", "b"], ["1", "2"]]) == "\"a\",\"b\"\n\"1\",\"2\"", "CSV rows")

        if failures > 0 { print("\(failures) test(s) failed"); exit(1) }
        print("All DomainLogic tests passed")
    }
}
