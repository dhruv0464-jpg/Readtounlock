import SwiftUI
#if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(DeviceActivity)
import FamilyControls
#endif

struct ScreenTimeSetupView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss

    #if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(DeviceActivity)
    @State private var showPicker = false
    #endif
    @State private var isRequestingAuth = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    statusCard
                    actionsCard

                    if let error = screenTime.authorizationError, !error.isEmpty {
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text("For real app blocking, run this on a physical iPhone with Family Controls enabled in Signing & Capabilities.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.label4)
                        .lineSpacing(3)
                }
                .padding(20)
            }
            .background(DS.bg)
            .navigationTitle("Screen Time Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.accent)
                }
            }
            .onAppear {
                screenTime.bootstrap()
            }
            #if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(DeviceActivity)
            .familyActivityPicker(isPresented: $showPicker, selection: $screenTime.selectedApps)
            .onChange(of: screenTime.selectedApps) { _, newSelection in
                screenTime.setSelectedApps(newSelection)
                screenTime.applyShieldsForSelection()
            }
            #endif
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Status")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(DS.label4)
                .textCase(.uppercase)
                .tracking(0.6)

            statusRow(
                title: "Framework Support",
                value: screenTime.isFrameworkSupported ? "Available" : "Unavailable",
                color: screenTime.isFrameworkSupported ? DS.success : .red
            )
            statusRow(
                title: "Authorization",
                value: screenTime.isAuthorized ? "Granted" : "Not Granted",
                color: screenTime.isAuthorized ? DS.success : DS.warning
            )
            statusRow(
                title: "Protected Items",
                value: "\(screenTime.selectedItemsCount)",
                color: screenTime.selectedItemsCount > 0 ? DS.success : DS.label3
            )
            statusRow(
                title: "Monitoring",
                value: screenTime.isMonitoring ? "Active" : "Inactive",
                color: screenTime.isMonitoring ? DS.success : DS.label3
            )
        }
        .padding(14)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(DS.label4)
                .textCase(.uppercase)
                .tracking(0.6)

            PrimaryButton(title: isRequestingAuth ? "Requesting Access..." : "Authorize Screen Time", icon: "person.badge.shield.checkmark") {
                requestAuthorization()
            }
            .disabled(isRequestingAuth)

            #if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(DeviceActivity)
            PrimaryButton(title: "Choose Apps & Categories", icon: "app.badge.checkmark") {
                showPicker = true
            }
            .disabled(!screenTime.isAuthorized)
            #else
            PrimaryButton(title: "Choose Apps & Categories", icon: "app.badge.checkmark", disabled: true) {}
            #endif

            PrimaryButton(title: "Apply Shields Now", icon: "lock.shield.fill") {
                screenTime.applyShieldsForSelection()
            }
            .disabled(!screenTime.isAuthorized || !screenTime.hasSelection)

            HStack(spacing: 10) {
                Button {
                    screenTime.startMonitoring()
                } label: {
                    Text("Start Monitoring")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DS.surface2)
                        .foregroundStyle(DS.label2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!screenTime.isAuthorized)

                Button {
                    screenTime.stopMonitoring()
                    screenTime.clearShields()
                } label: {
                    Text("Stop & Clear")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DS.surface2)
                        .foregroundStyle(DS.label2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
    }

    private func statusRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.label2)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func requestAuthorization() {
        guard !isRequestingAuth else { return }
        isRequestingAuth = true
        Task {
            await screenTime.requestAuthorization()
            await MainActor.run {
                isRequestingAuth = false
            }
        }
    }
}
