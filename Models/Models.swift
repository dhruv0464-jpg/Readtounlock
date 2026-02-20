import SwiftUI

// MARK: - Passage

struct Passage: Identifiable, Codable {
    let id: Int
    let category: PassageCategory
    let title: String
    let subtitle: String
    let content: String
    let readTimeMinutes: Int
    let difficulty: Difficulty
    let questions: [Question]
    let source: String // Attribution for public domain
    
    var readTimeLabel: String { "\(readTimeMinutes) min" }
}

enum PassageCategory: String, Codable, CaseIterable {
    case science = "Science"
    case history = "History"
    case philosophy = "Philosophy"
    case economics = "Economics"
    case psychology = "Psychology"
    case literature = "Literature"
    case mathematics = "Mathematics"
    case technology = "Technology"
    
    var color: Color {
        switch self {
        case .science: return Color(hex: "9BA96B")
        case .history: return Color(hex: "B78659")
        case .philosophy: return Color(hex: "8E9778")
        case .economics: return Color(hex: "6F8958")
        case .psychology: return Color(hex: "7F8E62")
        case .literature: return Color(hex: "A87962")
        case .mathematics: return Color(hex: "C3A56A")
        case .technology: return Color(hex: "7A8651")
        }
    }
    
    var icon: String {
        switch self {
        case .science: return "atom"
        case .history: return "clock.arrow.circlepath"
        case .philosophy: return "brain.head.profile"
        case .economics: return "chart.line.uptrend.xyaxis"
        case .psychology: return "brain"
        case .literature: return "text.book.closed"
        case .mathematics: return "function"
        case .technology: return "cpu"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

struct Question: Identifiable, Codable {
    let id: Int
    let text: String
    let options: [String]
    let correctIndex: Int
}

// MARK: - Blocked App

struct BlockedApp: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let dailyLimitMinutes: Int
    var usedMinutes: Int
    
    var usagePercent: Double {
        Double(usedMinutes) / Double(dailyLimitMinutes)
    }
    
    var isLocked: Bool {
        usedMinutes >= dailyLimitMinutes
    }
    
    var barColor: Color {
        if isLocked { return .red }
        if usagePercent > 0.7 { return .orange }
        return .green
    }
}

// MARK: - User Stats

struct DayStat: Identifiable {
    let id = UUID()
    let dayLabel: String
    let readings: Int
    let minutes: Int
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
