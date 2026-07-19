import Foundation
import Vision
import UIKit
import ImageIO

struct ReceiptScanResult: Equatable {
    var amount: Double?
    var merchant: String?
    var date: Date?
}

enum ReceiptTextParser {
    static func parse(lines: [String], calendar: Calendar = .current, locale: Locale = .current) -> ReceiptScanResult {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return ReceiptScanResult(amount: amount(in: cleaned), merchant: merchant(in: cleaned), date: date(in: cleaned, calendar: calendar, locale: locale))
    }

    private static func amount(in lines: [String]) -> Double? {
        var candidates: [(priority: Int, value: Double)] = []
        for line in lines {
            let lower = line.lowercased()
            let priority: Int
            if lower.contains("grand total") || lower.contains("amount paid") || lower.contains("total due") { priority = 3 }
            else if lower.range(of: #"\btotal\b"#, options: .regularExpression) != nil && !lower.contains("subtotal") { priority = 2 }
            else if lower.contains("balance") { priority = 1 }
            else { priority = 0 }
            let hasCurrency = line.range(of: #"[₹$€£¥]|\b(?:INR|USD|EUR|GBP|JPY|CAD|AUD|BDT|AED|SAR|QAR)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
            for raw in matches(pattern: #"(?:[₹$€£¥]|\b(?:INR|USD|EUR|GBP|JPY|CAD|AUD|BDT|AED|SAR|QAR|Rs\.?))?\s*([0-9][0-9, ]*(?:\.[0-9]{1,2})?)"#, in: line) {
                let normalized = raw.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
                guard let value = Double(normalized), value > 0, value < 100_000_000 else { continue }
                if priority > 0 || hasCurrency || raw.contains(".") { candidates.append((priority, value)) }
            }
        }
        return candidates.max { lhs, rhs in lhs.priority == rhs.priority ? lhs.value < rhs.value : lhs.priority < rhs.priority }?.value
    }

    private static func merchant(in lines: [String]) -> String? {
        let excluded = ["receipt", "invoice", "tax invoice", "gst", "thank you", "welcome", "date", "time", "total", "cash", "change", "phone"]
        return lines.prefix(10).first { line in
            let lower = line.lowercased(); let letters = line.filter(\.isLetter).count
            return line.count <= 80 && letters >= 3 && Double(letters) / Double(max(line.count, 1)) > 0.45 && !excluded.contains(where: lower.contains)
        }.map { DomainLogic.sanitizedText($0, maximumLength: 80) }
    }

    private static func date(in lines: [String], calendar: Calendar, locale: Locale) -> Date? {
        let text = lines.joined(separator: " ")
        let monthFirst = DateFormatter.dateFormat(fromTemplate: "MdY", options: 0, locale: locale)?.first == "M"
        let numeric = monthFirst
            ? ["M/d/yyyy", "MM/dd/yyyy", "d/M/yyyy", "dd/MM/yyyy", "M/d/yy", "d/M/yy", "d-M-yyyy", "dd-MM-yyyy"]
            : ["d/M/yyyy", "dd/MM/yyyy", "M/d/yyyy", "MM/dd/yyyy", "d-M-yyyy", "dd-MM-yyyy", "d/M/yy", "M/d/yy"]
        let patterns = [
            (#"\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b"#, ["yyyy-MM-dd", "yyyy/M/d"]),
            (#"\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b"#, numeric),
            (#"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}\b"#, ["d MMM yyyy", "d MMMM yyyy", "d MMM yy"]),
            (#"\b[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4}\b"#, ["MMM d yyyy", "MMMM d yyyy", "MMM d, yyyy", "MMMM d, yyyy"])
        ]
        for (pattern, formats) in patterns {
            guard let raw = firstMatch(pattern: pattern, in: text) else { continue }
            for format in formats {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = calendar; formatter.dateFormat = format; formatter.isLenient = false
                if let parsed = formatter.date(from: raw) { return parsed }
            }
        }
        return nil
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range, in: text) else { return nil }
        return String(text[range]).replacingOccurrences(of: ",", with: "")
    }
}

actor ReceiptScanner {
    enum ScanError: LocalizedError {
        case invalidImage, noText
        var errorDescription: String? { self == .invalidImage ? "The selected file is not a readable image." : "No receipt details could be recognized. Try a clearer, well-lit image." }
    }

    func scan(data: Data) throws -> ReceiptScanResult {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw ScanError.invalidImage }
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation, options: [:]).perform([request])
        let observations = (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.02 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { throw ScanError.noText }
        let result = ReceiptTextParser.parse(lines: lines)
        guard result.amount != nil || result.merchant != nil || result.date != nil else { throw ScanError.noText }
        return result
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up; case .upMirrored: .upMirrored; case .down: .down; case .downMirrored: .downMirrored
        case .left: .left; case .leftMirrored: .leftMirrored; case .right: .right; case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
