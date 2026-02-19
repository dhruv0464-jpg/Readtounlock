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

struct FreeReadFeedItem {
    let passage: Passage
    let excerpt: String
    let segmentIndex: Int
    let totalSegments: Int

    var stableID: String { "\(passage.id)-\(segmentIndex)" }

    var baseLikeCount: Int {
        120 + ((passage.id * 89 + segmentIndex * 41) % 9200)
    }

    var shareText: String {
        "\"\(excerpt)\"\n\nFrom: \(passage.title) • \(passage.category.rawValue)\nShared from Readtounlock"
    }

    static let seedPool: [FreeReadFeedItem] = buildSeedPool()

    private static func buildSeedPool() -> [FreeReadFeedItem] {
        let normalized: [(Passage, [String])] = PassageLibrary.all.map { passage in
            let segments = splitIntoSegments(passage.content)
            return (passage, segments.isEmpty ? [passage.content.trimmingCharacters(in: .whitespacesAndNewlines)] : segments)
        }

        let maxSegments = normalized.map { $0.1.count }.max() ?? 0
        var pool: [FreeReadFeedItem] = []

        for segmentOffset in 0..<maxSegments {
            for (passage, segments) in normalized {
                guard segmentOffset < segments.count else { continue }
                pool.append(
                    FreeReadFeedItem(
                        passage: passage,
                        excerpt: segments[segmentOffset],
                        segmentIndex: segmentOffset + 1,
                        totalSegments: segments.count
                    )
                )
            }
        }

        return pool
    }

    // Build longer reel cards: each item is a coherent multi-paragraph chunk.
    private static func splitIntoSegments(_ content: String) -> [String] {
        let paragraphs = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 40 }

        guard !paragraphs.isEmpty else { return [] }

        let targetChars = 950
        var segments: [String] = []
        var current: [String] = []
        var currentCount = 0

        for paragraph in paragraphs {
            let nextCount = currentCount + paragraph.count + (current.isEmpty ? 0 : 2)
            if !current.isEmpty && nextCount > targetChars {
                segments.append(current.joined(separator: "\n\n"))
                current = [paragraph]
                currentCount = paragraph.count
            } else {
                current.append(paragraph)
                currentCount = nextCount
            }
        }

        if !current.isEmpty {
            segments.append(current.joined(separator: "\n\n"))
        }

        return segments
    }
}

struct FreeReadRenderItem: Identifiable {
    let id = UUID()
    let content: FreeReadFeedItem
}

struct FreeReadView: View {
    private let likesStorageKey = "freeReadLikedPassageIDs"
    private let batchSize = 24
    private let prefetchThreshold = 8

    @State private var feed: [FreeReadRenderItem] = []
    @State private var seedPool: [FreeReadFeedItem] = []
    @State private var seedCursor: Int = 0
    @State private var likedPassageIDs: Set<Int> = Set(UserDefaults.standard.array(forKey: "freeReadLikedPassageIDs") as? [Int] ?? [])

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(feed.enumerated()), id: \.element.id) { index, item in
                        FreeReadCard(
                            item: item.content,
                            isLiked: likedPassageIDs.contains(item.content.passage.id),
                            onLike: { toggleLike(for: item.content) }
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .onAppear {
                            if index >= feed.count - prefetchThreshold {
                                appendBatch()
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .background(DS.bg)
        }
        .background(DS.bg)
        .onAppear {
            bootFeedIfNeeded()
        }
    }

    private func bootFeedIfNeeded() {
        guard feed.isEmpty else { return }
        seedPool = FreeReadFeedItem.seedPool.shuffled()
        appendBatch()
        appendBatch()
    }

    private func appendBatch() {
        guard !FreeReadFeedItem.seedPool.isEmpty else { return }
        if seedPool.isEmpty { seedPool = FreeReadFeedItem.seedPool.shuffled() }

        var newItems: [FreeReadRenderItem] = []
        newItems.reserveCapacity(batchSize)

        for _ in 0..<batchSize {
            if seedCursor >= seedPool.count {
                seedPool.shuffle()
                seedCursor = 0
            }
            newItems.append(FreeReadRenderItem(content: seedPool[seedCursor]))
            seedCursor += 1
        }

        feed.append(contentsOf: newItems)
    }

    private func toggleLike(for item: FreeReadFeedItem) {
        if likedPassageIDs.contains(item.passage.id) {
            likedPassageIDs.remove(item.passage.id)
        } else {
            likedPassageIDs.insert(item.passage.id)
        }
        UserDefaults.standard.set(Array(likedPassageIDs), forKey: likesStorageKey)
    }
}

struct FreeReadCard: View {
    let item: FreeReadFeedItem
    let isLiked: Bool
    let onLike: () -> Void

    private var likeCount: Int { item.baseLikeCount + (isLiked ? 1 : 0) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [
                    DS.bg,
                    item.passage.category.color.opacity(0.26),
                    DS.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.black.opacity(0.0), Color.black.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()

            contentOverlay
                .padding(.leading, 20)
                .padding(.trailing, 88)
                .padding(.bottom, 32)

            actionRail
                .padding(.trailing, 12)
                .padding(.bottom, 88)
        }
        .background(DS.bg)
    }

    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack(spacing: 8) {
                Text(item.passage.category.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(item.passage.category.color)
                    .clipShape(Capsule())

                Text("Part \(item.segmentIndex)/\(item.totalSegments)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.label4)
            }
            .padding(.bottom, 10)

            Text(item.passage.title)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .lineLimit(2)
                .foregroundStyle(.white)
                .padding(.bottom, 10)

            Text(item.excerpt)
                .font(.system(size: 16.5, weight: .medium))
                .lineSpacing(6)
                .foregroundStyle(DS.label2)
                .lineLimit(18)
                .padding(.bottom, 10)

            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                Text("Swipe for next")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(DS.label4)
        }
    }

    private var actionRail: some View {
        VStack(spacing: 18) {
            Button(action: onLike) {
                VStack(spacing: 5) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(isLiked ? .red : .white)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.28))
                        .clipShape(Circle())

                    Text(formatCount(likeCount))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            ShareLink(item: item.shareText) {
                VStack(spacing: 5) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.28))
                        .clipShape(Circle())

                    Text("Share")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000).replacingOccurrences(of: ".0K", with: "K")
        }
        return "\(value)"
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
