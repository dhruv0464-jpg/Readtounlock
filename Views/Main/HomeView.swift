import Foundation
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
    let stableID: String
    let title: String
    let quote: String
    let body: String
    let category: PassageCategory
    let source: String
    let sourceURL: URL?
    let symbol: String
    let palette: [Color]
    let sequenceLabel: String
    let visualSeed: Int
    let baseLikeCount: Int
    let shareText: String
    let keyPassage: String

    var id: String { stableID }

    init(stableID: String, title: String, quote: String, body: String, category: PassageCategory, source: String, sourceURL: URL? = nil, symbol: String, palette: [Color], sequenceLabel: String) {
        self.stableID = stableID
        self.title = title
        self.quote = quote
        self.body = body
        self.category = category
        self.source = source
        self.sourceURL = sourceURL
        self.symbol = symbol
        self.palette = palette
        self.sequenceLabel = sequenceLabel

        let seed = FreeReadFeedItem.deterministicSeed(stableID)
        self.visualSeed = seed
        self.baseLikeCount = 220 + (seed % 9400)
        self.keyPassage = FreeReadFeedItem.compactPassage(from: body, maxChars: 620)

        let preview = body.count > 320 ? "\(body.prefix(320))..." : body
        var parts = ["\"\(quote)\"", preview, source]
        if let sourceURL {
            parts.append(sourceURL.absoluteString)
        }
        parts.append("Shared from Readtounlock")
        self.shareText = parts.joined(separator: "\n\n")
    }

    init(story: FreeReadStory, sequenceLabel: String) {
        self.init(
            stableID: story.id,
            title: story.title,
            quote: story.quote,
            body: story.body,
            category: story.category,
            source: story.source,
            sourceURL: story.sourceURL.flatMap(URL.init(string:)),
            symbol: story.symbol,
            palette: story.palette,
            sequenceLabel: sequenceLabel
        )
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
                sequenceLabel: "Impact Read"
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

            let ranked = segments.enumerated()
                .map { index, segment in
                    (
                        sourceIndex: index,
                        text: segment,
                        score: segmentImpactScore(segment, category: passage.category)
                    )
                }
                .sorted { $0.score > $1.score }

            let selected = Array(ranked.filter { $0.score >= 0.22 }.prefix(2))
            let fallback = Array(ranked.prefix(2))
            let picked = selected.isEmpty ? fallback : selected

            for (rank, candidate) in picked.enumerated() {
                items.append(
                    FreeReadFeedItem(
                        stableID: "library-\(passage.id)-\(candidate.sourceIndex)",
                        title: passage.title,
                        quote: quoteFromSegment(candidate.text),
                        body: candidate.text,
                        category: passage.category,
                        source: "From library: \(passage.source)",
                        symbol: passage.category.icon,
                        palette: palette(for: passage.category),
                        sequenceLabel: "Best Passage \(rank + 1)"
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
            .filter { $0.count > 25 }

        let ideal = sentences
            .filter { $0.count >= 45 && $0.count <= 180 }
            .max(by: { sentenceImpactScore($0) < sentenceImpactScore($1) })

        if let ideal {
            return finalizedQuoteSentence(ideal)
        }

        if let best = sentences.max(by: { sentenceImpactScore($0) < sentenceImpactScore($1) }) {
            return finalizedQuoteSentence(best)
        }

        return flattened
    }

    private static func sentenceImpactScore(_ sentence: String) -> Double {
        let lower = sentence.lowercased()
        var score = 0.0
        if sentence.count >= 55 && sentence.count <= 170 { score += 0.24 }
        if sentence.contains("?") { score += 0.08 }
        if sentence.contains(";") || sentence.contains(":") { score += 0.06 }
        let hits = impactLexicon.filter { lower.contains($0) }.count
        score += min(0.48, Double(hits) * 0.07)
        return score
    }

    private static func segmentImpactScore(_ text: String, category: PassageCategory) -> Double {
        let lower = text.lowercased()
        let words = text.split(whereSeparator: \.isWhitespace)
        let sentenceCount = text.split(whereSeparator: { ".!?".contains($0) }).count

        var score = 0.0
        if words.count >= 65 && words.count <= 230 { score += 0.22 }
        if sentenceCount >= 3 && sentenceCount <= 8 { score += 0.13 }
        if text.contains("?") { score += 0.05 }
        if text.contains(";") || text.contains(":") { score += 0.04 }

        let coreHits = impactLexicon.filter { lower.contains($0) }.count
        score += min(0.46, Double(coreHits) * 0.055)

        let categoryHits = categoryImpactLexicon(for: category).filter { lower.contains($0) }.count
        score += min(0.24, Double(categoryHits) * 0.06)

        return score
    }

    private static func categoryImpactLexicon(for category: PassageCategory) -> [String] {
        switch category {
        case .science:
            return ["evidence", "experiment", "theory", "brain", "attention", "signal"]
        case .history:
            return ["empire", "civilization", "pattern", "institution", "century", "power"]
        case .philosophy:
            return ["virtue", "truth", "judgment", "wisdom", "character", "agency"]
        case .economics:
            return ["incentive", "tradeoff", "compounding", "scarcity", "capital", "leverage"]
        case .psychology:
            return ["habit", "emotion", "identity", "behavior", "motivation", "self-control"]
        case .literature:
            return ["meaning", "story", "voice", "language", "memory", "imagination"]
        case .mathematics:
            return ["proof", "structure", "logic", "model", "probability", "precision"]
        case .technology:
            return ["system", "design", "algorithm", "tool", "build", "feedback"]
        }
    }

    private static let impactLexicon: [String] = [
        "attention", "focus", "discipline", "clarity", "decision", "freedom", "agency",
        "courage", "truth", "character", "responsibility", "purpose", "leverage",
        "compounding", "pattern", "consequence", "habit", "memory", "signal", "future"
    ]

    private static func finalizedQuoteSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if ".!?".contains(last) {
            return trimmed
        }
        return trimmed + "."
    }

    private static func deterministicSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { current, scalar in
            (current * 33 + Int(scalar.value)) % 10_000
        }
    }

    private static func compactPassage(from text: String, maxChars: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sentences = normalized
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 35 }

        guard !sentences.isEmpty else {
            if normalized.count <= maxChars { return normalized }
            return String(normalized.prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        var selected: [String] = []
        var total = 0
        for sentence in sentences {
            let candidate = sentence + "."
            let nextTotal = total + candidate.count + (selected.isEmpty ? 0 : 1)
            if nextTotal > maxChars { break }
            selected.append(candidate)
            total = nextTotal
            if selected.count >= 4 { break }
        }

        if selected.isEmpty {
            return String(sentences[0].prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        return selected.joined(separator: " ")
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
        FreeReadStory(
            id: "obstacle-way",
            title: "Obstacle as Training",
            quote: "The impediment to action advances action.",
            body: """
            Marcus Aurelius wrote this while governing through war and plague: what blocks the path can become the path itself. The Stoic move is not denial. It is conversion.

            Friction can be interpreted as proof you are on the right task. Hard work with meaningful stakes should feel demanding. That sensation is not failure; it is adaptation in real time.

            Ask one better question today: what skill is this obstacle forcing me to build?
            """,
            category: .philosophy,
            source: "Meditations — Marcus Aurelius (public domain)",
            symbol: "flame.fill",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "control-and-choice",
            title: "Control and Choice",
            quote: "Work first on your judgment, then on your circumstances.",
            body: """
            Epictetus taught that anxiety grows when we demand certainty from a world that cannot promise it. We control judgments, actions, and commitments; we do not control outcomes, reactions, or luck.

            This distinction is not passive. It is a strategic allocation of emotional energy. You become calmer not by lowering standards, but by investing effort where leverage is highest.

            Before your next decision, separate what is yours to shape from what is yours to accept.
            """,
            category: .psychology,
            source: "Enchiridion — Epictetus (public domain)",
            symbol: "person.crop.circle.badge.questionmark",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "darwin-patience",
            title: "Patience Outlasts Noise",
            quote: "Great understanding usually arrives after long observation.",
            body: """
            Darwin spent decades collecting evidence before publishing his most controversial idea. His edge was not speed. It was disciplined attention over long intervals.

            We underestimate the power of patient accumulation: repeated observation, careful note-taking, and willingness to revise assumptions as new evidence appears.

            When the world rewards hot takes, patient truth-seeking becomes a competitive advantage.
            """,
            category: .science,
            source: "On the Origin of Species — Charles Darwin (public domain)",
            symbol: "atom",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "franklin-compound",
            title: "Compounding in Character",
            quote: "Little strokes fell great oaks.",
            body: """
            Franklin's line is economic and moral at once: repeated, small effort can reshape large systems over time. This is true for money, habits, trust, and craft.

            Big goals often fail because they demand intensity without structure. Small standards survive because they are repeatable under real-life constraints.

            Protect your daily minimum. The minimum is where long-term identity is built.
            """,
            category: .economics,
            source: "Poor Richard's Almanack — Benjamin Franklin (public domain)",
            symbol: "chart.line.uptrend.xyaxis",
            palette: [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        ),
        FreeReadStory(
            id: "lincoln-angles",
            title: "Better Angels Under Pressure",
            quote: "The language you choose can decide the future you get.",
            body: """
            Lincoln's speeches were strategic acts of moral framing. He understood that in periods of division, words can either harden camps or widen the space for shared purpose.

            High-impact reading is not just collecting facts. It is studying how leaders move attention from panic toward principle.

            In conflict, aim for language that preserves truth and keeps cooperation possible.
            """,
            category: .history,
            source: "First Inaugural Address — Abraham Lincoln (public domain)",
            symbol: "building.columns.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "ada-instructions",
            title: "Instructions Beat Inspiration",
            quote: "A powerful system is one you can describe precisely.",
            body: """
            Ada Lovelace saw early that computing was not just machinery; it was symbolic instruction. Power comes from clear procedures that can be executed consistently.

            Most personal systems fail because they are motivational, not operational. A good system is explicit enough to run on low-energy days.

            If you cannot write your process in a few steps, you are still relying on mood.
            """,
            category: .technology,
            source: "Notes on the Analytical Engine — Ada Lovelace (public domain)",
            symbol: "cpu",
            palette: [Color(hex: "4A361F"), Color(hex: "332515"), Color(hex: "1A130A")]
        ),
        FreeReadStory(
            id: "euclid-proof",
            title: "Proof Before Opinion",
            quote: "Structure protects you from confident nonsense.",
            body: """
            Euclid's method is a discipline of sequence: define terms, state assumptions, prove claims step by step. It turns argument from performance into verification.

            The same discipline helps with modern decisions. What are your assumptions? What evidence would falsify them? What follows logically?

            Precision is not coldness. It is respect for truth under pressure.
            """,
            category: .mathematics,
            source: "Elements — Euclid (public domain)",
            symbol: "sum",
            palette: [Color(hex: "5E3F22"), Color(hex: "402C17"), Color(hex: "20160B")]
        ),
        FreeReadStory(
            id: "douglass-literacy",
            title: "Reading as Liberation",
            quote: "Literacy changes what kinds of life are imaginable.",
            body: """
            Frederick Douglass described reading as a turning point in human agency. Words gave him a larger map of reality and a language for resistance.

            High-impact passages expand possibility. They help you name problems accurately and imagine responses that were previously invisible.

            Read not only for information, but for enlargement of self-command.
            """,
            category: .literature,
            source: "Narrative of the Life of Frederick Douglass (public domain)",
            symbol: "book.closed",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "seneca-time",
            title: "Spend Time Like Capital",
            quote: "It is not that life is short; it is that we waste much of it.",
            body: """
            Seneca frames time as your primary asset. Most people guard money more carefully than attention, then wonder why their days feel fragmented and thin.

            A powerful schedule is not packed. It is protected. Unclaimed time is quickly captured by default demands and low-quality stimulation.

            Treat one hour daily as non-negotiable investment time for your future self.
            """,
            category: .economics,
            source: "On the Shortness of Life — Seneca (public domain)",
            symbol: "banknote.fill",
            palette: [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        ),
        FreeReadStory(
            id: "james-attention",
            title: "Attention Chooses Reality",
            quote: "My experience is what I agree to attend to.",
            body: """
            William James recognized attention as a selection mechanism. In practice, your mind is always editing. What it repeats becomes what feels real.

            This is why your informational diet matters. Repeated exposure trains emotional baselines, threat perception, and default narratives.

            Pick your inputs with the same care you use for your closest relationships.
            """,
            category: .psychology,
            source: "The Principles of Psychology — William James (public domain)",
            symbol: "eye.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "emerson-self-trust",
            title: "Trust the Inner Signal",
            quote: "Nothing is at last sacred but the integrity of your own mind.",
            body: """
            Emerson's point is not arrogance. It is authorship. Borrowed opinions are easy to collect and hard to live by.

            High-impact reading should not end in mimicry. It should sharpen your independent judgment so your actions are coherent across pressure, praise, and doubt.

            Read deeply, then test ideas against your own lived evidence.
            """,
            category: .literature,
            source: "Self-Reliance — Ralph Waldo Emerson (public domain)",
            symbol: "text.book.closed.fill",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "faraday-wonder",
            title: "Curiosity with Discipline",
            quote: "Wonder becomes power when it is organized into method.",
            body: """
            Faraday began as a bookbinder's apprentice and became one of the most consequential experimental scientists in history through relentless, careful practice.

            Curiosity alone is not enough. Impact comes from disciplined loops: observe, test, record, refine. Repeat for years.

            Treat every question as an experiment and every experiment as a way to upgrade judgment.
            """,
            category: .science,
            source: "Experimental Researches in Electricity — Michael Faraday (public domain)",
            symbol: "bolt.fill",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "adam-smith-incentives",
            title: "Incentives Shape Behavior",
            quote: "Systems produce what they reward, not what they promise.",
            body: """
            Adam Smith observed that markets coordinate human effort through incentives, not speeches. People respond to structures: prices, constraints, trust, and accountability.

            The same principle applies to personal habits. If your environment rewards distraction, distraction wins. If your environment rewards deep work, focus becomes easier than force.

            Upgrade the structure first. Motivation follows systems more reliably than systems follow motivation.
            """,
            category: .economics,
            source: "The Wealth of Nations — Adam Smith (public domain)",
            symbol: "banknote.fill",
            palette: [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        ),
        FreeReadStory(
            id: "cicero-duty",
            title: "Duty Before Comfort",
            quote: "Character is built when principle outranks convenience.",
            body: """
            Cicero argued that useful and honorable should never be treated as enemies. Real leadership is the discipline of choosing what is right, especially when the easier option is available.

            High-impact reading from political philosophy reminds us that ethics is practical. It governs hiring, promises, attention, and how we act when nobody is watching.

            Before your next decision, ask what preserves both results and integrity.
            """,
            category: .philosophy,
            source: "On Duties — Cicero (public domain)",
            symbol: "scale.3d",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "sun-tzu-preparation",
            title: "Preparation Is Quiet Power",
            quote: "Victories are often earned before the contest begins.",
            body: """
            Sun Tzu's core insight is strategic: outcomes are shaped in preparation, positioning, and clarity long before visible conflict starts.

            In modern life, this means planning your day before notifications arrive, rehearsing hard conversations before pressure rises, and deciding standards before temptation appears.

            Winning is less about dramatic moments and more about invisible readiness.
            """,
            category: .history,
            source: "The Art of War — Sun Tzu (public domain translation)",
            symbol: "shield.lefthalf.filled",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "descartes-method",
            title: "Think in Clear Steps",
            quote: "Complexity breaks when you force it into method.",
            body: """
            Descartes proposed a practical method: divide difficult problems into smaller parts, solve the simple pieces, then rebuild the whole with order.

            This is still the foundation of engineering, writing, and decision-making. Confusion usually means too many variables are being held at once.

            When stuck, reduce the problem until the next move is obvious.
            """,
            category: .mathematics,
            source: "Discourse on Method — Rene Descartes (public domain)",
            symbol: "sum",
            palette: [Color(hex: "5E3F22"), Color(hex: "402C17"), Color(hex: "20160B")]
        ),
        FreeReadStory(
            id: "bacon-studies",
            title: "Read to Weigh and Consider",
            quote: "Reading should sharpen judgment, not decorate memory.",
            body: """
            Francis Bacon warned against shallow consumption: some books are to be tasted, others swallowed, and a few digested. The point is selective depth.

            High-impact readers do not collect pages as trophies. They read with questions and test ideas against reality.

            Choose one passage today to digest, not skim.
            """,
            category: .literature,
            source: "Of Studies — Francis Bacon (public domain)",
            symbol: "text.book.closed.fill",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "thoreau-simplicity",
            title: "Simplicity Restores Signal",
            quote: "Simplify your inputs so your mind can hear itself.",
            body: """
            Thoreau's experiment at Walden was not escapism. It was information design. He reduced noise to discover what was essential.

            Modern attention systems are louder, but the principle is unchanged. Every subtraction creates space for better observation.

            Remove one unnecessary input and notice how quickly clarity returns.
            """,
            category: .psychology,
            source: "Walden — Henry David Thoreau (public domain)",
            symbol: "leaf.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "wollstonecraft-reason",
            title: "Reason Expands Freedom",
            quote: "Education is leverage for agency.",
            body: """
            Wollstonecraft argued that dignity requires development of reason, not dependence on approval. Education is not decoration; it is power.

            High-impact passages on self-development should leave you more capable of independent thought, not more dependent on trends.

            Read to strengthen judgment that cannot be outsourced.
            """,
            category: .history,
            source: "A Vindication of the Rights of Woman — Mary Wollstonecraft (public domain)",
            symbol: "person.2.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "dubois-education",
            title: "Learning as Liberation",
            quote: "Serious study can turn survival into leadership.",
            body: """
            W. E. B. Du Bois treated education as social force, not private vanity. Knowledge equips people to name systems accurately and act with coordinated purpose.

            High-impact reading does not stop at insight. It changes how communities organize, decide, and imagine futures.

            Ask what this passage helps you improve beyond yourself.
            """,
            category: .history,
            source: "The Souls of Black Folk — W. E. B. Du Bois (public domain)",
            symbol: "building.2.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "nightingale-measure",
            title: "Measure What Matters",
            quote: "Evidence protects care from guesswork.",
            body: """
            Florence Nightingale transformed outcomes by insisting that observation and data should guide action. Compassion became more effective when paired with measurement.

            The lesson applies far beyond healthcare: if you do not track reality, optimism and fear both become unreliable narrators.

            Keep one honest metric for the behavior you want to improve.
            """,
            category: .science,
            source: "Notes on Nursing — Florence Nightingale (public domain)",
            symbol: "waveform.path.ecg",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "montaigne-self-observation",
            title: "Observe Yourself Clearly",
            quote: "Self-knowledge is a practical skill, not a mood.",
            body: """
            Montaigne wrote essays as experiments in honest observation. He studied his own mind to understand universal habits of fear, ego, and contradiction.

            Reflection becomes useful when it is specific: what triggered me, what assumption failed, what pattern repeated?

            Write one precise observation about your behavior today and turn it into a better rule tomorrow.
            """,
            category: .psychology,
            source: "Essays — Michel de Montaigne (public domain translation)",
            symbol: "eye.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "james-allen-thought",
            title: "Attention Becomes Character",
            quote: "What you repeatedly think, you eventually become.",
            body: """
            James Allen emphasized that thoughts are not harmless background noise. Repeated mental patterns set direction for behavior, relationships, and standards.

            This is why reading quality matters. Inputs become inner language, and inner language becomes action under pressure.

            Protect the first ideas you consume each day. They seed the rest.
            """,
            category: .psychology,
            source: "As a Man Thinketh — James Allen (public domain)",
            symbol: "brain.head.profile",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "kierkegaard-choice",
            title: "Choose with Commitment",
            quote: "A life is shaped less by options than by commitments.",
            body: """
            Kierkegaard wrote that endless possibility can become paralysis. Commitment converts abstract potential into concrete identity.

            In a feed-driven world, you can sample everything and build nothing. Depth requires repeated return to chosen practices.

            Pick one reading theme for this week and commit long enough to feel the compounding.
            """,
            category: .philosophy,
            source: "Either/Or — Soren Kierkegaard (public domain translation)",
            symbol: "checkmark.seal.fill",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "bastiat-seen-unseen",
            title: "Seen and Unseen Effects",
            quote: "Good decisions account for consequences beyond the first reaction.",
            body: """
            Bastiat's classic point is simple and brutal: people applaud visible benefits while ignoring hidden costs that arrive later or elsewhere.

            The same mistake appears in personal life. Short-term relief often hides long-term erosion of attention, health, or trust.

            Evaluate choices across time, not just across headlines.
            """,
            category: .economics,
            source: "That Which Is Seen, and That Which Is Not Seen — Frederic Bastiat (public domain)",
            symbol: "banknote.fill",
            palette: [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        ),
        FreeReadStory(
            id: "malthus-constraints",
            title: "Respect Constraints Early",
            quote: "Ignoring limits does not remove them.",
            body: """
            Malthus is often reduced to controversy, but one durable insight remains: systems fail when growth assumptions ignore real constraints.

            Attention, money, and energy all behave this way. Plans collapse when they demand infinite output from finite capacity.

            Sustainable momentum starts by designing with limits, not against them.
            """,
            category: .economics,
            source: "An Essay on the Principle of Population — Thomas Malthus (public domain)",
            symbol: "chart.line.uptrend.xyaxis",
            palette: [Color(hex: "53381E"), Color(hex: "3A2714"), Color(hex: "1D140A")]
        ),
        FreeReadStory(
            id: "mill-liberty-voice",
            title: "Protect Dissenting Voices",
            quote: "Silencing disagreement weakens truth itself.",
            body: """
            Mill argued that free discussion is not a luxury. It is how bad ideas are exposed and good ideas are sharpened.

            Even true beliefs become fragile when never challenged. Debate forces precision, evidence, and humility.

            Read viewpoints that disagree with you and test what survives.
            """,
            category: .philosophy,
            source: "On Liberty — John Stuart Mill (public domain)",
            symbol: "bubble.left.and.text.bubble.right.fill",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "laozi-empty-space",
            title: "Power of Empty Space",
            quote: "What is left open often creates what is useful.",
            body: """
            Laozi noticed that usefulness comes from space as much as substance: a room works because it is not filled, a cup works because it is hollow.

            The same applies to focus. A calendar packed to the edge produces motion without reflection.

            Leave white space in your day so better thought can appear.
            """,
            category: .philosophy,
            source: "Tao Te Ching — Laozi (public domain translation)",
            symbol: "circle.lefthalf.filled",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "heraclitus-flow",
            title: "Work with Change",
            quote: "You never step into the same river twice.",
            body: """
            Heraclitus frames reality as movement. Stability is temporary, and adaptation is a core skill rather than a special event.

            High-impact readers expect change and train principles that travel across changing conditions.

            Build routines that are sturdy enough to guide you and flexible enough to survive reality.
            """,
            category: .philosophy,
            source: "Fragments — Heraclitus (public domain translation)",
            symbol: "water.waves",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "tocqueville-associations",
            title: "Communities Build Strength",
            quote: "Free people stay free by practicing cooperation.",
            body: """
            Tocqueville observed that strong societies are sustained by everyday civic participation: clubs, associations, and local responsibility.

            Agency is not only individual willpower. It is also social design that helps people act together.

            Invest in one community where your effort compounds with others.
            """,
            category: .history,
            source: "Democracy in America — Alexis de Tocqueville (public domain)",
            symbol: "person.3.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "washington-farewell-unity",
            title: "Guard Long-Term Unity",
            quote: "Short-term faction wins can produce long-term national losses.",
            body: """
            Washington's farewell warning was strategic: extreme party conflict can make a nation easier to manipulate and harder to govern.

            On a personal level, the lesson generalizes. Constant internal conflict between goals destroys focus and confidence.

            Align your priorities before you optimize your schedule.
            """,
            category: .history,
            source: "Farewell Address — George Washington (public domain)",
            symbol: "flag.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "clausewitz-friction",
            title: "Expect Friction",
            quote: "In real execution, simple things become hard.",
            body: """
            Clausewitz called friction the gap between plans on paper and action in reality. Delays, confusion, and fatigue are normal, not surprising.

            The advantage goes to teams and individuals who design for friction instead of pretending it will not happen.

            Build buffers, fallback options, and clear priorities before pressure arrives.
            """,
            category: .history,
            source: "On War — Carl von Clausewitz (public domain translation)",
            symbol: "shield.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "boole-symbolic-thought",
            title: "Translate Thought into Structure",
            quote: "Clear symbols make complex reasoning manageable.",
            body: """
            Boole showed that logic could be formalized into symbolic operations. This transformed reasoning from intuition alone into repeatable method.

            Modern software inherits this move. Precision in representation reduces ambiguity in execution.

            When you are confused, rewrite the problem in cleaner terms first.
            """,
            category: .technology,
            source: "The Laws of Thought — George Boole (public domain)",
            symbol: "cpu.fill",
            palette: [Color(hex: "4A361F"), Color(hex: "332515"), Color(hex: "1A130A")]
        ),
        FreeReadStory(
            id: "maxwell-models",
            title: "Models Reveal Hidden Forces",
            quote: "A good model lets you see what experience alone misses.",
            body: """
            Maxwell's equations unified electricity and magnetism by revealing structure beneath scattered observations.

            Models are compression tools for thinking. They let you predict behavior in new situations rather than memorizing isolated facts.

            Learn one strong model each week and apply it outside its original domain.
            """,
            category: .science,
            source: "A Treatise on Electricity and Magnetism — James Clerk Maxwell (public domain)",
            symbol: "bolt.badge.a.fill",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "pasteur-observation",
            title: "Chance Favors Prepared Minds",
            quote: "Breakthroughs reward those already paying close attention.",
            body: """
            Pasteur's famous idea was practical, not mystical. Luck helps most when you have already built method, skill, and curiosity.

            Preparation turns random events into useful signals. Without preparation, the same event passes unnoticed.

            Study consistently so opportunity has somewhere to land.
            """,
            category: .science,
            source: "Scientific writings of Louis Pasteur (public domain translation)",
            symbol: "cross.case.fill",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "pavlov-cues",
            title: "Design Better Cues",
            quote: "Behavior often follows triggers before intentions.",
            body: """
            Pavlov's experiments highlighted how strongly cues shape response. We like to think actions come from conscious choice, but context often acts first.

            High-impact habit change starts by redesigning triggers: what you see, where you place tools, what appears first on your screen.

            Make the first cue of your day point toward who you want to become.
            """,
            category: .psychology,
            source: "Conditioned Reflexes — Ivan Pavlov (public domain translation)",
            symbol: "bell.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "austen-attention-detail",
            title: "Read the Subtext",
            quote: "What people imply often matters more than what they announce.",
            body: """
            Austen's social intelligence lives in details: tone, timing, hesitation, and quiet contradictions between speech and motive.

            Literature trains perception. You become better at reading people, not only pages.

            When you review a conversation, look for the subtext you missed in real time.
            """,
            category: .literature,
            source: "Pride and Prejudice — Jane Austen (public domain)",
            symbol: "book.closed.fill",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "pascal-focus",
            title: "Stillness Builds Depth",
            quote: "Many problems begin when attention cannot stay still.",
            body: """
            Pascal observed that much human misery comes from inability to remain quietly in one room. Restlessness seeks distraction before understanding.

            Depth needs stillness long enough for first thoughts to pass and better thoughts to appear.

            Practice five undistracted minutes before every major reading session.
            """,
            category: .psychology,
            source: "Pensees — Blaise Pascal (public domain translation)",
            symbol: "moon.stars.fill",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "aristotle-habit-virtue",
            title: "Habits Build Character",
            quote: "You become what you repeatedly practice.",
            body: """
            Aristotle's ethics is concrete: excellence is not a one-time act but a stable pattern built through repeated choices.

            Big identity shifts usually begin with tiny repeated actions. What feels small today becomes automatic tomorrow.

            Choose one behavior worth repeating and protect it daily.
            """,
            category: .philosophy,
            source: "Nicomachean Ethics — Aristotle (public domain translation)",
            symbol: "checkmark.shield.fill",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "confucius-name-things",
            title: "Name Things Clearly",
            quote: "Order begins when language is precise.",
            body: """
            Confucius emphasized that disorder often starts with vague words. If names are unclear, responsibilities blur and trust erodes.

            Precision is not pedantry. It is respect for reality and for other people trying to coordinate with you.

            Define your goal in one exact sentence before you start work.
            """,
            category: .history,
            source: "Analects — Confucius (public domain translation)",
            symbol: "character.book.closed.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "dhammapada-right-effort",
            title: "Train the Inner Direction",
            quote: "Guard attention before it becomes action.",
            body: """
            The Dhammapada frames mind as the starting point of conduct. Thoughts repeated become speech; speech repeated becomes habit.

            Psychological discipline is easier upstream. Correcting a thought early is cheaper than correcting consequences later.

            Catch one negative loop early today and redirect it deliberately.
            """,
            category: .psychology,
            source: "Dhammapada (public domain translation)",
            symbol: "brain.head.profile",
            palette: [Color(hex: "5A3D28"), Color(hex: "3C2A1B"), Color(hex: "1E150D")]
        ),
        FreeReadStory(
            id: "plato-examined-life",
            title: "Examine Assumptions",
            quote: "Unexamined assumptions silently run your life.",
            body: """
            Plato's dialogues model a discipline of questioning: define terms, test claims, expose contradictions, then revise.

            This is high-impact reading in action. You do not passively absorb ideas; you interrogate them until they can survive scrutiny.

            Pick one belief you hold and ask what evidence would change your mind.
            """,
            category: .philosophy,
            source: "Apology and Dialogues — Plato (public domain translation)",
            symbol: "questionmark.app.fill",
            palette: [Color(hex: "4D3B24"), Color(hex: "35291A"), Color(hex: "1A150D")]
        ),
        FreeReadStory(
            id: "thucydides-human-drivers",
            title: "Fear, Honor, Interest",
            quote: "Major decisions are often driven by a small set of motives.",
            body: """
            Thucydides tracked conflict with unusual realism. Beneath speeches and slogans, he saw recurring drivers: fear, honor, and interest.

            Naming the true driver behind behavior improves strategy immediately. You stop arguing with appearances and start working with causes.

            In your next conflict, identify the dominant motive before proposing a solution.
            """,
            category: .history,
            source: "History of the Peloponnesian War — Thucydides (public domain translation)",
            symbol: "shield.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "machiavelli-reality-check",
            title: "See the World as It Is",
            quote: "Strategy fails when it ignores real incentives.",
            body: """
            Machiavelli's hard lesson is diagnostic: plans based on wishful assumptions collapse when pressure arrives.

            Realism is not cynicism. It is accurate mapping of incentives, risks, and human behavior before action.

            Ask whether your current plan is built on evidence or on hope.
            """,
            category: .history,
            source: "The Prince — Niccolo Machiavelli (public domain translation)",
            symbol: "map.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "montesquieu-balance-power",
            title: "Design for Checks",
            quote: "Good systems prevent abuse before it starts.",
            body: """
            Montesquieu argued that concentrated power eventually overreaches. Durable institutions separate authority so correction is always possible.

            Personal systems benefit from the same idea: use constraints and review loops so one bad impulse cannot dominate outcomes.

            Add one check to your routine that catches mistakes early.
            """,
            category: .history,
            source: "The Spirit of Laws — Montesquieu (public domain translation)",
            symbol: "building.columns.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "gibbon-slow-decay",
            title: "Decline Is Usually Gradual",
            quote: "Most collapses begin as tolerated small failures.",
            body: """
            Gibbon's account of Rome shows that decay is often incremental: standards slip, institutions weaken, and warning signs are normalized.

            The same dynamic applies to personal discipline. You rarely lose direction all at once; you drift by unchallenged exceptions.

            Audit one standard you have been quietly lowering and restore it.
            """,
            category: .history,
            source: "The History of the Decline and Fall of the Roman Empire — Edward Gibbon (public domain)",
            symbol: "hourglass.bottomhalf.filled",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "galileo-measure-nature",
            title: "Measure Before Belief",
            quote: "What can be measured can be tested.",
            body: """
            Galileo insisted that claims about nature should face experiment and observation, not authority alone.

            This mindset generalizes to everyday decisions: measure outcomes, compare expectations, then update behavior.

            Replace one opinion this week with a tracked experiment.
            """,
            category: .science,
            source: "Scientific writings of Galileo Galilei (public domain translation)",
            symbol: "ruler.fill",
            palette: [Color(hex: "58371F"), Color(hex: "3D2615"), Color(hex: "1E130A")]
        ),
        FreeReadStory(
            id: "kepler-patient-law",
            title: "Patience Finds Structure",
            quote: "Persistence can reveal laws hidden in noise.",
            body: """
            Kepler spent years refining planetary models before finding the laws that fit the data. Breakthrough required stubborn iteration.

            High-impact learning often looks like long periods of unclear progress followed by sudden coherence.

            Stay with hard problems long enough for patterns to emerge.
            """,
            category: .mathematics,
            source: "Astronomia Nova — Johannes Kepler (public domain translation)",
            symbol: "function",
            palette: [Color(hex: "5E3F22"), Color(hex: "402C17"), Color(hex: "20160B")]
        ),
        FreeReadStory(
            id: "poincare-creative-order",
            title: "Creativity Needs Structure",
            quote: "Insight appears faster in minds trained by method.",
            body: """
            Poincare described mathematical discovery as a balance: disciplined groundwork plus incubation where the mind recombines ideas.

            Creativity is not random magic. It is prepared intuition operating on well-organized material.

            Build a note system that makes your ideas easier to recombine.
            """,
            category: .mathematics,
            source: "Science and Method — Henri Poincare (public domain translation)",
            symbol: "sum",
            palette: [Color(hex: "5E3F22"), Color(hex: "402C17"), Color(hex: "20160B")]
        ),
        FreeReadStory(
            id: "george-eliot-sympathy",
            title: "Attention Is Moral",
            quote: "To understand another life is a serious discipline.",
            body: """
            George Eliot's fiction expands moral perception by forcing readers to inhabit complex motives rather than stereotypes.

            Literature at its best sharpens empathy without reducing accountability. You learn to see context and consequence together.

            Read one difficult character as practice for real-world understanding.
            """,
            category: .literature,
            source: "Middlemarch — George Eliot (public domain)",
            symbol: "text.book.closed.fill",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "melville-depth-work",
            title: "Go Deep, Not Just Fast",
            quote: "Depth changes you in ways speed cannot.",
            body: """
            Melville's long-form narrative rewards sustained attention. It is a reminder that some insights only appear after extended engagement.

            Feed-driven reading trains quick reaction. Book-level reading trains depth, memory, and synthesis.

            Spend one session this week reading beyond your comfort span.
            """,
            category: .literature,
            source: "Moby-Dick — Herman Melville (public domain)",
            symbol: "book.fill",
            palette: [Color(hex: "4F3424"), Color(hex: "372518"), Color(hex: "1B130C")]
        ),
        FreeReadStory(
            id: "booker-washington-build-skill",
            title: "Build Skill Under Constraint",
            quote: "Progress is often built with what you already have.",
            body: """
            Booker T. Washington emphasized disciplined skill-building even in constrained conditions. Agency grows when effort is directed toward mastery.

            Waiting for ideal conditions delays momentum. Small, consistent improvement compounds into real leverage.

            Choose one practical skill and advance it daily, even in short intervals.
            """,
            category: .history,
            source: "Up from Slavery — Booker T. Washington (public domain)",
            symbol: "hammer.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
        FreeReadStory(
            id: "jane-addams-civic-duty",
            title: "Service as Intelligence",
            quote: "Understanding grows when you engage real human needs.",
            body: """
            Jane Addams treated social reform as disciplined observation plus action. Ideas were tested against lived community outcomes.

            This is impact reading in civic form: study, apply, evaluate, improve.

            Use one idea from today's reading to make one concrete environment better.
            """,
            category: .history,
            source: "Democracy and Social Ethics — Jane Addams (public domain)",
            symbol: "person.3.sequence.fill",
            palette: [Color(hex: "5C3A22"), Color(hex: "3E2718"), Color(hex: "1F140C")]
        ),
    ]
}

struct FreeReadRenderItem: Identifiable {
    let id = UUID()
    let content: FreeReadFeedItem
}

struct FreeReadView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("personalizationCategoryCSV") private var personalizationCategoryCSV = ""
    private let likesStorageKey = "freeReadLikedStoryIDs"
    private var batchSize: Int { max(1, appState.performanceBudget.freeReadBatchSize) }
    private var prefetchThreshold: Int { max(1, appState.performanceBudget.freeReadPrefetchThreshold) }
    private var activePoolCap: Int { max(1, appState.performanceBudget.freeReadActivePoolCap) }
    private var initialBatchCount: Int { max(1, appState.performanceBudget.freeReadInitialBatches) }

    @State private var feed: [FreeReadRenderItem] = []
    @State private var masterPool: [FreeReadFeedItem] = []
    @State private var seedPool: [FreeReadFeedItem] = []
    @State private var seedCursor: Int = 0
    @State private var activeVibeCategories: Set<PassageCategory> = []
    @State private var likedStoryIDs: Set<String> = Set(UserDefaults.standard.array(forKey: "freeReadLikedStoryIDs") as? [String] ?? [])
    @State private var selectedStory: FreeReadFeedItem?
    @State private var didAttemptRemoteLoad = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(feed.enumerated()), id: \.element.id) { index, item in
                        FreeReadCard(
                            item: item.content,
                            isLiked: likedStoryIDs.contains(item.content.stableID),
                            onLike: { toggleLike(for: item.content) },
                            onOpen: { selectedStory = item.content }
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
            applyPersonalizationThemes()
            applyPendingVibeIfNeeded()
            if !didAttemptRemoteLoad {
                didAttemptRemoteLoad = true
                Task {
                    await refreshFeedFromBooksAPI()
                }
            }
        }
        .onChange(of: appState.freeReadFocusCategory) { _, newValue in
            guard let category = newValue else { return }
            applyVibeCategory(category)
            appState.freeReadFocusCategory = nil
        }
        .onChange(of: personalizationCategoryCSV) { _, _ in
            applyPersonalizationThemes()
        }
        .sheet(item: $selectedStory) { story in
            FreeReadDetailView(
                item: story,
                isLiked: likedStoryIDs.contains(story.stableID),
                onLike: { toggleLike(for: story) }
            )
        }
    }

    private func bootFeedIfNeeded() {
        guard feed.isEmpty else { return }
        if masterPool.isEmpty {
            masterPool = FreeReadFeedItem.seedPool
        }
        if activeVibeCategories.isEmpty {
            activeVibeCategories = defaultThemeCategories
        }
        rebuildFeed(for: activeVibeCategories)
    }

    private func appendBatch() {
        if seedPool.isEmpty { seedPool = FreeReadFeedItem.seedPool.shuffled() }
        guard !seedPool.isEmpty else { return }

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

    private func refreshFeedFromBooksAPI() async {
        let targetCount = 60
        let stories = await GutendexService.shared.fetchStories(limit: targetCount)

        await MainActor.run {
            guard !stories.isEmpty else { return }

            var remoteItems = stories.enumerated().map { index, story in
                FreeReadFeedItem(story: story, sequenceLabel: "Book \(index + 1)")
            }

            if remoteItems.count < targetCount {
                let fallback = FreeReadFeedItem.seedPool.shuffled()
                remoteItems.append(contentsOf: fallback.prefix(targetCount - remoteItems.count))
            }

            masterPool = remoteItems
            rebuildFeed(for: activeVibeCategories)
        }
    }

    private func applyPendingVibeIfNeeded() {
        guard let pending = appState.freeReadFocusCategory else { return }
        applyVibeCategory(pending)
        appState.freeReadFocusCategory = nil
    }

    private func applyVibeCategory(_ category: PassageCategory) {
        activeVibeCategories = [category]
        rebuildFeed(for: activeVibeCategories)
    }

    private func applyPersonalizationThemes() {
        guard appState.freeReadFocusCategory == nil else { return }
        activeVibeCategories = defaultThemeCategories
        rebuildFeed(for: activeVibeCategories)
    }

    private var defaultThemeCategories: Set<PassageCategory> {
        let themes = decodeStoredCategories(from: personalizationCategoryCSV)
        return themes.isEmpty ? [.psychology] : themes
    }

    private func rebuildFeed(for categories: Set<PassageCategory>) {
        let basePool = masterPool.isEmpty ? FreeReadFeedItem.seedPool : masterPool
        let activeCategories = categories.isEmpty ? [.psychology] : categories
        let filteredPool: [FreeReadFeedItem]
        let matches = basePool.filter { activeCategories.contains($0.category) }
        filteredPool = matches.isEmpty ? basePool : matches

        let activePool: [FreeReadFeedItem]
        if filteredPool.count > activePoolCap {
            activePool = Array(filteredPool.shuffled().prefix(activePoolCap))
        } else {
            activePool = filteredPool
        }

        seedPool = activePool.shuffled()
        seedCursor = 0
        feed.removeAll()
        for _ in 0..<initialBatchCount {
            appendBatch()
        }
    }
}

struct FreeReadCard: View {
    let item: FreeReadFeedItem
    let isLiked: Bool
    let onLike: () -> Void
    let onOpen: () -> Void

    private var theme: CategoryTheme { item.category.theme }
    private var likeCount: Int { item.baseLikeCount + (isLiked ? 1 : 0) }
    private var titleFontSize: CGFloat {
        let length = item.title.count
        if length <= 24 { return 34 }
        if length <= 42 { return 31 }
        if length <= 60 { return 28 }
        if length <= 84 { return 24 }
        if length <= 110 { return 21 }
        return 19
    }
    private var quoteFontSize: CGFloat {
        let length = item.quote.count
        if length <= 70 { return 44 }
        if length <= 110 { return 40 }
        if length <= 150 { return 35 }
        return 31
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            backgroundLayer
                .ignoresSafeArea()
                .onTapGesture {
                    onOpen()
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        onLike()
                    }
                )

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
                theme.deepReadBackground,
                theme.gradientStart.opacity(0.9),
                theme.gradientEnd.opacity(0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.0), Color.black.opacity(0.36)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(item.category.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(theme.chipBackground)
                    .clipShape(Capsule())

                Text(item.sequenceLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.accent.opacity(0.95))
            }
            .padding(.top, 18)
            .padding(.bottom, 12)

            Text(item.title)
                .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .lineLimit(nil)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            Text("\"\(item.quote)\"")
                .font(.system(size: quoteFontSize, weight: .bold, design: .serif))
                .tracking(-0.4)
                .lineSpacing(4)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            Text(item.keyPassage)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .lineSpacing(9)
                .foregroundStyle(DS.label2)
                .padding(.bottom, 16)

            Spacer(minLength: 8)

            Text(item.source)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.label4)
                .lineLimit(1)
                .padding(.bottom, 6)

            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                Text("Swipe for next")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(DS.label4)
            .padding(.bottom, 4)

            HStack(spacing: 5) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Tap to expand · Double tap to like")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(DS.label4)
            .padding(.bottom, 8)
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
                        .background(theme.gradientStart.opacity(0.58))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1)
                        )

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
                        .background(theme.gradientStart.opacity(0.58))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1)
                        )

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

struct FreeReadDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: FreeReadFeedItem
    let isLiked: Bool
    let onLike: () -> Void
    private var theme: CategoryTheme { item.category.theme }
    private var titleFontSize: CGFloat {
        let length = item.title.count
        if length <= 24 { return 40 }
        if length <= 42 { return 36 }
        if length <= 60 { return 33 }
        if length <= 84 { return 30 }
        if length <= 110 { return 27 }
        return 24
    }
    private var quoteFontSize: CGFloat {
        let length = item.quote.count
        if length <= 70 { return 48 }
        if length <= 110 { return 44 }
        if length <= 150 { return 38 }
        return 34
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.category.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(theme.chipBackground)
                        .clipShape(Capsule())
                        .padding(.bottom, 12)

                    Text(item.title)
                        .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 14)

                    Text("\"\(item.quote)\"")
                        .font(.system(size: quoteFontSize, weight: .bold, design: .serif))
                        .tracking(-0.5)
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)

                    Text(item.body)
                        .font(.system(size: 26, weight: .medium, design: .serif))
                        .lineSpacing(11)
                        .foregroundStyle(DS.label2)
                        .textSelection(.enabled)
                        .padding(.bottom, 20)

                    Text(item.source)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.label4)
                        .padding(.bottom, item.sourceURL == nil ? 30 : 10)

                    if let sourceURL = item.sourceURL {
                        Link(destination: sourceURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Open Original Book Source")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 26)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(
                LinearGradient(
                    colors: [
                        theme.deepReadBackground,
                        theme.gradientStart.opacity(0.55),
                        DS.bg
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Free Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: onLike) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? Color.red : theme.accent.opacity(0.95))
                    }

                    ShareLink(item: item.shareText) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(theme.accent.opacity(0.95))
                    }
                }
            }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mgr: ReadingManager
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var showScreenTimeSetup = false
    @State private var showPersonalization = false
    @State private var didIntroAnimate = false
    @State private var rankedFeedCache: [Passage] = []
    @State private var featuredCache: [Passage] = []
    @State private var communityCache: [Passage] = []
    @AppStorage("personalizationCategoryCSV") private var personalizationCategoryCSV = ""
    @AppStorage("personalizationPrompt") private var personalizationPrompt = ""

    private let discoverTopics: [(icon: String, title: String, color: Color, category: PassageCategory)] = [
        ("brain", "Self-Growth", PassageCategory.psychology.theme.accent, .psychology),
        ("bolt.fill", "Focus", PassageCategory.science.theme.accent, .science),
        ("bubble.left.and.text.bubble.right.fill", "Communication", PassageCategory.philosophy.theme.accent, .philosophy),
        ("briefcase.fill", "Career", PassageCategory.technology.theme.accent, .technology),
        ("banknote.fill", "Money", PassageCategory.economics.theme.accent, .economics),
        ("person.2.fill", "Relationships", PassageCategory.literature.theme.accent, .literature),
    ]

    private let moodPrompts: [(title: String, subtitle: String, icon: String, category: PassageCategory)] = [
        ("Taking a late walk", "wanting something reflective", "moon.stars.fill", .philosophy),
        ("Before a hard conversation", "wanting clear words", "bubble.left.and.text.bubble.right.fill", .psychology),
        ("When focus feels low", "wanting sharp concentration", "bolt.fill", .science),
        ("After a long day", "wanting calm and reset", "book.fill", .literature),
    ]

    private var preferredCategories: Set<PassageCategory> {
        decodeStoredCategories(from: personalizationCategoryCSV)
    }

    private var activeCurationCategories: Set<PassageCategory> {
        preferredCategories.isEmpty ? [.psychology] : preferredCategories
    }

    private var personalizedFeed: [Passage] {
        rankedFeedCache.isEmpty ? computeRankedFeed() : rankedFeedCache
    }

    private var featuredPassages: [Passage] {
        featuredCache.isEmpty ? buildFeatured(from: personalizedFeed) : featuredCache
    }

    private var communityPassages: [Passage] {
        communityCache.isEmpty
            ? buildCommunity(from: personalizedFeed, featured: featuredPassages)
            : communityCache
    }

    private var quickStartPassages: [Passage] {
        Array(personalizedFeed.prefix(3))
    }

    private var curationMatchCount: Int {
        PassageLibrary.all.filter { activeCurationCategories.contains($0.category) }.count
    }

    private var discoverSubtitle: String {
        let prompt = personalizationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            return "Curating your home feed for: \(prompt)"
        }
        if !preferredCategories.isEmpty {
            return "Your growth goals are shaping Featured and Quick Starts."
        }
        return "Self-Growth is active by default. Pick topics to tune your feed."
    }

    private var featuredTitle: String {
        preferredCategories.isEmpty ? "Featured for Self-Growth" : "Featured for Your Focus"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Home Feed")
                                .font(.system(size: 42, weight: .bold, design: .serif))
                                .tracking(-0.8)
                            Text(discoverSubtitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DS.label3)
                                .fixedSize(horizontal: false, vertical: true)
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

                    CreateLessonPromptCard(
                        selectedCategories: activeCurationCategories,
                        customPrompt: personalizationPrompt,
                        matchedCount: curationMatchCount,
                        featuredCount: featuredPassages.count,
                        quickStartCount: quickStartPassages.count,
                        hasExplicitSelections: !preferredCategories.isEmpty,
                        action: {
                            showPersonalization = true
                        },
                        activateSelfGrowth: {
                            personalizationCategoryCSV = encodeStoredCategories([.psychology])
                        }
                    )
                    .padding(.bottom, 12)

                    Text("Curate by topic")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.bottom, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(discoverTopics, id: \.title) { topic in
                                DiscoverTopicChip(
                                    icon: topic.icon,
                                    title: topic.title,
                                    color: topic.color,
                                    isSelected: activeCurationCategories.contains(topic.category)
                                ) {
                                    togglePreferredCategory(topic.category)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 18)

                    Text("Learn by mood")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .tracking(-0.7)
                        .padding(.bottom, 6)

                    Text("Start with how you feel and jump into the right read.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.label3)
                        .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(moodPrompts, id: \.title) { mood in
                                MoodPromptCard(
                                    title: mood.title,
                                    subtitle: mood.subtitle,
                                    icon: mood.icon,
                                    category: mood.category
                                ) {
                                    startMoodReading(for: mood.category)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 22)

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

                    Text("Free Read by vibe")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .tracking(-0.6)
                        .padding(.bottom, 4)

                    Text("Pick a vibe and jump into the Free Read feed.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.label3)
                        .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(communityPassages) { passage in
                                FeaturedLessonCard(passage: passage, compact: true) {
                                    openFreeRead(for: passage.category)
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

                    if !appState.hasUnlimitedAccess {
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
                        title: preferredCategories.isEmpty ? "Quick Starts for Self-Growth" : "Quick Starts for Your Plan",
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
                .opacity(didIntroAnimate ? 1.0 : 0.95)
                .offset(y: didIntroAnimate ? 0 : 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: didIntroAnimate)
            }
            .background(DS.bg)
            .navigationBarHidden(true)
        }
        .onAppear {
            appState.refreshDailyUnlockCreditsIfNeeded()
            screenTime.bootstrap()
            if rankedFeedCache.isEmpty {
                rebuildHomeFeedCaches()
            } else {
                refreshHomeSurfaceOrdering()
            }
            didIntroAnimate = true
        }
        .onChange(of: personalizationCategoryCSV) { _, _ in
            rebuildHomeFeedCaches()
        }
        .onChange(of: personalizationPrompt) { _, _ in
            rebuildHomeFeedCaches()
        }
        .onChange(of: appState.featuredRotationSeed) { _, _ in
            refreshHomeSurfaceOrdering()
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
        if preferredCategories.isEmpty {
            personalizationCategoryCSV = encodeStoredCategories([category])
            return
        }

        var updated = preferredCategories
        if updated.contains(category) {
            updated.remove(category)
        } else {
            updated.insert(category)
        }
        personalizationCategoryCSV = encodeStoredCategories(updated)
    }

    private func startMoodReading(for category: PassageCategory) {
        if let match = personalizedFeed.first(where: { $0.category == category }) {
            appState.startReading(match)
            return
        }

        if let fallback = PassageLibrary.all.first(where: { $0.category == category }) {
            appState.startReading(fallback)
        }
    }

    private func openFreeRead(for category: PassageCategory) {
        appState.freeReadFocusCategory = category
        appState.selectedTab = .freeRead
    }

    private func rebuildHomeFeedCaches() {
        let ranked = computeRankedFeed()
        rankedFeedCache = ranked
        featuredCache = buildFeatured(from: ranked)
        communityCache = buildCommunity(from: ranked, featured: featuredCache)
    }

    private func refreshHomeSurfaceOrdering() {
        let ranked = rankedFeedCache.isEmpty ? computeRankedFeed() : rankedFeedCache
        featuredCache = buildFeatured(from: ranked)
        communityCache = buildCommunity(from: ranked, featured: featuredCache)
    }

    private func computeRankedFeed() -> [Passage] {
        let all = PassageLibrary.all.sorted { passageImpactScore($0) > passageImpactScore($1) }
        let focusCategories = activeCurationCategories
        let prioritized = all.filter { focusCategories.contains($0.category) }
        guard !prioritized.isEmpty else { return all }

        let fallback = all.filter { !focusCategories.contains($0.category) }
        return prioritized + fallback
    }

    private func buildFeatured(from feed: [Passage]) -> [Passage] {
        guard !feed.isEmpty else { return [] }
        let candidateCount = min(feed.count, appState.performanceBudget.homeFeaturedCandidateCount)
        let focused = feed.filter { activeCurationCategories.contains($0.category) }
        let fallback = feed.filter { !activeCurationCategories.contains($0.category) }

        var candidates: [Passage] = Array(focused.prefix(candidateCount))
        if candidates.count < candidateCount {
            candidates.append(contentsOf: fallback.prefix(candidateCount - candidates.count))
        }
        if candidates.isEmpty {
            candidates = Array(feed.prefix(candidateCount))
        }

        let shuffled = candidates.sorted { featuredShuffleValue(for: $0) < featuredShuffleValue(for: $1) }
        return Array(shuffled.prefix(appState.performanceBudget.homeFeaturedCount))
    }

    private func buildCommunity(from feed: [Passage], featured: [Passage]) -> [Passage] {
        let featuredIDs = Set(featured.map(\.id))
        let remainder = feed.filter { !featuredIDs.contains($0.id) }
        let focused = remainder.filter { activeCurationCategories.contains($0.category) }
        let fallback = remainder.filter { !activeCurationCategories.contains($0.category) }
        return Array((focused + fallback).prefix(appState.performanceBudget.homeCommunityCount))
    }

    private func passageImpactScore(_ passage: Passage) -> Double {
        let text = "\(passage.title) \(passage.subtitle) \(passage.content)".lowercased()
        let wordCount = passage.content.split(whereSeparator: \.isWhitespace).count
        var score = 0.0

        if wordCount >= 220 && wordCount <= 650 { score += 0.2 }
        if passage.questions.count >= 3 { score += 0.08 }

        let coreHits = homeImpactKeywords.filter { text.contains($0) }.count
        score += min(0.52, Double(coreHits) * 0.045)

        let categoryHits = homeCategoryKeywords(for: passage.category).filter { text.contains($0) }.count
        score += min(0.3, Double(categoryHits) * 0.075)

        if passage.difficulty == .medium { score += 0.06 }
        if passage.difficulty == .hard { score += 0.04 }

        return score
    }

    private func featuredShuffleValue(for passage: Passage) -> UInt64 {
        var value = UInt64(bitPattern: Int64(passage.id))
        value ^= UInt64(bitPattern: Int64(appState.featuredRotationSeed))
        value &+= 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    private var homeImpactKeywords: [String] {
        [
            "attention", "focus", "habit", "discipline", "judgment", "decision", "responsibility",
            "purpose", "truth", "agency", "character", "freedom", "consequence", "strategy",
            "evidence", "leverage", "compounding", "pattern", "clarity", "resilience"
        ]
    }

    private func homeCategoryKeywords(for category: PassageCategory) -> [String] {
        switch category {
        case .science:
            return ["experiment", "evidence", "neural", "physics", "biology"]
        case .history:
            return ["empire", "civilization", "century", "institution", "conflict"]
        case .philosophy:
            return ["virtue", "wisdom", "ethics", "truth", "reason"]
        case .economics:
            return ["incentive", "tradeoff", "capital", "compounding", "scarcity"]
        case .psychology:
            return ["behavior", "emotion", "identity", "motivation", "self-control"]
        case .literature:
            return ["language", "meaning", "narrative", "voice", "imagination"]
        case .mathematics:
            return ["proof", "logic", "model", "probability", "precision"]
        case .technology:
            return ["system", "algorithm", "design", "tool", "feedback"]
        }
    }
}

struct CreateLessonPromptCard: View {
    let selectedCategories: Set<PassageCategory>
    let customPrompt: String
    let matchedCount: Int
    let featuredCount: Int
    let quickStartCount: Int
    let hasExplicitSelections: Bool
    let action: () -> Void
    let activateSelfGrowth: () -> Void

    private var focusLine: String {
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            return prompt
        }

        let labels = selectedCategories
            .map(\.rawValue)
            .sorted()

        guard !labels.isEmpty else { return "Self-Growth" }
        if labels.count <= 2 { return labels.joined(separator: " • ") }
        return "\(labels[0]) • \(labels[1]) +\(labels.count - 2)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Curate Home Feed")
                        .font(.system(size: 31, weight: .bold, design: .serif))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                    Text(focusLine)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.accentLight)
                        .lineLimit(2)
                    Text("This focus controls your Featured and Quick Starts.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.label3)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                        Text("Edit")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                HomeFeedMetricPill(value: "\(matchedCount)", label: "Matches")
                HomeFeedMetricPill(value: "\(featuredCount)", label: "Featured")
                HomeFeedMetricPill(value: "\(quickStartCount)", label: "Quick")
            }

            if !hasExplicitSelections {
                Button(action: activateSelfGrowth) {
                    Text("Lock in Self-Growth")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DS.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
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
}

private struct HomeFeedMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(DS.label3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
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

struct SnappyCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct FeaturedLessonCard: View {
    let passage: Passage
    var compact: Bool = false
    let action: () -> Void

    private var theme: CategoryTheme { passage.category.theme }
    private var cardWidth: CGFloat { compact ? 152 : 182 }
    private var cardHeight: CGFloat { compact ? 194 : 252 }
    private var visualSeed: Int {
        passage.title.unicodeScalars.reduce(passage.id * 31) { current, scalar in
            (current * 33 + Int(scalar.value)) % 10_000
        }
    }
    private var titleFontSize: CGFloat {
        let length = passage.title.count
        if compact {
            if length <= 34 { return 31 }
            if length <= 52 { return 27 }
            return 23
        }
        if length <= 34 { return 37 }
        if length <= 56 { return 32 }
        return 28
    }
    private var categoryLabel: String { passage.category.rawValue.uppercased() }
    private var symbolName: String { passage.category.icon }
    private var vibeLabel: String {
        switch passage.category {
        case .science: return "Curiosity vibe"
        case .history: return "Long-view vibe"
        case .philosophy: return "Deep-think vibe"
        case .economics: return "Decision vibe"
        case .psychology: return "Calm-focus vibe"
        case .literature: return "Reflective vibe"
        case .mathematics: return "Logic vibe"
        case .technology: return "Builder vibe"
        }
    }
    private var coverGradient: [Color] { [theme.gradientStart, theme.gradientEnd, theme.deepReadBackground] }
    private var footerColors: [Color] {
        [theme.accent.opacity(0.2), Color.white.opacity(0.08), Color.white.opacity(0.03)]
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                coverSection
                footerSection
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(Color.black.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(theme.accent.opacity(0.85))
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(SnappyCardButtonStyle())
    }

    private var coverSection: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: coverGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            coverPattern

            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                Text(categoryLabel)
                    .font(.system(size: compact ? 9 : 10, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(.horizontal, compact ? 8 : 10)
                    .padding(.vertical, 4)
                    .background(theme.chipBackground.opacity(0.95))
                    .clipShape(Capsule())

                Spacer(minLength: 0)

                Text(passage.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .lineLimit(compact ? 4 : 5)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 10 : 12)

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: symbolName)
                        .font(.system(size: compact ? 24 : 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(compact ? 9 : 11)
                        .background(Color.black.opacity(0.22))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                        )
                }
                Spacer()
            }
            .padding(compact ? 10 : 12)
        }
        .frame(height: cardHeight * 0.72)
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                Text(vibeLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(size: compact ? 11 : 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.92))

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                Text("Open")
                    .font(.system(size: compact ? 11 : 12, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 7 : 8)
        .background(
            LinearGradient(
                colors: footerColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var coverPattern: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: compact ? 88 : 116, height: compact ? 88 : 116)
                .offset(x: compact ? 80 : 98, y: compact ? -24 : -30)

            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                .frame(width: compact ? 68 : 88, height: compact ? 92 : 114)
                .rotationEffect(.degrees(Double((visualSeed % 10) - 5)))
                .offset(x: compact ? 30 : 38, y: compact ? 34 : 44)
        }
    }
}

struct MoodPromptCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let category: PassageCategory
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(category.theme.chipBackground)
                        .clipShape(Capsule())

                    Text(category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(DS.label4)
                }

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
            .background(
                LinearGradient(
                    colors: [
                        category.theme.gradientStart.opacity(0.52),
                        DS.surface,
                        category.theme.gradientEnd.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(category.theme.accent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(SnappyCardButtonStyle())
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
                    Image(systemName: appState.hasUnlimitedAccess ? "infinity" : "lock.open.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DS.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Unlock Budget")
                    .font(.system(size: 14, weight: .semibold))
                Text(appState.hasUnlimitedAccess
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

final class GutendexService {
    static let shared = GutendexService()

    private let session: URLSession
    private let cacheKey = "freeRead.cachedStories.v2"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    func fetchStories(limit: Int = 40) async -> [FreeReadStory] {
        let cachedStories = loadCachedStories(limit: limit)

        do {
            let books = try await fetchCandidateBooks(maxPages: 5, maxBooks: 14)

            var stories: [FreeReadStory] = []
            await withTaskGroup(of: [FreeReadStory].self) { group in
                for (index, book) in books.enumerated() {
                    group.addTask {
                        await self.extractStories(from: book, order: index, maxPerBook: 4)
                    }
                }

                for await bookStories in group {
                    stories.append(contentsOf: bookStories)
                }
            }

            let rankedStories = rankStories(stories, limit: limit)
            if !rankedStories.isEmpty {
                saveCachedStories(rankedStories)
                return rankedStories
            }
            return cachedStories
        } catch {
            return cachedStories
        }
    }

    private func fetchCandidateBooks(maxPages: Int, maxBooks: Int) async throws -> [GutendexBook] {
        var collected: [GutendexBook] = []

        for page in 1...maxPages {
            guard let url = URL(string: "https://gutendex.com/books/?languages=en&page=\(page)") else {
                continue
            }

            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(GutendexResponse.self, from: data)
            collected.append(contentsOf: response.results)
        }

        let filtered = collected.filter { preferredTextURL(for: $0) != nil && isHighSignalBook($0) }
        var uniqueByID: [Int: GutendexBook] = [:]
        for book in filtered {
            uniqueByID[book.id] = book
        }

        let sorted = uniqueByID.values.sorted { ($0.downloadCount ?? 0) > ($1.downloadCount ?? 0) }
        return Array(sorted.prefix(maxBooks))
    }

    private func extractStories(from book: GutendexBook, order: Int, maxPerBook: Int) async -> [FreeReadStory] {
        guard let textURLString = preferredTextURL(for: book), let textURL = URL(string: textURLString) else {
            return []
        }

        do {
            let (data, _) = try await session.data(from: textURL)
            guard let rawText = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                return []
            }

            let cleanedText = stripGutenbergBoilerplate(from: rawText)
            let sections = extractSections(from: cleanedText, targetCount: maxPerBook)
            guard !sections.isEmpty else { return [] }

            let author = book.authors.first?.name ?? "Unknown Author"
            let subjects = book.subjects ?? []
            let category = inferCategory(from: subjects, title: book.title)
            let symbol = symbol(for: category, subjects: subjects)
            let canonicalURL = canonicalBookURL(for: book)

            return sections.enumerated().map { index, section in
                FreeReadStory(
                    id: "gut-\(book.id)-\(index)",
                    title: book.title,
                    quote: buildQuote(from: section),
                    body: section,
                    category: category,
                    source: "\(book.title) — \(author) (Project Gutenberg via Gutendex)",
                    symbol: symbol,
                    palette: palette(for: category, seed: order + index),
                    sourceURL: canonicalURL
                )
            }
        } catch {
            return []
        }
    }

    private func preferredTextURL(for book: GutendexBook) -> String? {
        let preferredKeys = [
            "text/plain; charset=utf-8",
            "text/plain; charset=us-ascii",
            "text/plain",
            "text/plain; charset=iso-8859-1",
        ]

        for key in preferredKeys {
            if let url = book.formats[key], !url.contains(".zip") {
                return url
            }
        }

        return nil
    }

    private func canonicalBookURL(for book: GutendexBook) -> String {
        if let html = book.formats["text/html"], !html.contains(".zip") {
            return html
        }
        return "https://www.gutenberg.org/ebooks/\(book.id)"
    }

    private func isHighSignalBook(_ book: GutendexBook) -> Bool {
        let haystack = ([book.title] + (book.subjects ?? []))
            .joined(separator: " ")
            .lowercased()

        let blockedTerms = [
            "children",
            "juvenile",
            "school reader",
            "catalog",
            "dictionary",
            "cookbook",
            "songbook",
            "bible",
            "index of",
            "advertisement"
        ]
        if blockedTerms.contains(where: { haystack.contains($0) }) {
            return false
        }

        return true
    }

    private func stripGutenbergBoilerplate(from text: String) -> String {
        var working = text.replacingOccurrences(of: "\r\n", with: "\n")

        if let startRange = working.range(
            of: "*** START OF THE PROJECT GUTENBERG",
            options: [.caseInsensitive]
        ) {
            let tail = working[startRange.upperBound...]
            if let firstBreak = tail.range(of: "\n") {
                working = String(tail[firstBreak.upperBound...])
            } else {
                working = String(tail)
            }
        }

        if let endRange = working.range(
            of: "*** END OF THE PROJECT GUTENBERG",
            options: [.caseInsensitive]
        ) {
            working = String(working[..<endRange.lowerBound])
        }

        return working
    }

    private func extractSections(from text: String, targetCount: Int) -> [String] {
        let rawParagraphs = text
            .components(separatedBy: "\n\n")
            .map { normalizedParagraph($0) }
            .filter(isValidParagraph)

        guard rawParagraphs.count >= 6 else { return [] }

        let safeTarget = max(1, targetCount)
        let scoredParagraphs = rawParagraphs.enumerated()
            .map { (index: $0.offset, text: $0.element, score: scoreParagraphImpact($0.element)) }
            .sorted { $0.score > $1.score }

        var sections: [String] = []
        var usedIndices: [Int] = []

        for candidate in scoredParagraphs {
            if sections.count >= safeTarget { break }
            if usedIndices.contains(where: { abs($0 - candidate.index) < 3 }) { continue }

            let section = composeSection(from: rawParagraphs, startIndex: candidate.index)
            guard section.count >= 260 else { continue }
            guard scoreSectionImpact(section) >= 0.26 else { continue }

            sections.append(section)
            usedIndices.append(candidate.index)
        }

        if sections.count < safeTarget {
            let step = max(1, rawParagraphs.count / (safeTarget + 1))
            for bucket in 1...safeTarget {
                let index = min(rawParagraphs.count - 1, bucket * step)
                if usedIndices.contains(where: { abs($0 - index) < 2 }) { continue }
                let section = composeSection(from: rawParagraphs, startIndex: index)
                if section.count >= 240 {
                    sections.append(section)
                    usedIndices.append(index)
                }
                if sections.count >= safeTarget { break }
            }
        }

        return Array(sections.prefix(safeTarget))
    }

    private func composeSection(from paragraphs: [String], startIndex: Int) -> String {
        var section = paragraphs[startIndex]
        var cursor = startIndex + 1

        while section.count < 700 && cursor < paragraphs.count {
            let next = paragraphs[cursor]
            if next.count > 180 {
                section += "\n\n" + next
            }
            cursor += 1
        }

        return trimmedToSentence(section, maxChars: 1150)
    }

    private func normalizedParagraph(_ paragraph: String) -> String {
        paragraph
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidParagraph(_ paragraph: String) -> Bool {
        guard paragraph.count >= 180 && paragraph.count <= 1800 else { return false }
        guard paragraph.contains(".") || paragraph.contains(";") || paragraph.contains("!") || paragraph.contains("?") else { return false }
        if appearsToBeHeading(paragraph) { return false }

        let words = paragraph.split(separator: " ")
        guard words.count >= 30 else { return false }

        let letters = paragraph.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        let uppercaseRatio = Double(paragraph.filter(\.isUppercase).count) / Double(letters.count)
        if uppercaseRatio >= 0.4 { return false }

        let digitRatio = Double(paragraph.filter(\.isNumber).count) / Double(max(1, paragraph.count))
        if digitRatio > 0.05 { return false }

        return true
    }

    private func trimmedToSentence(_ text: String, maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        let prefix = String(text.prefix(maxChars))
        if let split = prefix.lastIndex(where: { ".!?".contains($0) }) {
            return String(prefix[...split]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func buildQuote(from section: String) -> String {
        let flattened = section.replacingOccurrences(of: "\n", with: " ")
        let candidates = flattened
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 35 }

        if let best = bestQuoteCandidate(from: candidates) {
            return finalizedQuote(best)
        }

        return finalizedQuote(flattened)
    }

    private func bestQuoteCandidate(from candidates: [String]) -> String? {
        guard !candidates.isEmpty else { return nil }

        let idealRange = candidates.filter { $0.count >= 45 && $0.count <= 185 }
        if let bestIdeal = idealRange.max(by: { scoreSentenceImpact($0) < scoreSentenceImpact($1) }) {
            return bestIdeal
        }

        let fallbackRange = candidates.filter { $0.count >= 25 && $0.count <= 240 }
        if let bestFallback = fallbackRange.max(by: { scoreSentenceImpact($0) < scoreSentenceImpact($1) }) {
            return bestFallback
        }

        return candidates.max(by: { scoreSentenceImpact($0) < scoreSentenceImpact($1) })
    }

    private func finalizedQuote(_ value: String) -> String {
        let trimmed = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if ".!?".contains(last) {
            return trimmed
        }
        return trimmed + "."
    }

    private func scoreSectionImpact(_ section: String) -> Double {
        let paragraphs = section.components(separatedBy: "\n\n")
        guard !paragraphs.isEmpty else { return 0 }
        let paragraphScores = paragraphs.map(scoreParagraphImpact)
        let average = paragraphScores.reduce(0, +) / Double(paragraphScores.count)
        return average + min(0.15, Double(section.count) / 9_000.0)
    }

    private func scoreParagraphImpact(_ paragraph: String) -> Double {
        let lowercased = paragraph.lowercased()
        let words = paragraph.split(separator: " ")
        let wordCount = words.count

        let impactWords = [
            "attention", "mind", "time", "habit", "discipline", "freedom", "courage",
            "character", "purpose", "truth", "wisdom", "power", "virtue", "justice",
            "love", "fear", "change", "choice", "focus", "judgment", "future"
        ]
        let keywordHits = impactWords.filter { lowercased.contains($0) }.count

        var score = 0.0
        if wordCount >= 45 && wordCount <= 150 { score += 0.28 }
        if paragraph.contains("?") { score += 0.06 }
        if paragraph.contains("!") { score += 0.04 }
        if paragraph.contains(";") || paragraph.contains(":") { score += 0.05 }
        score += min(0.34, Double(keywordHits) * 0.05)

        if lowercased.contains("chapter") || lowercased.contains("book ") {
            score -= 0.24
        }

        if paragraph.contains("  ") {
            score -= 0.05
        }

        return max(0, min(1, score))
    }

    private func scoreSentenceImpact(_ sentence: String) -> Double {
        let lowercased = sentence.lowercased()
        let words = sentence.split(separator: " ").count
        var score = 0.0

        if words >= 8 && words <= 32 { score += 0.24 }
        if sentence.contains(",") { score += 0.04 }
        if sentence.contains(";") { score += 0.04 }

        let impactWords = [
            "mind", "attention", "choice", "time", "habit", "truth", "freedom",
            "courage", "character", "future", "wisdom", "purpose", "discipline"
        ]
        score += min(0.52, Double(impactWords.filter { lowercased.contains($0) }.count) * 0.08)

        if lowercased.contains("chapter") || lowercased.contains("book ") {
            score -= 0.3
        }

        return max(0, min(1, score))
    }

    private func appearsToBeHeading(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if trimmed.count < 24 && trimmed.uppercased() == trimmed {
            return true
        }

        let lowercased = trimmed.lowercased()
        let headingPatterns = [
            "chapter ",
            "book ",
            "table of contents",
            "preface",
            "contents"
        ]
        return headingPatterns.contains(where: { lowercased.hasPrefix($0) })
    }

    private func rankStories(_ stories: [FreeReadStory], limit: Int) -> [FreeReadStory] {
        let ranked = stories.sorted {
            storyScore($0) > storyScore($1)
        }

        var uniqueStories: [FreeReadStory] = []
        var seenKeys: Set<String> = []

        for story in ranked {
            let dedupeKey = "\(story.title.lowercased())|\(story.quote.lowercased().prefix(90))"
            guard !seenKeys.contains(dedupeKey) else { continue }
            seenKeys.insert(dedupeKey)
            uniqueStories.append(story)
            if uniqueStories.count >= limit { break }
        }

        return uniqueStories
    }

    private func storyScore(_ story: FreeReadStory) -> Double {
        scoreSentenceImpact(story.quote) + (0.5 * scoreSectionImpact(story.body))
    }

    private func loadCachedStories(limit: Int) -> [FreeReadStory] {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let payload = try? JSONDecoder().decode([CachedFreeReadStory].self, from: data)
        else {
            return []
        }

        let stories: [FreeReadStory] = payload.enumerated().compactMap { element in
            let (index, cached) = element
            guard let category = PassageCategory(rawValue: cached.category) else { return nil }
            return FreeReadStory(
                id: cached.id,
                title: cached.title,
                quote: cached.quote,
                body: cached.body,
                category: category,
                source: cached.source,
                symbol: cached.symbol,
                palette: palette(for: category, seed: index),
                sourceURL: cached.sourceURL
            )
        }

        return Array(stories.prefix(limit))
    }

    private func saveCachedStories(_ stories: [FreeReadStory]) {
        let payload = stories.map {
            CachedFreeReadStory(
                id: $0.id,
                title: $0.title,
                quote: $0.quote,
                body: $0.body,
                category: $0.category.rawValue,
                source: $0.source,
                symbol: $0.symbol,
                sourceURL: $0.sourceURL
            )
        }

        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func inferCategory(from subjects: [String], title: String) -> PassageCategory {
        let haystack = ([title] + subjects).joined(separator: " ").lowercased()

        let map: [(PassageCategory, [String])] = [
            (.philosophy, ["philosophy", "ethics", "stoic", "metaphysics", "reason"]),
            (.science, ["science", "biology", "physics", "chemistry", "natural history"]),
            (.history, ["history", "war", "roman", "ancient", "revolution", "biography"]),
            (.economics, ["econom", "money", "trade", "wealth", "capital"]),
            (.psychology, ["mind", "character", "habit", "moral", "human nature"]),
            (.literature, ["novel", "poetry", "fiction", "drama", "literature"]),
            (.mathematics, ["math", "geometry", "number", "algebra"]),
            (.technology, ["industry", "machine", "technology", "engineering", "invent"]),
        ]

        for (category, keywords) in map where keywords.contains(where: { haystack.contains($0) }) {
            return category
        }

        return .literature
    }

    private func symbol(for category: PassageCategory, subjects: [String]) -> String {
        let subjectLine = subjects.joined(separator: " ").lowercased()
        if subjectLine.contains("women") || subjectLine.contains("love") || subjectLine.contains("marriage") {
            return "heart.text.square.fill"
        }

        switch category {
        case .science: return "atom"
        case .history: return "clock.arrow.circlepath"
        case .philosophy: return "brain.head.profile"
        case .economics: return "banknote.fill"
        case .psychology: return "person.2.fill"
        case .literature: return "text.book.closed.fill"
        case .mathematics: return "function"
        case .technology: return "cpu.fill"
        }
    }

    private func palette(for category: PassageCategory, seed: Int) -> [Color] {
        let variants: [[Color]]
        switch category {
        case .science:
            variants = [[Color(hex: "2F4E8B"), Color(hex: "1E3466"), Color(hex: "0D1D43")]]
        case .history:
            variants = [[Color(hex: "3C4F85"), Color(hex: "24345E"), Color(hex: "111D3E")]]
        case .philosophy:
            variants = [[Color(hex: "2C4A7D"), Color(hex: "1B345D"), Color(hex: "0F1E40")]]
        case .economics:
            variants = [[Color(hex: "2D4778"), Color(hex: "1A3156"), Color(hex: "0E1B39")]]
        case .psychology:
            variants = [[Color(hex: "394D88"), Color(hex: "203462"), Color(hex: "111F43")]]
        case .literature:
            variants = [[Color(hex: "334A7F"), Color(hex: "1D335C"), Color(hex: "101F40")]]
        case .mathematics:
            variants = [[Color(hex: "315293"), Color(hex: "1D3B72"), Color(hex: "10234A")]]
        case .technology:
            variants = [[Color(hex: "294678"), Color(hex: "173159"), Color(hex: "0D1D3F")]]
        }

        return variants[seed % variants.count]
    }
}

private struct GutendexResponse: Decodable {
    let results: [GutendexBook]
}

private struct GutendexBook: Decodable {
    let id: Int
    let title: String
    let authors: [GutendexAuthor]
    let subjects: [String]?
    let formats: [String: String]
    let downloadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case authors
        case subjects
        case formats
        case downloadCount = "download_count"
    }
}

private struct GutendexAuthor: Decodable {
    let name: String
}

private struct CachedFreeReadStory: Codable {
    let id: String
    let title: String
    let quote: String
    let body: String
    let category: String
    let source: String
    let symbol: String
    let sourceURL: String?
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
