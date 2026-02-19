import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: PassageCategory? = nil
    @State private var query = ""

    private let premiumCategories: Set<PassageCategory> = [.technology, .mathematics]
    
    var filteredPassages: [Passage] {
        var list = PassageLibrary.all
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            list = list.filter { passage in
                passage.title.localizedCaseInsensitiveContains(query)
                || passage.subtitle.localizedCaseInsensitiveContains(query)
                || passage.category.rawValue.localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    private func isPremiumLocked(_ passage: Passage) -> Bool {
        !appState.isPremiumUser && premiumCategories.contains(passage.category)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Library")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .padding(.bottom, 4)
                    
                    Text("\(PassageLibrary.all.count) passages · Free & Public Domain")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.label4)
                        .padding(.bottom, 14)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.label4)
                        TextField("Search passages or categories", text: $query)
                            .font(.system(size: 14, weight: .medium))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(DS.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(DS.separator, lineWidth: 1)
                    )
                    .padding(.bottom, 12)

                    if !appState.isPremiumUser {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Technology and Mathematics are Pro-only categories.")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Button("Upgrade") {
                                appState.presentPaywall(from: .launch)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(DS.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 10)

                        HStack(spacing: 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(appState.freeReadCreditsRemaining) of \(AppState.dailyFreeReadLimit) free reads left today")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            if !appState.canStartFreeRead {
                                Button("Upgrade") {
                                    appState.presentPaywall(from: .readLimitReached)
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DS.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(DS.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 14)
                    } else {
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("Pro unlocked: full passage library")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.green)
                        .padding(.bottom, 14)
                    }
                    
                    // Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterChip(title: "All", isActive: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            
                            ForEach(PassageCategory.allCases, id: \.rawValue) { cat in
                                FilterChip(title: cat.rawValue, isActive: selectedCategory == cat) {
                                    selectedCategory = cat
                                }
                            }
                        }
                    }
                    .padding(.bottom, 18)
                    
                    // Passages
                    ForEach(filteredPassages) { passage in
                        let isLocked = isPremiumLocked(passage)
                        ReadingCard(passage: passage, action: {
                            if isLocked {
                                appState.presentPaywall(from: .launch)
                            } else {
                                appState.startReading(passage)
                            }
                        }, showDifficulty: true)
                        .overlay(alignment: .topTrailing) {
                            if isLocked {
                                Text("PRO")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DS.accent)
                                    .clipShape(Capsule())
                                    .padding(12)
                            }
                        }
                        .overlay {
                            if isLocked {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.black.opacity(0.22))
                            }
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
        }
    }
}

struct FilterChip: View {
    let title: String
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .black : DS.label3)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? DS.accent : DS.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? DS.accent : DS.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
