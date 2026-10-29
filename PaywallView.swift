import SwiftUI
import StoreKit

/// Editorial Book-Plate Paywall Modal for Orator: Executive Lexicon.
/// Highlights the 1,800-word collegiate repository, 60 sets, and one-time $4.99 lifetime ownership.
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreKitManager.shared

    private let canvasParchment = Color(red: 0.937, green: 0.925, blue: 0.894) // #EFECE4
    private let cardWhite = Color.white
    private let warmLinen = Color(red: 0.969, green: 0.961, blue: 0.941)
    private let inkCharcoal = Color(red: 0.110, green: 0.133, blue: 0.133)     // #1C2222
    private let slateMuted = Color(red: 0.345, green: 0.400, blue: 0.400)
    private let coastalSage = Color(red: 0.451, green: 0.620, blue: 0.608)     // #739E9B
    private let matchaMint = Color(red: 0.710, green: 0.839, blue: 0.612)      // #B5D69C
    private let coralTerracotta = Color(red: 0.878, green: 0.455, blue: 0.357)
    private let warmGold = Color(red: 0.949, green: 0.788, blue: 0.298)

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                canvasParchment.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Header Badge
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(inkCharcoal)
                                .font(.system(size: 12, weight: .bold))
                            Text("ONE-TIME PURCHASE • ZERO SUBSCRIPTIONS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(inkCharcoal)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(warmGold)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(inkCharcoal, lineWidth: 1.4)
                        )
                        .padding(.top, 8)

                        // Title & Subtitle
                        VStack(spacing: 8) {
                            Text("Unlock the Complete Executive Lexicon")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(inkCharcoal)
                                .multilineTextAlignment(.center)

                            Text("Master all 1,800 collegiate, literary, and medicolegal words hands-free on your daily commute.")
                                .font(.system(size: 15, weight: .regular, design: .serif))
                                .foregroundColor(slateMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                        }

                        // Feature Highlights Card
                        VStack(spacing: 16) {
                            featureRow(
                                icon: "crown.fill",
                                fill: warmGold,
                                title: "1,800 Curated Words Across 60 Sets",
                                subtitle: "Complete curricula across Executive & Orator, GRE, Classic Literary & Medicolegal tracks."
                            )

                            featureRow(
                                icon: "car.fill",
                                fill: coastalSage.opacity(0.45),
                                title: "CarPlay & Hands-Free Knowledge Checks",
                                subtitle: "Seamless set-to-set autoplay and spoken 3-question recall quizzes behind the wheel."
                            )

                            featureRow(
                                icon: "waveform",
                                fill: matchaMint,
                                title: "0ms On-Device Speech Radar",
                                subtitle: "Instant offline voice commands ('Next', 'Repeat', 'Explain', 'Root') with zero cloud lag."
                            )

                            featureRow(
                                icon: "checkmark.shield.fill",
                                fill: coralTerracotta.opacity(0.35),
                                title: "Pay Once • Own Forever",
                                subtitle: "100% private on-device execution with zero recurring monthly subscription traps."
                            )
                        }
                        .padding(20)
                        .background(cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(inkCharcoal, lineWidth: 1.5)
                        )

                        if let error = storeManager.errorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(coralTerracotta)
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
                                            .tint(inkCharcoal)
                                    } else {
                                        Text("Unlock All 60 Sets • \(priceString)")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(inkCharcoal)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(coastalSage)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(inkCharcoal, lineWidth: 1.6)
                                )
                                .shadow(color: inkCharcoal.opacity(0.18), radius: 0, x: 0, y: 3)
                            }
                            .disabled(storeManager.isPurchasing)

                            Button {
                                Task {
                                    await storeManager.restorePurchases()
                                    if storeManager.isUnlocked {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Restore Previous Purchase")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(slateMuted)
                            }
                            .disabled(storeManager.isPurchasing)
                        }

                        VStack(spacing: 4) {
                            Text("One-time payment charged to your Apple ID upon confirmation.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(slateMuted)

                            HStack(spacing: 16) {
                                Link("Privacy Policy", destination: URL(string: "https://alexmohit825.github.io/Hands-Free-Vocab/privacy.html")!)
                                Link("Support Guide", destination: URL(string: "https://alexmohit825.github.io/Hands-Free-Vocab/")!)
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(inkCharcoal)
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
                            .foregroundColor(inkCharcoal)
                            .font(.system(size: 22))
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var priceString: String {
        storeManager.lifetimeProduct?.displayPrice ?? "$4.99"
    }

    private func featureRow(icon: String, fill: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(inkCharcoal, lineWidth: 1.3)
                    )
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(inkCharcoal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(inkCharcoal)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(slateMuted)
                    .lineSpacing(2)
            }
            Spacer()
        }
    }
}
