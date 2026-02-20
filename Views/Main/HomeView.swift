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

    private let discoverTopics: [(icon: String, title: String, color: Color)] = [
        ("person.crop.circle.badge.checkmark", "Self-Growth", Color(hex: "9BA96B")),
        ("bubble.left.and.text.bubble.right", "Communication", Color(hex: "C7AE73")),
        ("briefcase", "Career & Business", Color(hex: "A87757")),
        ("book.closed", "Fiction", Color(hex: "8F9978")),
        ("banknote", "Finance & Economics", Color(hex: "7A8F59")),
        ("heart", "Relationships", Color(hex: "B7846A")),
    ]

    private let moodPrompts: [(title: String, subtitle: String)] = [
        ("Taking a late walk", "wanting something reflective"),
        ("Before a hard conversation", "wanting clear words"),
        ("When focus feels low", "wanting sharp concentration"),
        ("After a long day", "wanting calm and reset"),
    ]

    private var featuredPassages: [Passage] {
        Array(PassageLibrary.all.prefix(6))
    }

    private var communityPassages: [Passage] {
        let pool = PassageLibrary.all.dropFirst(6)
        return Array(pool.prefix(6))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discover")
                                .font(.system(size: 42, weight: .bold, design: .serif))
                                .tracking(-0.8)
                            Text("Hey \(appState.userName.isEmpty ? "Reader" : appState.userName), pick what to learn next.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DS.label3)
                        }
                        Spacer()

                        Button {
                            appState.selectedTab = .library
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(DS.surface2)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 14)

                    CreateLessonPromptCard {
                        appState.selectedTab = .library
                    }
                    .padding(.bottom, 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(discoverTopics, id: \.title) { topic in
                                DiscoverTopicChip(icon: topic.icon, title: topic.title, color: topic.color)
                            }
                        }
                    }
                    .padding(.bottom, 20)

                    Text("Featured")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .tracking(-0.7)
                        .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(featuredPassages) { passage in
                                FeaturedLessonCard(passage: passage) {
                                    appState.startReading(passage)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 22)

                    Text("Learn by mood")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .tracking(-0.7)
                        .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(moodPrompts, id: \.title) { mood in
                                MoodPromptCard(title: mood.title, subtitle: mood.subtitle)
                            }
                        }
                    }
                    .padding(.bottom, 22)

                    Text("More creations by community")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .tracking(-0.6)
                        .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(communityPassages) { passage in
                                FeaturedLessonCard(passage: passage, compact: true) {
                                    appState.startReading(passage)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 22)

                    Text("Daily Guardrails")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .tracking(-0.5)
                        .padding(.bottom, 10)

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
                        title: "Quick Starts",
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

struct CreateLessonPromptCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make My Own Lesson")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                    Text("Describe what you want to learn and we’ll build a reading path.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.label3)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text("Create")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(Capsule())
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "2A2418"), Color(hex: "1E2417"), Color(hex: "162013")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DiscoverTopicChip: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.label2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(DS.separator, lineWidth: 1)
        )
    }
}

struct FeaturedLessonCard: View {
    let passage: Passage
    var compact: Bool = false
    let action: () -> Void

    private var cardWidth: CGFloat { compact ? 150 : 176 }
    private var cardHeight: CGFloat { compact ? 188 : 246 }
    private var sourceCount: Int { 4 + ((passage.id * 7) % 35) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                passage.category.color.opacity(0.85),
                                Color.black.opacity(0.75),
                                passage.category.color.opacity(0.35),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(passage.title)
                        .font(.system(size: compact ? 20 : 28, weight: .bold, design: .serif))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .lineLimit(compact ? 3 : 4)
                        .padding(.bottom, 8)

                    Text("\(sourceCount) sources")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(12)
            }
            .frame(width: cardWidth, height: cardHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MoodPromptCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.label3)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 290, alignment: .leading)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
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
