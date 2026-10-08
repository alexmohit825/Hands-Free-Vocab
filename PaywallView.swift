import SwiftUI
import StoreKit

/// Driver-safe, high-converting paywall modal for Orator: Executive Lexicon.
/// Highlights the 1,800-word collegiate repository, 60 sets, and one-time $4.99 lifetime ownership.
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreKitManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background dark gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.14),
                        Color(red: 0.02, green: 0.03, blue: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Badge
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                            Text("ONE-TIME PURCHASE • ZERO SUBSCRIPTIONS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(20)
                        .padding(.top, 10)

                        // Title & Subtitle
                        VStack(spacing: 8) {
                            Text("Unlock Lifetime Access")
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Master all 1,800 collegiate and executive words hands-free on your daily commute.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        // Feature Highlights Card
                        VStack(spacing: 16) {
                            featureRow(
                                icon: "crown.fill",
                                color: .orange,
                                title: "1,800 Curated Words Across 60 Sets",
                                subtitle: "Complete curricula across Executive & Orator, GRE, Classic Literary & Medicolegal tracks."
                            )

                            featureRow(
                                icon: "arrow.triangle.2.circlepath.circle.fill",
                                color: .cyan,
                                title: "Continuous Cross-Set Autoplay",
                                subtitle: "Seamlessly transitions from set to set with spoken milestone announcements and calibrated pauses."
                            )

                            featureRow(
                                icon: "waveform",
                                color: .green,
                                title: "0ms On-Device Speech Radar",
                                subtitle: "Whisper-quiet voice commands ('Next', 'Repeat', 'Mastered', 'Explain', 'Root') without cellular latency."
                            )

                            featureRow(
                                icon: "bolt.shield.fill",
                                color: .purple,
                                title: "Zero Ads • Zero Telemetry",
                                subtitle: "100% on-device local execution with lifetime access and zero recurring monthly fees."
                            )
                        }
                        .padding(20)
                        .background(Color(white: 0.08))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                        // Error Banner
                        if let error = storeManager.errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Purchase Action Button
                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    let success = await storeManager.purchaseLifetime()
                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    if storeManager.isPurchasing {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Text("Unlock All 60 Sets • \(priceString)")
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.yellow)
                                .cornerRadius(16)
                            }
                            .disabled(storeManager.isPurchasing)

                            // Restore Purchases Button
                            Button {
                                Task {
                                    await storeManager.restorePurchases()
                                    if storeManager.isUnlocked {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .disabled(storeManager.isPurchasing)
                        }
                        .padding(.top, 8)

                        // Legal Footnote
                        VStack(spacing: 4) {
                            Text("Payment is charged to your Apple ID upon confirmation.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.7))

                            HStack(spacing: 16) {
                                Link("Privacy Policy", destination: URL(string: "https://alexmohit825.github.io/Hands-Free-Vocab/privacy.html")!)
                                Link("Support Guide", destination: URL(string: "https://alexmohit825.github.io/Hands-Free-Vocab/")!)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange.opacity(0.8))
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 22))
                    }
                }
            }
        }
    }

    private var priceString: String {
        storeManager.lifetimeProduct?.displayPrice ?? "$4.99"
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
            Spacer()
        }
    }
}
