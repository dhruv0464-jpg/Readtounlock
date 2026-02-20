import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @State private var restoreMessage: String?

    let perks: [(icon: String, title: String)] = [
        ("sparkles", "Unlimited unlocks per day"),
        ("books.vertical.fill", "Full passage library and all categories"),
        ("chart.xyaxis.line", "Deeper focus and reading analytics"),
        ("person.2.fill", "Family mode and shared goals"),
        ("wand.and.stars", "Future AI coaching features"),
    ]

    private var headerBadge: String {
        switch appState.paywallEntryPoint {
        case .onboarding:
            return "START STRONG"
        case .launch:
            return "UNLOCK ALL FEATURES"
        case .unlockLimitReached:
            return "DAILY LIMIT REACHED"
        case .readLimitReached:
            return "FREE READS USED"
        case .settings:
            return "UPGRADE"
        }
    }

    private var headline: String {
        switch appState.paywallEntryPoint {
        case .onboarding:
            return "Build a Smarter\nScreen-Time Habit"
        case .launch:
            return "Unlock the Full\nReadToUnlock App"
        case .unlockLimitReached:
            return "Keep Unlocking\nWithout Limits"
        case .readLimitReached:
            return "Keep Reading\nWithout Limits"
        case .settings:
            return "Go Pro for\nBetter Results"
        }
    }

    private var subheadline: String {
        switch appState.paywallEntryPoint {
        case .onboarding:
            return "Make every unlock a learning checkpoint with unlimited reading gates."
        case .launch:
            return "Get unlimited app unlocks, unlimited reads, and access to every category from day one."
        case .unlockLimitReached:
            return "You've used today's free unlocks. Upgrade for unlimited app unlocks."
        case .readLimitReached:
            return "You've used today's free reads. Upgrade for unlimited reading and all categories."
        case .settings:
            return "Get the full Read to Unlock experience with one upgrade."
        }
    }

    private var ctaTitle: String {
        appState.selectedPlan == .yearly ? "Start 7-Day Free Trial" : "Continue with \(appState.selectedPlan.rawValue)"
    }

    private var footerText: String {
        if appState.selectedPlan == .yearly {
            return "Free for 7 days, then \(appState.selectedPlan.price)\(appState.selectedPlan.period). Cancel anytime."
        }
        return "Billed at \(appState.selectedPlan.price)\(appState.selectedPlan.period). Cancel anytime."
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1410"), Color(hex: "120E0A"), DS.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        hero
                            .padding(.bottom, 24)

                        planPicker
                            .padding(.bottom, 18)

                        PrimaryButton(title: ctaTitle, icon: "crown.fill") {
                            appState.isPremiumUser = true
                            appState.goHome()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                        Text(footerText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.label4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 20)

                        perksSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 18)

                        trustRow

                        Button("Restore Purchases") {
                            restorePurchases()
                        }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.label3)
                            .padding(.top, 14)
                            .padding(.bottom, 22)
                    }
                }
            }
        }
        .alert("Restore Purchases", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { showing in
                if !showing { restoreMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .onAppear {
            appState.refreshDailyUnlockCreditsIfNeeded()
        }
    }

    private var topBar: some View {
        HStack {
            Text(headerBadge)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(DS.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DS.accent.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            Button {
                appState.goHome()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.label3)
                    .frame(width: 34, height: 34)
                    .background(DS.surface2.opacity(0.95))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F5D77A"), DS.accent, Color(hex: "C99A2E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 82, height: 82)
                .overlay(
                    Image(systemName: "crown.fill")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.82))
                )
                .shadow(color: DS.accent.opacity(0.35), radius: 24, y: 12)
                .padding(.bottom, 20)

            Text(headline)
                .font(.system(size: 33, weight: .bold))
                .tracking(-1)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text(subheadline)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.label3)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 16)

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.accent)
                }
                Text("4.9 • 12.4K ratings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.label4)
            }
        }
        .padding(.top, 8)
    }

    private var planPicker: some View {
        HStack(spacing: 10) {
            ForEach(SubscriptionPlan.allCases, id: \.rawValue) { plan in
                PaywallPlanCard(
                    plan: plan,
                    isSelected: appState.selectedPlan == plan,
                    onTap: { appState.selectedPlan = plan }
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var perksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WHAT YOU GET")
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(DS.label4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(perks.enumerated()), id: \.offset) { index, perk in
                    HStack(spacing: 12) {
                        Image(systemName: perk.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.accent)
                            .frame(width: 30, height: 30)
                            .background(DS.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        Text(perk.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.label2)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if index < perks.count - 1 {
                        Divider()
                            .background(DS.separator)
                    }
                }
            }
            .background(DS.surface.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(DS.separator, lineWidth: 1)
            )
        }
    }

    private var trustRow: some View {
        HStack(spacing: 16) {
            Text("Privacy")
            Text("Terms")
            Text("Cancel Anytime")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(DS.label4)
    }

    private func restorePurchases() {
        if appState.isPremiumUser {
            restoreMessage = "Your Pro access is already active."
            return
        }

        // POC behavior until StoreKit is integrated.
        restoreMessage = "No previous purchases were found for this test build."
    }
}

struct PaywallPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                if plan == .yearly {
                    Text("BEST VALUE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.7)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(DS.accent)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 15)
                }

                Text(plan.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.accent : DS.label4)

                Text(plan.price)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(isSelected ? .white : DS.label2)

                Text(plan.period)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.label4)

                if let savings = plan.savings {
                    Text(savings)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.success)
                } else {
                    Color.clear.frame(height: 12)
                }

                Circle()
                    .strokeBorder(isSelected ? DS.accent : DS.surface3, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(DS.accent)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: isSelected ? [DS.surface, DS.surface2] : [DS.surface, DS.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? DS.accent : DS.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
