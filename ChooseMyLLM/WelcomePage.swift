import SwiftUI

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.34, green: 0.65, blue: 1), .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 24, y: 10)

                Image(systemName: "globe")
                    .font(.system(size: 53, weight: .light))
                    .foregroundStyle(.white)
            }
            .frame(width: 100, height: 100)
            .padding(.top, 46)

            Text(AppConfiguration.displayName)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .tracking(-0.7)
                .padding(.top, 24)

            Text(AppConfiguration.tagline)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 8)

            Text("Version \(AppConfiguration.version)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.07), in: Capsule())
                .padding(.top, 18)

            Spacer()

            Text(AppConfiguration.credit)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
        .frame(width: 360, height: 360)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.16, blue: 0.27),
                                 Color(red: 0.04, green: 0.06, blue: 0.11)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

#Preview {
    WelcomePage()
}
