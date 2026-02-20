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

struct FreeReadStory {
    let id: String
    let title: String
    let quote: String
    let body: String
    let category: PassageCategory
    let source: String
    let symbol: String
    let palette: [Color]
}

struct FreeReadFeedItem {
    let stableID: String
    let title: String
    let quote: String
    let body: String
    let category: PassageCategory
    let source: String
    let symbol: String
    let palette: [Color]
    let sequenceLabel: String

    var visualSeed: Int {
        FreeReadFeedItem.deterministicSeed(stableID)
    }

    var baseLikeCount: Int {
        220 + (visualSeed % 9400)
    }

    var shareText: String {
        let preview = body.count > 320 ? "\(body.prefix(320))..." : body
        return "\"\(quote)\"\n\n\(preview)\n\n\(source)\nShared from Readtounlock"
    }

    static let seedPool: [FreeReadFeedItem] = buildSeedPool()

    private static func buildSeedPool() -> [FreeReadFeedItem] {
        let curated = curatedStories.map { story in
            FreeReadFeedItem(
                stableID: "story-\(story.id)",
                title: story.title,
                quote: story.quote,
                body: story.body,
                category: story.category,
                source: story.source,
                symbol: story.symbol,
                palette: story.palette,
                sequenceLabel: "Editorial"
            )
        }

        let passageDerived = buildPassageDerivedFeedItems()
        return curated + passageDerived
    }

    private static func buildPassageDerivedFeedItems() -> [FreeReadFeedItem] {
        var items: [FreeReadFeedItem] = []

        for passage in PassageLibrary.all {
            let segments = splitIntoSegments(passage.content)
            guard !segments.isEmpty else { continue }

            for (index, segment) in segments.prefix(2).enumerated() {
                items.append(
                    FreeReadFeedItem(
                        stableID: "library-\(passage.id)-\(index)",
                        title: passage.title,
                        quote: quoteFromSegment(segment),
                        body: segment,
                        category: passage.category,
                        source: "From library: \(passage.source)",
                        symbol: passage.category.icon,
                        palette: palette(for: passage.category),
                        sequenceLabel: "Library \(index + 1)/\(segments.count)"
                    )
                )
            }
        }

        return items
    }

    private static func splitIntoSegments(_ content: String) -> [String] {
        let paragraphs = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 45 }

        guard !paragraphs.isEmpty else { return [] }

        let targetChars = 680
        var segments: [String] = []
        var current: [String] = []
        var count = 0

        for paragraph in paragraphs {
            let nextCount = count + paragraph.count + (current.isEmpty ? 0 : 2)
            if !current.isEmpty && nextCount > targetChars {
                segments.append(current.joined(separator: "\n\n"))
                current = [paragraph]
                count = paragraph.count
            } else {
                current.append(paragraph)
                count = nextCount
            }
        }

        if !current.isEmpty {
            segments.append(current.joined(separator: "\n\n"))
        }

        return segments
    }

    private static func quoteFromSegment(_ segment: String) -> String {
        let flattened = segment.replacingOccurrences(of: "\n", with: " ")
        let sentences = flattened
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 35 }

        if let first = sentences.first {
            return first.count > 118 ? "\(first.prefix(118))..." : first
        }

        return flattened.count > 118 ? "\(flattened.prefix(118))..." : flattened
    }

    private static func deterministicSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { current, scalar in
            (current * 33 + Int(scalar.value)) % 10_000
        }
    }

    private static func palette(for category: PassageCategory) -> [Color] {
        switch category {
        case .science: return [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        case .history: return [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        case .philosophy: return [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        case .economics: return [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        case .psychology: return [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        case .literature: return [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        case .mathematics: return [Color(hex: "5E3F22"), Color(hex: "402C17"), Color(hex: "20160B")]
        case .technology: return [Color(hex: "4A361F"), Color(hex: "332515"), Color(hex: "1A130A")]
        }
    }

    private static let curatedStories: [FreeReadStory] = [
        FreeReadStory(
            id: "attention-room",
            title: "Attention Is a Room",
            quote: "Where your attention sits, your life gets built.",
            body: """
            Most people treat attention like weather, something that happens to them. But attention behaves more like architecture. Every notification, open tab, and unfinished thread is furniture inside your mental room.

            If that room is crowded, your thinking feels expensive. If it is clear, ideas connect fast. The quality of your decisions is often less about intelligence and more about how clean your room is before you decide.

            Tonight, remove one source of noise and read one thing deeply. Protecting a single focused hour is not a productivity trick. It is identity work.
            """,
            category: .psychology,
            source: "ReadToUnlock Editorial",
            symbol: "sparkles.rectangle.stack.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "borrowed-urgency",
            title: "Stop Borrowing Urgency",
            quote: "If everything feels urgent, none of it was chosen.",
            body: """
            Digital feeds train us to inherit urgency from strangers. A hot take, a trend, a deadline that is not yours, and suddenly your nervous system is sprinting without a map.

            Borrowed urgency creates shallow work and restless evenings. Chosen urgency creates momentum. One is panic. The other is leadership.

            Before opening your next app, ask: what actually matters in the next hour? Write one sentence. Then let that sentence be louder than the feed.
            """,
            category: .philosophy,
            source: "ReadToUnlock Editorial",
            symbol: "flame.fill",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "small-decisions",
            title: "Why Small Decisions Drain You",
            quote: "Decision fatigue is not weakness. It is unbudgeted energy.",
            body: """
            The brain spends fuel on every choice, even tiny ones. What to wear, what to reply, what to open next. None of these feels heavy alone, but together they tax your control systems.

            High performers do not avoid decisions. They automate the trivial so they can spend energy where stakes are real. Same breakfast, fixed focus blocks, fewer app switches.

            Make one default rule today. Keep your energy for the decisions that shape tomorrow.
            """,
            category: .science,
            source: "ReadToUnlock Editorial",
            symbol: "brain.head.profile",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "twenty-minutes",
            title: "The Quiet Compounding of 20 Minutes",
            quote: "Twenty focused minutes daily can outrun random two-hour bursts.",
            body: """
            People underestimate steady effort because it looks small in the moment. But compounding never announces itself early. It looks ordinary until it looks inevitable.

            One page a day becomes thirty books in a few years. One note daily becomes a personal archive of ideas. One clear session beats five distracted marathons.

            Protect a non-negotiable 20-minute reading block. Future you will call it leverage.
            """,
            category: .economics,
            source: "ReadToUnlock Editorial",
            symbol: "chart.line.uptrend.xyaxis",
            palette: [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        ),
        FreeReadStory(
            id: "social-courage",
            title: "Social Courage Is Trainable",
            quote: "Confidence often arrives after action, not before it.",
            body: """
            We wait to feel ready before speaking up, introducing ourselves, or asking better questions. But readiness rarely appears first. Repetition creates readiness.

            Social courage grows from small reps: one thoughtful message, one honest question, one uncomfortable but respectful conversation. Neural pathways care more about frequency than intensity.

            Your next brave moment can be tiny. Tiny still counts.
            """,
            category: .psychology,
            source: "ReadToUnlock Editorial",
            symbol: "person.2.wave.2.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "history-patterns",
            title: "History Rewards Pattern Hunters",
            quote: "History does not repeat exactly, but it rhymes loudly.",
            body: """
            Great readers of history are not memorizing dates for trivia points. They are training pattern recognition under pressure: incentives, power shifts, overconfidence, recovery.

            When you study prior cycles, current headlines become less confusing. You can separate noise from signal because you have seen this shape before, just in different clothes.

            Read one historical case this week and ask: what human pattern is timeless here?
            """,
            category: .history,
            source: "ReadToUnlock Editorial",
            symbol: "building.columns.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "read-like-builder",
            title: "Read Like a Builder",
            quote: "Do not read to finish pages. Read to build mental tools.",
            body: """
            Passive reading feels productive but often evaporates by evening. Builder reading is different. You capture one model, one question, one application for your real life.

            The strongest readers annotate in outcomes: what decision will this improve? what behavior should change? what assumption did this challenge?

            A single implemented insight is worth more than ten highlighted chapters.
            """,
            category: .technology,
            source: "ReadToUnlock Editorial",
            symbol: "hammer.fill",
            palette: [Color(hex: "4A361F"), Color(hex: "332515"), Color(hex: "1A130A")]
        ),
        FreeReadStory(
            id: "context-switching",
            title: "The Hidden Tax of Context Switching",
            quote: "Every switch leaves cognitive residue.",
            body: """
            Moving from app to app feels harmless because each jump is short. The cost shows up later as slower recall, fuzzy priorities, and mental drag.

            Your brain needs re-entry time each time attention shifts. That overhead can consume more than the task itself when interruptions are constant.

            Batch similar tasks. Read in uninterrupted chunks. Defend transitions as seriously as you defend deadlines.
            """,
            category: .science,
            source: "ReadToUnlock Editorial",
            symbol: "arrow.left.arrow.right.square.fill",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "math-of-weeks",
            title: "The Math of Better Weeks",
            quote: "A good week is designed, not discovered.",
            body: """
            If your week has no structure, mood becomes strategy. You work hard but drift. A simple weekly map changes everything: deep work blocks, reading windows, reflection slots.

            Mathematically, even a 10 percent improvement in each day creates a week that feels radically different. Direction compounds faster than intensity.

            Sunday planning is not bureaucracy. It is pre-commitment to the person you want to be by Friday.
            """,
            category: .mathematics,
            source: "ReadToUnlock Editorial",
            symbol: "function",
            palette: [Color(hex: "5E3F22"), Color(hex: "402C17"), Color(hex: "20160B")]
        ),
        FreeReadStory(
            id: "quality-inputs",
            title: "Your Inputs Become Your Inner Voice",
            quote: "What you read repeatedly becomes how you think automatically.",
            body: """
            Most people protect their schedules but ignore their informational diet. Yet thoughts are made of inputs. Scroll chaos leads to chaotic thinking. High signal inputs create clear internal language.

            Curate your feed like an athlete curates nutrition. Fewer empty calories. More dense material that sharpens judgment.

            You do not need perfect discipline. You need better defaults.
            """,
            category: .literature,
            source: "ReadToUnlock Editorial",
            symbol: "text.book.closed.fill",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "one-question",
            title: "One Question Before Any App",
            quote: "Open with intention or be opened by the algorithm.",
            body: """
            Most app sessions begin unconsciously. A small pause changes the whole session: what am I here to do in the next ten minutes?

            That question restores agency. Suddenly, scrolling becomes a choice with boundaries, not a default with no end state.

            Intentional use does not mean never relaxing. It means deciding before the feed decides for you.
            """,
            category: .technology,
            source: "ReadToUnlock Editorial",
            symbol: "app.badge.checkmark",
            palette: [Color(hex: "4A361F"), Color(hex: "332515"), Color(hex: "1A130A")]
        ),
        FreeReadStory(
            id: "long-view",
            title: "The Long View Beats the Loud Moment",
            quote: "Do not trade long-term clarity for short-term stimulation.",
            body: """
            The modern attention economy is optimized for now. But most meaningful outcomes live in later: skills, trust, reputation, mastery.

            When you choose reading over reflexive scrolling, you are not rejecting fun. You are investing in a broader timeline where your decisions gain weight.

            Ask what future this next hour belongs to. Then act accordingly.
            """,
            category: .philosophy,
            source: "ReadToUnlock Editorial",
            symbol: "hourglass.bottomhalf.filled",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
    ]
}

struct FreeReadRenderItem: Identifiable {
    let id = UUID()
    let content: FreeReadFeedItem
}

struct FreeReadView: View {
    private let likesStorageKey = "freeReadLikedStoryIDs"
    private let batchSize = 24
    private let prefetchThreshold = 8

    @State private var feed: [FreeReadRenderItem] = []
    @State private var seedPool: [FreeReadFeedItem] = []
    @State private var seedCursor: Int = 0
    @State private var likedStoryIDs: Set<String> = Set(UserDefaults.standard.array(forKey: "freeReadLikedStoryIDs") as? [String] ?? [])

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(feed.enumerated()), id: \.element.id) { index, item in
                        FreeReadCard(
                            item: item.content,
                            isLiked: likedStoryIDs.contains(item.content.stableID),
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
        if likedStoryIDs.contains(item.stableID) {
            likedStoryIDs.remove(item.stableID)
        } else {
            likedStoryIDs.insert(item.stableID)
        }
        UserDefaults.standard.set(Array(likedStoryIDs), forKey: likesStorageKey)
    }
}

struct FreeReadCard: View {
    let item: FreeReadFeedItem
    let isLiked: Bool
    let onLike: () -> Void

    private var likeCount: Int { item.baseLikeCount + (isLiked ? 1 : 0) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            backgroundLayer
                .ignoresSafeArea()

            contentOverlay
                .padding(.leading, 20)
                .padding(.trailing, 88)
                .padding(.bottom, 28)

            actionRail
                .padding(.trailing, 12)
                .padding(.bottom, 88)
        }
        .background(DS.bg)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                item.palette[2].opacity(0.88),
                DS.bg,
                item.palette[0].opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(StarFieldOverlay(seed: item.visualSeed, starCount: 30))
        .overlay(
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.0), Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack(spacing: 8) {
                Text(item.category.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(item.category.color)
                    .clipShape(Capsule())

                Text(item.sequenceLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.label4)
            }
            .padding(.bottom, 10)

            coverArt
                .padding(.bottom, 12)

            Text("\"\(item.quote)\"")
                .font(.system(size: 25, weight: .bold, design: .serif))
                .tracking(-0.4)
                .lineLimit(3)
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            Text(item.body)
                .font(.system(size: 16, weight: .medium))
                .lineSpacing(6)
                .foregroundStyle(DS.label2)
                .lineLimit(11)
                .padding(.bottom, 8)

            Text(item.source)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.label4)
                .lineLimit(1)
                .padding(.bottom, 8)

            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                Text("Swipe for next story")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(DS.label4)
        }
    }

    private var coverArt: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: item.palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            StarFieldOverlay(seed: item.visualSeed + 901, starCount: 18)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .opacity(0.8)

            Image(systemName: item.symbol)
                .font(.system(size: 86, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .offset(x: 48, y: 12)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Night Read")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(DS.accent)
                Text(item.title)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .tracking(-0.4)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(14)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var actionRail: some View {
        VStack(spacing: 18) {
            Button(action: onLike) {
                VStack(spacing: 5) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(isLiked ? .red : .white)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.32))
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
                        .background(Color.black.opacity(0.32))
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

struct StarFieldOverlay: View {
    let seed: Int
    let starCount: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<starCount, id: \.self) { index in
                    let xRatio = pseudoRandom(index, salt: 17)
                    let yRatio = pseudoRandom(index, salt: 41)
                    let starSize = 1.0 + pseudoRandom(index, salt: 73) * 2.8
                    let alpha = 0.18 + pseudoRandom(index, salt: 101) * 0.72

                    Circle()
                        .fill(Color.white.opacity(alpha))
                        .frame(width: starSize, height: starSize)
                        .position(
                            x: xRatio * geo.size.width,
                            y: yRatio * geo.size.height
                        )
                }
            }
        }
    }

    private func pseudoRandom(_ index: Int, salt: Int) -> CGFloat {
        let value = (seed * (index + 11) + salt * 1_187 + index * 373) % 997
        return CGFloat(value) / 997.0
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mgr: ReadingManager
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var showScreenTimeSetup = false
    @State private var showPersonalization = false
    @AppStorage("personalizationCategoryCSV") private var personalizationCategoryCSV = ""
    @AppStorage("personalizationPrompt") private var personalizationPrompt = ""

    private let discoverTopics: [(icon: String, title: String, color: Color, category: PassageCategory)] = [
        ("person.crop.circle.badge.checkmark", "Self-Growth", Color(hex: "EDBE53"), .psychology),
        ("bubble.left.and.text.bubble.right", "Communication", Color(hex: "D4A853"), .philosophy),
        ("briefcase", "Career & Business", Color(hex: "C48B5C"), .economics),
        ("book.closed", "Fiction", Color(hex: "B8A472"), .literature),
        ("banknote", "Finance & Economics", Color(hex: "C9A65A"), .economics),
        ("heart", "Relationships", Color(hex: "C49670"), .psychology),
    ]

    private let moodPrompts: [(title: String, subtitle: String)] = [
        ("Taking a late walk", "wanting something reflective"),
        ("Before a hard conversation", "wanting clear words"),
        ("When focus feels low", "wanting sharp concentration"),
        ("After a long day", "wanting calm and reset"),
    ]

    private var preferredCategories: Set<PassageCategory> {
        decodeStoredCategories(from: personalizationCategoryCSV)
    }

    private var personalizedFeed: [Passage] {
        let all = PassageLibrary.all
        guard !preferredCategories.isEmpty else { return all }

        let prioritized = all.filter { preferredCategories.contains($0.category) }
        let fallback = all.filter { !preferredCategories.contains($0.category) }
        return prioritized + fallback
    }

    private var featuredPassages: [Passage] {
        Array(personalizedFeed.prefix(6))
    }

    private var communityPassages: [Passage] {
        let feed = personalizedFeed
        if feed.count <= 6 { return feed }
        return Array(feed.dropFirst(6).prefix(6))
    }

    private var quickStartPassages: [Passage] {
        Array(personalizedFeed.prefix(3))
    }

    private var discoverSubtitle: String {
        if !personalizationPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return personalizationPrompt
        }
        if !preferredCategories.isEmpty {
            return "Your learning plan is active. Pick what to dive into next."
        }
        return "Hey \(appState.userName.isEmpty ? "Reader" : appState.userName), pick what to learn next."
    }

    private var featuredTitle: String {
        preferredCategories.isEmpty ? "Featured" : "For You"
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
                            Text(discoverSubtitle)
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
                        showPersonalization = true
                    }
                    .padding(.bottom, 14)

                    if !preferredCategories.isEmpty {
                        PersonalizedPlanSummaryCard(
                            selectedCategories: preferredCategories,
                            customPrompt: personalizationPrompt
                        ) {
                            showPersonalization = true
                        }
                        .padding(.bottom, 14)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(discoverTopics, id: \.title) { topic in
                                DiscoverTopicChip(
                                    icon: topic.icon,
                                    title: topic.title,
                                    color: topic.color,
                                    isSelected: preferredCategories.contains(topic.category)
                                ) {
                                    togglePreferredCategory(topic.category)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)

                    Text(featuredTitle)
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
                        title: preferredCategories.isEmpty ? "Quick Starts" : "Quick Starts for Your Plan",
                        trailing: "See All",
                        trailingAction: { appState.selectedTab = .library }
                    )
                    .padding(.bottom, 12)
                    
                    ForEach(quickStartPassages) { passage in
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
        .fullScreenCover(isPresented: $showPersonalization) {
            PersonalizationPlanView(
                isPresented: $showPersonalization,
                storedCategoryCSV: $personalizationCategoryCSV,
                customPrompt: $personalizationPrompt
            )
        }
    }

    private func togglePreferredCategory(_ category: PassageCategory) {
        var updated = preferredCategories
        if updated.contains(category) {
            updated.remove(category)
        } else {
            updated.insert(category)
        }
        personalizationCategoryCSV = encodeStoredCategories(updated)
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
                    colors: [Color(hex: "3D2615"), Color(hex: "2A1B10"), Color(hex: "1A130A")],
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
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? .black : color)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .black : DS.label2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? color : DS.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? color : DS.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PersonalizedPlanSummaryCard: View {
    let selectedCategories: Set<PassageCategory>
    let customPrompt: String
    let editAction: () -> Void

    private var summaryText: String {
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty { return prompt }
        return selectedCategories
            .map(\.rawValue)
            .sorted()
            .joined(separator: " • ")
    }

    var body: some View {
        Button(action: editAction) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(DS.accent.opacity(0.18))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DS.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Personal Learning Plan")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(summaryText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.label3)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.label3)
            }
            .padding(12)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(DS.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PersonalizationPlan: Identifiable {
    let id: String
    let title: String
    let planCount: Int
    let categories: Set<PassageCategory>
    let symbol: String
    let colors: [Color]
}

struct PersonalizationPlanView: View {
    @Binding var isPresented: Bool
    @Binding var storedCategoryCSV: String
    @Binding var customPrompt: String

    @State private var draftPrompt = ""
    @State private var selectedCategories: Set<PassageCategory> = []

    private let planCards: [PersonalizationPlan] = [
        PersonalizationPlan(
            id: "career",
            title: "Career & Leadership",
            planCount: 12,
            categories: [.economics, .technology, .history],
            symbol: "person.crop.square.filled.and.at.rectangle",
            colors: [Color(hex: "58371F"), Color(hex: "6B4D2E"), Color(hex: "1A130A")]
        ),
        PersonalizationPlan(
            id: "finance",
            title: "Finance",
            planCount: 6,
            categories: [.economics, .mathematics],
            symbol: "banknote.fill",
            colors: [Color(hex: "3D2615"), Color(hex: "5C3A22"), Color(hex: "1E130A")]
        ),
        PersonalizationPlan(
            id: "philosophy-history",
            title: "Philosophy & History",
            planCount: 9,
            categories: [.philosophy, .history, .literature],
            symbol: "building.columns.fill",
            colors: [Color(hex: "4D3B24"), Color(hex: "6B5838"), Color(hex: "1A150D")]
        ),
        PersonalizationPlan(
            id: "productivity",
            title: "Productivity",
            planCount: 7,
            categories: [.psychology, .technology, .science],
            symbol: "clock.fill",
            colors: [Color(hex: "53381E"), Color(hex: "6A4F30"), Color(hex: "1D140A")]
        ),
        PersonalizationPlan(
            id: "relationships",
            title: "Relationships",
            planCount: 8,
            categories: [.psychology, .literature],
            symbol: "person.2.fill",
            colors: [Color(hex: "5A3D28"), Color(hex: "72563A"), Color(hex: "1E150D")]
        ),
        PersonalizationPlan(
            id: "social-skills",
            title: "Social Skills",
            planCount: 14,
            categories: [.psychology, .philosophy],
            symbol: "person.3.fill",
            colors: [Color(hex: "4A361F"), Color(hex: "5E4530"), Color(hex: "1A130A")]
        ),
    ]

    private let categoryColumns = [GridItem(.adaptive(minimum: 112), spacing: 8)]
    private let planColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DS.bg, Color(hex: "100C08"), Color(hex: "0C0907")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        offerBanner
                            .padding(.bottom, 18)

                        Text("Build my own")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .padding(.bottom, 8)

                        TextEditor(text: $draftPrompt)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(minHeight: 88, maxHeight: 120)
                            .padding(12)
                            .background(DS.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(DS.separator, lineWidth: 1)
                            )
                            .padding(.bottom, 10)
                            .overlay(alignment: .topLeading) {
                                if draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("I want to get better at public speaking and confidence...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(DS.label4)
                                        .padding(.leading, 24)
                                        .padding(.top, 24)
                                        .allowsHitTesting(false)
                                }
                            }

                        Button {
                            generatePlanFromPrompt()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Generate my plan")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "EDBE53"))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 18)

                        Text("Trending plans")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .tracking(-0.6)
                            .padding(.bottom, 10)

                        LazyVGrid(columns: planColumns, spacing: 10) {
                            ForEach(planCards) { plan in
                                PersonalizationPlanCard(
                                    plan: plan,
                                    isSelected: plan.categories.isSubset(of: selectedCategories)
                                ) {
                                    togglePlan(plan)
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        Text("Fine tune your categories")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.bottom, 10)

                        LazyVGrid(columns: categoryColumns, spacing: 8) {
                            ForEach(PassageCategory.allCases, id: \.self) { category in
                                Button {
                                    toggleCategory(category)
                                } label: {
                                    Text(category.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(selectedCategories.contains(category) ? .black : DS.label2)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedCategories.contains(category) ? category.color : DS.surface)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(selectedCategories.contains(category) ? category.color : DS.separator, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text("\(selectedCategories.count) categories selected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.label3)

                    PrimaryButton(title: "Save My Plan", icon: "checkmark") {
                        saveAndClose()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    LinearGradient(
                        colors: [DS.bg.opacity(0.0), DS.bg.opacity(0.94), DS.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            selectedCategories = decodeStoredCategories(from: storedCategoryCSV)
            draftPrompt = customPrompt
        }
    }

    private var header: some View {
        HStack {
            Text("Set my plan")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .tracking(-0.7)

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.label3)
                    .frame(width: 36, height: 36)
                    .background(DS.surface2)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var offerBanner: some View {
        HStack {
            Text("Special Offer")
                .font(.system(size: 13, weight: .bold))
            Spacer()
            Text("Save 40%+ with annual plan")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.black.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(hex: "EDBE53"), Color(hex: "D4A853"), Color(hex: "C99A2E")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func togglePlan(_ plan: PersonalizationPlan) {
        if plan.categories.isSubset(of: selectedCategories) {
            selectedCategories.subtract(plan.categories)
        } else {
            selectedCategories.formUnion(plan.categories)
        }
    }

    private func toggleCategory(_ category: PassageCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func saveAndClose() {
        storedCategoryCSV = encodeStoredCategories(selectedCategories)
        customPrompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        isPresented = false
    }

    private func generatePlanFromPrompt() {
        let prompt = draftPrompt.lowercased()
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let keywordMap: [(PassageCategory, [String])] = [
            (.economics, ["finance", "money", "business", "career", "invest"]),
            (.psychology, ["mind", "habit", "focus", "confidence", "social", "relationship"]),
            (.history, ["history", "ancient", "war", "civilization", "rome"]),
            (.philosophy, ["philosophy", "stoic", "ethics", "meaning", "thinking"]),
            (.science, ["science", "biology", "physics", "brain", "health"]),
            (.technology, ["tech", "ai", "startup", "coding", "digital"]),
            (.literature, ["fiction", "story", "books", "writing", "novel"]),
            (.mathematics, ["math", "quant", "logic", "statistics", "data"]),
        ]

        var inferred: Set<PassageCategory> = []
        for (category, keywords) in keywordMap where keywords.contains(where: { prompt.contains($0) }) {
            inferred.insert(category)
        }

        if inferred.isEmpty {
            inferred = [.psychology, .history, .science]
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            selectedCategories.formUnion(inferred)
        }
    }
}

struct PersonalizationPlanCard: View {
    let plan: PersonalizationPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: plan.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [Color.white.opacity(0.18), Color.clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 120
                )

                Image(systemName: plan.symbol)
                    .font(.system(size: 74, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                    .offset(x: 44, y: 8)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.68)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(plan.planCount) plans")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
                .padding(12)
            }
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? DS.accent : Color.white.opacity(0.16), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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
                    .background(DS.warning)
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
                    .fill(DS.success.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DS.success)
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
                    .foregroundStyle(app.isLocked ? .red : DS.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(app.isLocked ? Color.red.opacity(0.12) : DS.success.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(14)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private func decodeStoredCategories(from rawValue: String) -> Set<PassageCategory> {
    Set(rawValue.split(separator: ",").compactMap { PassageCategory(rawValue: String($0)) })
}

private func encodeStoredCategories(_ categories: Set<PassageCategory>) -> String {
    categories
        .map(\.rawValue)
        .sorted()
        .joined(separator: ",")
}
