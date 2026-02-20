import SwiftUI

// MARK: - Stats View

struct StatsView: View {
    @EnvironmentObject var mgr: ReadingManager
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your Stats")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .tracking(-0.7)
                        .padding(.bottom, 20)
                    
                    // Big streak card
                    VStack(spacing: 6) {
                        Text("\(mgr.streak)")
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.accent)
                        Text("Day Streak 🔥")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.label3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(DS.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.bottom, 12)
                    
                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatGridCard(value: "\(mgr.totalReadings)", label: "Total Reads")
                        StatGridCard(value: "\(mgr.totalMinutesRead)", label: "Minutes Read")
                        StatGridCard(value: "\(Int(mgr.quizAccuracy * 100))%", label: "Quiz Accuracy")
                        StatGridCard(value: "\(mgr.categoriesRead)", label: "Categories")
                    }
                    .padding(.bottom, 24)
                    
                    // Weekly chart
                    SectionHeader(
                        title: "This Week",
                        trailing: "\(mgr.weeklyTotalMinutes) min total"
                    )
                    .padding(.bottom, 12)
                    
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(mgr.weeklyStats.enumerated()), id: \.element.id) { i, stat in
                            VStack(spacing: 6) {
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DS.accent.opacity(i == 5 ? 1.0 : 0.5))
                                    .frame(height: CGFloat(stat.minutes) / CGFloat(max(1, mgr.maxWeeklyMinutes)) * 80)
                                    .frame(minHeight: 4)
                                
                                Text(stat.dayLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DS.label4)
                            }
                        }
                    }
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(DS.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
                    .padding(.bottom, 4)
                    
                    Text("Minutes read per day")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.label4)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, DS.screenPadding)
                .padding(.bottom, 20)
            }
            .background(DS.bg)
            .navigationBarHidden(true)
        }
    }
}

struct StatGridCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.label4)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mgr: ReadingManager
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var showScreenTimeSetup = false
    @State private var showDailyGoalEditor = false
    @State private var draftDailyGoal = 3
    @State private var showDifficultyPicker = false
    @State private var showAccountSheet = false
    @State private var showHelpSheet = false
    @State private var showMembershipAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Settings")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .tracking(-0.7)
                    
                    // Reading section
                    GroupedSection(label: "Reading") {
                        NavRow(
                            icon: "📚",
                            title: "Daily Goal",
                            value: "\(appState.dailyGoal) readings",
                            action: {
                                draftDailyGoal = appState.dailyGoal
                                showDailyGoalEditor = true
                            }
                        )
                        NavRow(
                            icon: "🎯",
                            title: "Difficulty",
                            value: appState.difficultyLevel,
                            action: { showDifficultyPicker = true }
                        )
                        ToggleRow(icon: "🔒", title: "Strict Mode", isOn: $appState.strictMode, isLast: true)
                    }
                    
                    // Blocked apps
                    GroupedSection(label: "Blocked Apps") {
                        ForEach(Array(mgr.blockedApps.enumerated()), id: \.element.id) { i, app in
                            let iconText: String = {
                                switch app.id {
                                case "instagram": return "📷"
                                case "tiktok": return "🎵"
                                case "twitter": return "𝕏"
                                case "youtube": return "▶️"
                                case "snapchat": return "👻"
                                case "reddit": return "🤖"
                                default: return "📱"
                                }
                            }()
                            
                            ToggleRow(
                                icon: iconText,
                                title: app.name.split(separator: " /").first.map(String.init) ?? app.name,
                                isOn: Binding(
                                    get: { mgr.isAppEnabled(app.id) },
                                    set: { _ in mgr.toggleApp(app.id) }
                                ),
                                isLast: i == mgr.blockedApps.count - 1
                            )
                        }
                    }
                    
                    // Notifications
                    GroupedSection(label: "Notifications") {
                        ToggleRow(icon: "🔔", title: "Push Notifications", isOn: $appState.notificationsEnabled)
                        ToggleRow(icon: "📳", title: "Haptic Feedback", isOn: $appState.hapticsEnabled, isLast: true)
                    }

                    GroupedSection(label: "Screen Time") {
                        NavRow(
                            icon: "🛡️",
                            title: "Authorization",
                            value: screenTime.isAuthorized ? "Granted" : "Not Granted",
                            valueColor: screenTime.isAuthorized ? DS.success : DS.warning,
                            action: { showScreenTimeSetup = true }
                        )
                        NavRow(
                            icon: "📱",
                            title: "Protected Selection",
                            value: "\(screenTime.selectedItemsCount) items",
                            valueColor: screenTime.selectedItemsCount > 0 ? DS.success : DS.label4,
                            isLast: true,
                            action: { showScreenTimeSetup = true }
                        )
                    }

                    PrimaryButton(
                        title: screenTime.hasSelection ? "Manage Screen Time Setup" : "Set Up Screen Time Blocking",
                        icon: "lock.shield.fill"
                    ) {
                        showScreenTimeSetup = true
                    }

                    if !appState.isPremiumUser {
                        PrimaryButton(title: "Upgrade to Pro", icon: "crown.fill") {
                            appState.presentPaywall(from: .settings)
                        }
                    }
                    
                    // Account
                    GroupedSection(label: "Account") {
                        NavRow(icon: "👤", title: "Manage Account", action: {
                            showAccountSheet = true
                        })
                        NavRow(
                            icon: "⭐",
                            title: appState.isPremiumUser ? "Pro Membership" : "Upgrade to Pro",
                            value: appState.isPremiumUser ? "Active" : nil,
                            valueColor: appState.isPremiumUser ? DS.success : DS.accent,
                            action: {
                                if appState.isPremiumUser {
                                    showMembershipAlert = true
                                } else {
                                    appState.presentPaywall(from: .settings)
                                }
                            }
                        )
                        NavRow(icon: "❓", title: "Help & Support", isLast: true, action: {
                            showHelpSheet = true
                        })
                    }
                    
                    // Footer
                    VStack(spacing: 4) {
                        Text("Read to Unlock v1.2.0")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.label4)
                        Text("Made with 📖 in Chicago")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.label4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(.horizontal, DS.screenPadding)
                .padding(.bottom, 20)
            }
            .background(DS.bg)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showScreenTimeSetup) {
            ScreenTimeSetupView()
                .environmentObject(screenTime)
        }
        .sheet(isPresented: $showDailyGoalEditor) {
            NavigationStack {
                Form {
                    Stepper(value: $draftDailyGoal, in: 1...12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Goal")
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(draftDailyGoal) readings per day")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Daily Goal")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            showDailyGoalEditor = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            appState.dailyGoal = draftDailyGoal
                            showDailyGoalEditor = false
                        }
                    }
                }
            }
        }
        .confirmationDialog("Select Difficulty", isPresented: $showDifficultyPicker, titleVisibility: .visible) {
            ForEach(["Easy", "Medium", "Hard"], id: \.self) { level in
                Button(level) {
                    appState.difficultyLevel = level
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showAccountSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Account")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    Text("Name: \(appState.userName.isEmpty ? "Reader" : appState.userName)")
                    Text("Plan: \(appState.isPremiumUser ? "Pro" : "Free")")
                    Text("Daily goal: \(appState.dailyGoal) readings")
                    Text("Notifications: \(appState.notificationsEnabled ? "On" : "Off")")
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DS.bg)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showAccountSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHelpSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Help & Support")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    Text("Need help with screen-time setup, unlock flow, or subscriptions?")
                        .foregroundStyle(DS.label3)
                    Link("Email Support", destination: URL(string: "mailto:support@readtounlock.app")!)
                    Link("Open Project Gutenberg", destination: URL(string: "https://www.gutenberg.org/")!)
                    Link("Open Gutendex API", destination: URL(string: "https://gutendex.com/")!)
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DS.bg)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showHelpSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Pro Membership", isPresented: $showMembershipAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Pro membership is active in this prototype build.")
        }
    }
}
