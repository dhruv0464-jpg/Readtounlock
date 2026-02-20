import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App icon
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "D8C695"), Color(hex: "A48E5A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.black)
                )
                .shadow(color: Color(hex: "C8B47A").opacity(0.26), radius: 30)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
            
            // Title
            VStack(spacing: 4) {
                Text("Read to Unlock")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .tracking(-0.8)
                
                Text("Learn before you scroll")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.label3)
            }
            .opacity(textOpacity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "1A1E15"), DS.bg, Color(hex: "090A08")],
                startPoint: .top,
                endPoint: .center
            )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                appState.splashDidFinish()
            }
        }
    }
}
