import SwiftUI

// MARK: - Quiz View

struct QuizView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mgr: ReadingManager
    let passage: Passage
    
    @State private var currentQ = 0
    @State private var selected: [Int: Int] = [:]
    @State private var submitted: [Int: Bool] = [:]
    
    let letters = ["A", "B", "C", "D"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Nav
            HStack {
                Button {
                    appState.navigate(to: .reading(passage))
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
                Text("\(currentQ + 1) of \(passage.questions.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.label3)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<passage.questions.count, id: \.self) { i in
                    Capsule()
                        .fill(dotColor(for: i))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.3), value: submitted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    let q = passage.questions[currentQ]
                    
                    Text("QUESTION \(currentQ + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(DS.accent)
                        .padding(.bottom, 12)
                    
                    Text(q.text)
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .lineSpacing(4)
                        .padding(.bottom, 24)
                    
                    // Options
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                        OptionButton(
                            letter: letters[i],
                            text: option,
                            state: optionState(questionIndex: currentQ, optionIndex: i, correctIndex: q.correctIndex)
                        ) {
                            if submitted[currentQ] == nil {
                                selected[currentQ] = i
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Submit
                    PrimaryButton(
                        title: submitButtonTitle,
                        disabled: selected[currentQ] == nil || submitted[currentQ] != nil
                    ) {
                        submitAnswer()
                    }
                    .padding(.top, 12)
                    
                    // Feedback
                    if let isCorrect = submitted[currentQ] {
                        HStack(spacing: 6) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text(isCorrect ? "Correct!" : "Not quite — correct answer highlighted above.")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(isCorrect ? DS.success : .red)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background((isCorrect ? DS.success : Color.red).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(DS.bg)
        .onAppear {
            if !appState.canTakeQuiz(for: passage) {
                appState.navigate(to: .reading(passage))
            }
        }
    }
    
    private func dotColor(for index: Int) -> Color {
        if let correct = submitted[index] {
            return correct ? DS.success : .red
        }
        return index <= currentQ ? DS.accent : DS.surface3
    }
    
    private var submitButtonTitle: String {
        if submitted[currentQ] != nil {
            return currentQ < passage.questions.count - 1 ? "Loading next..." : "Calculating..."
        }
        return "Submit Answer"
    }
    
    private func optionState(questionIndex: Int, optionIndex: Int, correctIndex: Int) -> OptionState {
        guard let _ = submitted[questionIndex] else {
            return selected[questionIndex] == optionIndex ? .selected : .idle
        }
        if optionIndex == correctIndex { return .correct }
        if selected[questionIndex] == optionIndex { return .wrong }
        return .idle
    }
    
    private func submitAnswer() {
        let q = passage.questions[currentQ]
        let isCorrect = selected[currentQ] == q.correctIndex
        submitted[currentQ] = isCorrect
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if currentQ < passage.questions.count - 1 {
                withAnimation { currentQ += 1 }
            } else {
                let score = submitted.values.filter { $0 }.count
                mgr.recordQuizResult(passage: passage, correct: score, total: passage.questions.count)
                appState.navigate(to: .results(score: score, total: passage.questions.count, passage: passage))
            }
        }
    }
}

enum OptionState { case idle, selected, correct, wrong }

struct OptionButton: View {
    let letter: String
    let text: String
    let state: OptionState
    let onTap: () -> Void
    
    var bg: Color {
        switch state {
        case .idle: return DS.surface
        case .selected: return DS.accent.opacity(0.08)
        case .correct: return DS.success.opacity(0.1)
        case .wrong: return Color.red.opacity(0.1)
        }
    }

    var border: Color {
        switch state {
        case .idle: return DS.separator
        case .selected: return DS.accent
        case .correct: return DS.success
        case .wrong: return .red
        }
    }

    var letterBg: Color {
        switch state {
        case .idle: return DS.surface2
        case .selected: return DS.accent
        case .correct: return DS.success
        case .wrong: return .red
        }
    }
    
    var letterFg: Color {
        switch state {
        case .idle: return DS.label3
        default: return .black
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(letter)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(letterFg)
                    .frame(width: 28, height: 28)
                    .background(letterBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.label)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(16)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(border, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Results View

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mgr: ReadingManager
    @EnvironmentObject var screenTime: ScreenTimeManager
    let score: Int
    let total: Int
    let passage: Passage
    
    @State private var showConfetti = false
    
    var passed: Bool { score >= 2 }
    var isUnlockFlow: Bool { appState.pendingUnlockAppID != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
            RoundedRectangle(cornerRadius: 28)
                .fill(passed ? DS.accent.opacity(0.12) : Color.red.opacity(0.12))
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: passed ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(passed ? DS.accent : .red)
                )
                .padding(.bottom, 24)
            
            Text(passed ? "Passage Complete!" : "Almost There")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .padding(.bottom, 10)
            
            Text(resultSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(DS.label3)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.bottom, 28)
            
            // Score
            Text("\(score)/\(total)")
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundStyle(passed ? DS.accent : .red)
                .padding(.bottom, 6)
            
            Text("Questions Correct")
                .font(.system(size: 14))
                .foregroundStyle(DS.label4)
                .padding(.bottom, 36)

            if passed && isUnlockFlow && !appState.isPremiumUser {
                Text("\(appState.freeUnlockCreditsRemaining) free unlocks left today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.label4)
                    .padding(.bottom, 10)
            }
            
            Spacer()
            
            PrimaryButton(title: primaryButtonTitle) {
                handlePrimaryAction()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .background(DS.bg)
        .onAppear {
            if passed { showConfetti = true }
        }
    }

    private var resultSubtitle: String {
        if passed {
            if isUnlockFlow {
                return "You passed. We'll grant 15 minutes after you continue."
            }
            return "Great read. Keep the momentum going."
        }
        return "You need 2/3 correct to unlock. Try this passage again."
    }

    private var primaryButtonTitle: String {
        passed ? (isUnlockFlow ? "Unlock App" : "Back to Home") : "Try Again"
    }

    private func handlePrimaryAction() {
        if !passed {
            appState.navigate(to: .reading(passage))
            return
        }

        guard let appID = appState.pendingUnlockAppID else {
            appState.goHome()
            return
        }

        if appState.consumeUnlockCreditIfNeeded() {
            mgr.grantUnlock(for: appID)
            screenTime.removeShields(for: appID, duration: ScreenTimeShared.unlockDurationSeconds)
            appState.goHome()
        } else {
            appState.presentPaywall(from: .unlockLimitReached)
        }
    }
}

// MARK: - Blocked App Overlay (iOS Sheet)

struct BlockedOverlayView: View {
    @EnvironmentObject var appState: AppState
    let blockedApp: BlockedApp
    
    var iconText: String {
        switch blockedApp.id {
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
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { appState.goHome() }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Sheet handle
                    Capsule()
                        .fill(DS.surface3)
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Content
                    VStack(spacing: 0) {
                        Text(iconText)
                            .font(.system(size: 48))
                            .padding(.bottom, 4)
                        
                        Text("\(blockedApp.name) is locked")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.label4)
                            .padding(.bottom, 16)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(DS.accent)
                            .padding(.bottom, 16)
                        
                        Text("Time to Read")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.6)
                            .padding(.bottom, 8)
                        
                        Text("You've used all your \(blockedApp.name) time today.\nRead a passage to earn 15 more minutes.")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.label3)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        if !appState.isPremiumUser {
                            Text("\(appState.freeUnlockCreditsRemaining) free unlocks remaining today")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.label4)
                                .padding(.bottom, 12)
                        }
                    }
                    
                    // Reading options
                    VStack(spacing: 8) {
                        ForEach(Array(PassageLibrary.all.prefix(3))) { p in
                            Button {
                                appState.pendingUnlockAppID = blockedApp.id
                                appState.startReading(p, isUnlockFlow: true)
                            } label: {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(p.category.color)
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(DS.label)
                                        Text("\(p.category.rawValue) · \(p.readTimeLabel)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DS.label4)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DS.label4)
                                }
                                .padding(14)
                                .background(DS.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(DS.separator, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    Button("Dismiss") {
                        appState.goHome()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.label4)
                    .padding(.bottom, 24)
                }
                .background(DS.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
