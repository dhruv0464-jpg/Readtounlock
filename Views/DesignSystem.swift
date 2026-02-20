import SwiftUI

// MARK: - Design Tokens

enum DS {
    // Colors
    static let bg = Color(hex: "080A07")
    static let surface = Color(hex: "12160F")
    static let surface2 = Color(hex: "1B2116")
    static let surface3 = Color(hex: "2A3224")
    static let separator = Color(hex: "333C2D")
    static let accent = Color(hex: "C8B47A")
    static let accent2 = Color(hex: "A08D59")
    static let label = Color.white
    static let label2 = Color.white.opacity(0.85)
    static let label3 = Color.white.opacity(0.6)
    static let label4 = Color.white.opacity(0.3)
    
    // Spacing
    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 14
    static let smallRadius: CGFloat = 10
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Group {
                    if disabled {
                        DS.surface2
                    } else {
                        LinearGradient(
                            colors: [DS.accent, DS.accent2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .foregroundStyle(disabled ? DS.label4 : .black)
            .clipShape(RoundedRectangle(cornerRadius: DS.buttonRadius))
            .shadow(color: disabled ? .clear : DS.accent.opacity(0.22), radius: 12, y: 6)
        }
        .disabled(disabled)
    }
}

// MARK: - iOS Toggle Row

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var isLast: Bool = false
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 18))
            Text(title)
                .font(.system(size: 16))
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(Color.green)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(DS.surface)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .background(DS.separator)
                    .padding(.leading, 52)
            }
        }
    }
}

// MARK: - Navigation Row

struct NavRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = DS.label4
    var isLast: Bool = false
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 18))
            Text(title)
                .font(.system(size: 16))
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(valueColor)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(DS.surface)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .background(DS.separator)
                    .padding(.leading, 52)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.label4)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: PassageCategory
    
    var body: some View {
        Text(category.rawValue)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(category.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.system(size: 10, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.3)
            .foregroundStyle(difficulty.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(difficulty.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Reading Card

struct ReadingCard: View {
    let passage: Passage
    let action: () -> Void
    var showDifficulty: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CategoryBadge(category: passage.category)
                    Spacer()
                    if showDifficulty {
                        DifficultyBadge(difficulty: passage.difficulty)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(passage.readTimeLabel)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(DS.label4)
                }
                
                Text(passage.title)
                    .font(.system(size: 19, weight: .bold))
                    .tracking(-0.4)
                    .lineLimit(2)
                    .foregroundStyle(DS.label)
                    .multilineTextAlignment(.leading)
                
                Text(passage.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.label3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(20)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
            Spacer()
            if let trailing {
                if let trailingAction {
                    Button(trailing, action: trailingAction)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.accent)
                } else {
                    Text(trailing)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.label4)
                }
            }
        }
    }
}

// MARK: - Grouped Section Container

struct GroupedSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(DS.label4)
                .padding(.leading, 16)
            
            VStack(spacing: 0) {
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
