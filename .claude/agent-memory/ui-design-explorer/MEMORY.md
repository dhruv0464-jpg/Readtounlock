# ScribeScroll (ReadToUnlock) - UI Design Explorer Memory

## Project Structure
- Xcode project: `Readtounlock.xcodeproj`, scheme: `Readtounlock`
- Build command: `xcodebuild -scheme Readtounlock -destination 'generic/platform=iOS Simulator' build`
- SwiftUI app targeting iOS

## Design System (`Views/DesignSystem.swift`)
- Centralized in `DS` enum with static color tokens
- Primary accent: `#EDBE53` (golden/amber)
- Dark warm background: `#0C0907` -> `#1A1410` -> `#2A2119` -> `#3D3128`
- Golden palette tokens: accent, accent2, accentLight, accentMuted, success, warning
- All greens/oranges replaced with golden-family colors as of Feb 2026
- Components: PrimaryButton, ToggleRow, NavRow, StatCard, CategoryBadge, DifficultyBadge, ReadingCard, SectionHeader, GroupedSection

## Color Scheme Conventions
- Success states: `DS.success` (#D4B86A) - golden-success, replaces system green
- Warning states: `DS.warning` (#C9A65A) - warm gold, replaces system orange
- Error states: keep `.red` (universal semantic meaning)
- Toggle tint: uses `DS.accent`
- Category colors: all warm golden family (E8C04E through BDA048)
- Difficulty colors: golden gradient (easy=D4B86A, medium=C9A65A, hard=C48B5C)

## Key File Locations
- Design tokens: `Views/DesignSystem.swift`
- Models/enums: `Models/Models.swift`
- Home + sub-components: `Views/Main/HomeView.swift`
- Onboarding flow: `Views/Onboarding/OnboardingView.swift`
- Paywall: `Views/Onboarding/PaywallView.swift`
- Splash: `Views/Onboarding/SplashView.swift`
- Library: `Views/Main/LibraryView.swift`
- Stats + Settings: `Views/Main/StatsSettingsViews.swift`
- Quiz + Results: `Views/Reading/QuizResultsViews.swift`
- Reading view: `Views/Reading/ReadingView.swift`
- Root navigation: `Views/RootView.swift`
- Screen Time: `Views/Main/ScreenTimeSetupView.swift`
- ReadingManager: `Managers/ReadingManager.swift`
