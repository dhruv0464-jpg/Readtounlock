import SwiftUI
import Combine

enum AppScreen: Equatable {
    case splash
    case onboarding
    case paywall
    case main
    case reading(Passage)
    case quiz(Passage)
    case results(score: Int, total: Int, passage: Passage)
    case blockedOverlay(BlockedApp)
    
    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.splash, .splash), (.onboarding, .onboarding),
             (.paywall, .paywall), (.main, .main):
            return true
        case let (.reading(a), .reading(b)):
            return a.id == b.id
        case let (.quiz(a), .quiz(b)):
            return a.id == b.id
        case let (.results(s1, t1, p1), .results(s2, t2, p2)):
            return s1 == s2 && t1 == t2 && p1.id == p2.id
        case let (.blockedOverlay(a), .blockedOverlay(b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

enum PaywallEntryPoint {
    case onboarding
    case launch
    case unlockLimitReached
    case readLimitReached
    case settings
}

enum MainTab: String, CaseIterable {
    case home = "Home"
    case freeRead = "Free Read"
    case library = "Library"
    case stats = "Stats"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .freeRead: return "text.quote"
        case .library: return "books.vertical.fill"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

class AppState: ObservableObject {
    static let dailyFreeUnlockLimit = 3
    static let dailyFreeReadLimit = 5
    static let disablePaywallsForTesting = true

    @Published var currentScreen: AppScreen = .splash
    @Published var selectedTab: MainTab = .home
    @Published var freeReadFocusCategory: PassageCategory?
    @Published var onboardingStep: Int = 0
    @Published var selectedPlan: SubscriptionPlan = .yearly
    @Published var paywallEntryPoint: PaywallEntryPoint = .onboarding
    @Published var pendingUnlockAppID: String?
    @Published private var quizUnlockedPassageIDs: Set<Int> = []
    
    // User preferences persisted
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("isPremiumUser") var isPremiumUser = false
    @AppStorage("userName") var userName = ""
    @AppStorage("dailyGoal") var dailyGoal = 3
    @AppStorage("difficultyLevel") var difficultyLevel = "Medium"
    @AppStorage("strictMode") var strictMode = false
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("hapticsEnabled") var hapticsEnabled = true
    @AppStorage("freeUnlockCreditsRemaining") var freeUnlockCreditsRemaining = AppState.dailyFreeUnlockLimit
    @AppStorage("lastUnlockCreditResetAt") private var lastUnlockCreditResetAt: Double = 0
    @AppStorage("freeReadCreditsRemaining") var freeReadCreditsRemaining = AppState.dailyFreeReadLimit
    @AppStorage("lastReadCreditResetAt") private var lastReadCreditResetAt: Double = 0

    var hasUnlimitedAccess: Bool {
        isPremiumUser || Self.disablePaywallsForTesting
    }

    init() {
        refreshDailyUnlockCreditsIfNeeded()
    }
    
    func navigate(to screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = screen
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        if hasUnlimitedAccess {
            goHome()
        } else {
            presentPaywall(from: .launch)
        }
    }
    
    func goHome() {
        navigate(to: .main)
        selectedTab = .home
        pendingUnlockAppID = nil
    }

    func presentPaywall(from entryPoint: PaywallEntryPoint) {
        if Self.disablePaywallsForTesting {
            goHome()
            return
        }
        paywallEntryPoint = entryPoint
        navigate(to: .paywall)
    }

    func splashDidFinish() {
        refreshDailyUnlockCreditsIfNeeded()
        if !hasCompletedOnboarding {
            navigate(to: .onboarding)
            return
        }

        if hasUnlimitedAccess {
            navigate(to: .main)
        } else {
            presentPaywall(from: .launch)
        }
    }

    var canUnlockBlockedApps: Bool {
        hasUnlimitedAccess || freeUnlockCreditsRemaining > 0
    }

    var canStartFreeRead: Bool {
        hasUnlimitedAccess || freeReadCreditsRemaining > 0
    }

    func markPassageReadyForQuiz(_ passageID: Int) {
        quizUnlockedPassageIDs.insert(passageID)
    }

    func canTakeQuiz(for passage: Passage) -> Bool {
        quizUnlockedPassageIDs.contains(passage.id)
    }

    @discardableResult
    func consumeUnlockCreditIfNeeded() -> Bool {
        refreshDailyUnlockCreditsIfNeeded()
        guard !hasUnlimitedAccess else { return true }
        guard freeUnlockCreditsRemaining > 0 else {
            return false
        }

        freeUnlockCreditsRemaining -= 1
        return true
    }

    @discardableResult
    func consumeReadCreditIfNeeded() -> Bool {
        refreshDailyUnlockCreditsIfNeeded()
        guard !hasUnlimitedAccess else { return true }
        guard freeReadCreditsRemaining > 0 else {
            return false
        }

        freeReadCreditsRemaining -= 1
        return true
    }

    func startReading(_ passage: Passage, isUnlockFlow: Bool = false) {
        if isUnlockFlow {
            navigate(to: .reading(passage))
            return
        }

        if consumeReadCreditIfNeeded() {
            navigate(to: .reading(passage))
        } else {
            presentPaywall(from: .readLimitReached)
        }
    }

    func refreshDailyUnlockCreditsIfNeeded(referenceDate: Date = Date()) {
        guard !hasUnlimitedAccess else {
            freeUnlockCreditsRemaining = AppState.dailyFreeUnlockLimit
            freeReadCreditsRemaining = AppState.dailyFreeReadLimit
            lastUnlockCreditResetAt = referenceDate.timeIntervalSince1970
            lastReadCreditResetAt = referenceDate.timeIntervalSince1970
            return
        }

        let calendar = Calendar.current
        let lastResetDate = Date(timeIntervalSince1970: lastUnlockCreditResetAt)
        let lastReadResetDate = Date(timeIntervalSince1970: lastReadCreditResetAt)

        if lastUnlockCreditResetAt == 0 || !calendar.isDate(lastResetDate, inSameDayAs: referenceDate) {
            freeUnlockCreditsRemaining = AppState.dailyFreeUnlockLimit
            lastUnlockCreditResetAt = referenceDate.timeIntervalSince1970
        }

        if lastReadCreditResetAt == 0 || !calendar.isDate(lastReadResetDate, inSameDayAs: referenceDate) {
            freeReadCreditsRemaining = AppState.dailyFreeReadLimit
            lastReadCreditResetAt = referenceDate.timeIntervalSince1970
        }
    }
}

enum SubscriptionPlan: String, CaseIterable {
    case weekly = "Weekly"
    case yearly = "Annual"
    case monthly = "Monthly"
    
    var price: String {
        switch self {
        case .weekly: return "$2.99"
        case .yearly: return "$29.99"
        case .monthly: return "$6.99"
        }
    }
    
    var period: String {
        switch self {
        case .weekly: return "/week"
        case .yearly: return "/year"
        case .monthly: return "/month"
        }
    }
    
    var savings: String? {
        switch self {
        case .yearly: return "75% OFF"
        default: return nil
        }
    }
    
    var trial: String? {
        switch self {
        case .yearly: return "7-day free trial"
        default: return nil
        }
    }
}
