import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(MainTab.home)

            FreeReadView()
                .tabItem {
                    Image(systemName: "text.quote")
                    Text("Free Read")
                }
                .tag(MainTab.freeRead)
            
            LibraryView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Library")
                }
                .tag(MainTab.library)
            
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(MainTab.stats)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(MainTab.settings)
        }
        .tint(DS.accent)
    }
}

struct FreeReadFeedItem: Identifiable {
    let id: String
    let passage: Passage
    let paragraph: String
    let paragraphIndex: Int
    let totalParagraphs: Int

    static let all: [FreeReadFeedItem] = buildFeed()

    private static func buildFeed() -> [FreeReadFeedItem] {
        let normalized: [(Passage, [String])] = PassageLibrary.all.map { passage in
            let chunks = splitParagraphs(passage.content)
            return (passage, chunks.isEmpty ? [passage.content.trimmingCharacters(in: .whitespacesAndNewlines)] : chunks)
        }

        let maxParagraphs = normalized.map { $0.1.count }.max() ?? 0
        var feed: [FreeReadFeedItem] = []

        for index in 0..<maxParagraphs {
            for (passage, paragraphs) in normalized {
                guard index < paragraphs.count else { continue }
                feed.append(
                    FreeReadFeedItem(
                        id: "\(passage.id)-\(index)",
                        passage: passage,
                        paragraph: paragraphs[index],
                        paragraphIndex: index + 1,
                        totalParagraphs: paragraphs.count
                    )
                )
            }
        }

        return feed
    }

    private static func splitParagraphs(_ content: String) -> [String] {
        content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 90 }
    }
}

struct FreeReadView: View {
    @EnvironmentObject var appState: AppState

    private let feedItems = FreeReadFeedItem.all

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(feedItems.enumerated()), id: \.element.id) { index, item in
                        FreeReadCard(
                            item: item,
                            position: index + 1,
                            total: feedItems.count
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .background(DS.bg)
            .safeAreaInset(edge: .top) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free Read")
                            .font(.system(size: 22, weight: .bold))
                            .tracking(-0.5)
                        Text("Swipe up to keep reading")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.label3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [DS.bg.opacity(0.98), DS.bg.opacity(0.45), DS.bg.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .background(DS.bg)
    }
}

struct FreeReadCard: View {
    let item: FreeReadFeedItem
    let position: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 84)

            HStack(spacing: 8) {
                CategoryBadge(category: item.passage.category)
                Text("Paragraph \(item.paragraphIndex)/\(item.totalParagraphs)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.label4)
            }
            .padding(.bottom, 14)

            Text(item.passage.title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .lineSpacing(3)
                .padding(.bottom, 14)

            Text(item.paragraph)
                .font(.system(size: 21, weight: .medium))
                .lineSpacing(9)
                .foregroundStyle(DS.label2)
                .padding(.bottom, 18)

            Text(item.passage.source)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.label4)
                .lineLimit(1)
                .padding(.bottom, 14)

            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Free Read mode: no quiz, just read")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DS.label3)
            .padding(.bottom, 4)

            Spacer()

            HStack {
                Text("Card \(position) of \(total)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.label4)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text("Swipe for next")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(DS.label4)
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 22)
        .background(
            LinearGradient(
                colors: [DS.bg, DS.surface.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(DS.separator.opacity(0.2), lineWidth: 1)
            )
        )
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mgr: ReadingManager
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var showScreenTimeSetup = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good morning")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.label3)
                            Text(appState.userName.isEmpty ? "Reader" : appState.userName)
                                .font(.system(size: 28, weight: .bold))
                                .tracking(-0.8)
                        }
                        Spacer()
                        if appState.isPremiumUser {
                            HStack(spacing: 5) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 13))
                                Text("PRO")
                                    .font(.system(size: 12, weight: .black))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DS.accent)
                            .clipShape(Capsule())
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16))
                                Text("\(mgr.streak)")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(DS.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(DS.accent.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 16)

                    UnlockBudgetCard()
                        .padding(.bottom, 12)

                    if !appState.isPremiumUser {
                        UpgradeStrip {
                            appState.presentPaywall(from: .settings)
                        }
                        .padding(.bottom, 18)
                    }

                    if !screenTime.isAuthorized || !screenTime.hasSelection {
                        ScreenTimeSetupStrip {
                            showScreenTimeSetup = true
                        }
                        .padding(.bottom, 16)
                    } else {
                        ScreenTimeActiveCard(
                            protectedItems: screenTime.selectedItemsCount,
                            monitoringEnabled: screenTime.isMonitoring,
                            onTap: { showScreenTimeSetup = true }
                        )
                        .padding(.bottom, 16)
                    }
                    
                    // Stats row
                    HStack(spacing: 8) {
                        StatCard(value: "\(mgr.totalReadings)", label: "Readings")
                        StatCard(value: "\(mgr.totalMinutesRead)", label: "Minutes")
                        StatCard(value: "\(Int(mgr.quizAccuracy * 100))%", label: "Accuracy")
                    }
                    .padding(.bottom, 24)
                    
                    // Blocked apps
                    SectionHeader(
                        title: "Today's Apps",
                        trailing: "\(mgr.lockedCount) blocked"
                    )
                    .padding(.bottom, 12)
                    
                    ForEach(mgr.enabledApps) { app in
                        BlockedAppRow(app: app) {
                            if app.isLocked {
                                if appState.canUnlockBlockedApps {
                                    appState.navigate(to: .blockedOverlay(app))
                                } else {
                                    appState.presentPaywall(from: .unlockLimitReached)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.bottom, 16)
                    
                    // Suggested readings
                    SectionHeader(
                        title: "Read Now",
                        trailing: "See All",
                        trailingAction: { appState.selectedTab = .library }
                    )
                    .padding(.bottom, 12)
                    
                    ForEach(Array(PassageLibrary.all.prefix(3))) { passage in
                        ReadingCard(passage: passage) {
                            appState.startReading(passage)
                        }
                        .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, DS.screenPadding)
                .padding(.bottom, 20)
            }
            .background(DS.bg)
            .navigationBarHidden(true)
        }
        .onAppear {
            appState.refreshDailyUnlockCreditsIfNeeded()
            screenTime.bootstrap()
        }
        .sheet(isPresented: $showScreenTimeSetup) {
            ScreenTimeSetupView()
                .environmentObject(screenTime)
        }
    }
}

struct UnlockBudgetCard: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(DS.accent.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: appState.isPremiumUser ? "infinity" : "lock.open.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DS.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Unlock Budget")
                    .font(.system(size: 14, weight: .semibold))
                Text(appState.isPremiumUser
                     ? "Unlimited unlocks and unlimited reads with Pro"
                     : "\(appState.freeUnlockCreditsRemaining)/\(AppState.dailyFreeUnlockLimit) free unlocks · \(appState.freeReadCreditsRemaining)/\(AppState.dailyFreeReadLimit) free reads")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.label3)
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [DS.surface, DS.surface2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
    }
}

struct UpgradeStrip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(DS.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Go Pro for unlimited unlocks")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.label2)
                    Text("No daily cap, full reading library, advanced stats")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.label4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.label3)
            }
            .padding(12)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(DS.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScreenTimeSetupStrip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(.orange)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Finish Screen Time setup")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.label2)
                    Text("Grant access and choose apps to block for real")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.label4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.label3)
            }
            .padding(12)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(DS.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScreenTimeActiveCard: View {
    let protectedItems: Int
    let monitoringEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.green)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Time is active")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(protectedItems) protected items • \(monitoringEnabled ? "Monitoring on" : "Monitoring off")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.label3)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.label3)
            }
            .padding(12)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(DS.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Blocked App Row

struct BlockedAppRow: View {
    let app: BlockedApp
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
            HStack(spacing: 14) {
                Text(iconText)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(DS.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.label)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(app.usedMinutes)/\(app.dailyLimitMinutes) min")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(DS.label4)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DS.surface3)
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(app.barColor)
                                .frame(width: geo.size.width * min(1, app.usagePercent), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 4)
                }
                
                Text(app.isLocked ? "LOCKED" : "OPEN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(app.isLocked ? .red : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(app.isLocked ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(14)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
