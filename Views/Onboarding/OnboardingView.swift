import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readingManager: ReadingManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= appState.onboardingStep ? DS.accent : DS.surface3)
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.4), value: appState.onboardingStep)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 36)
            
            // Content
            TabView(selection: $appState.onboardingStep) {
                OnboardingStep1().tag(0)
                OnboardingStep2().tag(1)
                OnboardingStep3(readingManager: readingManager).tag(2)
                OnboardingStep4().tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: appState.onboardingStep)
            
            // Buttons
            VStack(spacing: 0) {
                PrimaryButton(
                    title: appState.onboardingStep == 3 ? "Continue" : "Next",
                    icon: "chevron.right"
                ) {
                    if appState.onboardingStep < 3 {
                        withAnimation { appState.onboardingStep += 1 }
                    } else {
                        appState.completeOnboarding()
                    }
                }
                
                if appState.onboardingStep > 0 {
                    Button("Back") {
                        withAnimation { appState.onboardingStep -= 1 }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.label3)
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .background(DS.bg)
    }
}

// MARK: - Step 1: Welcome

struct OnboardingStep1: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIcon(gradient: [Color(hex: "D2C08A"), Color(hex: "A58E5E")], systemName: "book.fill")
                    .padding(.bottom, 28)
                
                Text("Read Before\nYou Scroll")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .tracking(-1.2)
                    .lineSpacing(2)
                    .padding(.bottom, 14)
                
                Text("Transform mindless screen time into 3-minute learning moments. One passage. One quiz. Then scroll away.")
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .foregroundStyle(DS.label3)
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Step 2: How It Works

struct OnboardingStep2: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIcon(gradient: [Color(hex: "8E9972"), Color(hex: "687553")], systemName: "brain")
                    .padding(.bottom, 28)
                
                Text("How It\nWorks")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .tracking(-1.2)
                    .lineSpacing(2)
                    .padding(.bottom, 14)
                
                Text("Three steps between you and your apps.")
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .foregroundStyle(DS.label3)
                    .padding(.bottom, 28)
                
                VStack(spacing: 10) {
                    FeatureRow(icon: "lock.fill", color: Color(hex: "B16953"), title: "App Gets Blocked", subtitle: "When you hit your daily time limit")
                    FeatureRow(icon: "book.fill", color: DS.accent, title: "Read a Passage", subtitle: "Short, curated readings on real topics")
                    FeatureRow(icon: "checkmark", color: Color(hex: "88A26A"), title: "Pass the Quiz", subtitle: "2/3 correct and you're in")
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Step 3: App Selection

struct OnboardingStep3: View {
    @ObservedObject var readingManager: ReadingManager
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIcon(gradient: [Color(hex: "829064"), Color(hex: "5E6B49")], systemName: "shield.fill")
                    .padding(.bottom, 28)
                
                Text("Choose Apps\nto Gate")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .tracking(-1.2)
                    .lineSpacing(2)
                    .padding(.bottom, 14)
                
                Text("Pick the apps you want to add reading checkpoints to.")
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .foregroundStyle(DS.label3)
                    .padding(.bottom, 24)
                
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(readingManager.blockedApps) { app in
                        AppSelectionTile(
                            app: app,
                            isSelected: readingManager.isAppEnabled(app.id),
                            onTap: { readingManager.toggleApp(app.id) }
                        )
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Step 4: All Set

struct OnboardingStep4: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIcon(gradient: [Color(hex: "C8B47A"), Color(hex: "9F8A56")], systemName: "trophy.fill")
                    .padding(.bottom, 28)
                
                Text("You're\nAll Set")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .tracking(-1.2)
                    .lineSpacing(2)
                    .padding(.bottom, 14)
                
                Text("Every unlock makes you smarter. Build streaks, track stats, and actually learn something while scrolling.")
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .foregroundStyle(DS.label3)
                    .padding(.bottom, 28)
                
                VStack(spacing: 10) {
                    FeatureRow(icon: "flame.fill", color: DS.accent, title: "Daily Streaks", subtitle: "Read every day to keep your streak alive", highlighted: true)
                    FeatureRow(icon: "chart.bar.fill", color: Color(hex: "8D9671"), title: "Learning Stats", subtitle: "Track passages read, accuracy, and more")
                    FeatureRow(icon: "crown.fill", color: Color(hex: "B5905F"), title: "Earn Badges", subtitle: "Complete challenges to level up")
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Components

struct OnboardingIcon: View {
    let gradient: [Color]
    let systemName: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
            )
            .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 20, y: 8)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var highlighted: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(highlighted ? DS.accent : DS.label)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.label3)
            }
            
            Spacer()
        }
        .padding(14)
        .background(highlighted ? DS.accent.opacity(0.08) : DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(highlighted ? DS.accent.opacity(0.2) : .clear, lineWidth: 1)
        )
    }
}

struct AppSelectionTile: View {
    let app: BlockedApp
    let isSelected: Bool
    let onTap: () -> Void
    
    var iconText: String {
        switch app.id {
        case "instagram": return "📷"
        case "tiktok": return "🎵"
        case "twitter": return "𝕏"
        case "youtube": return "▶️"
        case "snapchat": return "👻"
        case "reddit": return "🤖"
        default: return "📱"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(iconText)
                    .font(.system(size: 28))
                
                Text(app.name.split(separator: " ").first.map(String.init) ?? app.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.accent : DS.label3)
                
                Circle()
                    .strokeBorder(isSelected ? DS.accent : DS.surface3, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Group {
                            if isSelected {
                                Circle()
                                    .fill(DS.accent)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.black)
                                    )
                            }
                        }
                    )
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? DS.accent.opacity(0.08) : DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? DS.accent : DS.separator, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
