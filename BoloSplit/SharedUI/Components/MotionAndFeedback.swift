//
//  MotionAndFeedback.swift
//  BoloSplit
//
//  Reusable micro-interactions, tactile button styles, skeleton shimmers, and avatars.
//

import SwiftUI
import UIKit

// MARK: - Tactile Press Button Style

struct BoloPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed, let haptic {
                    UIImpactFeedbackGenerator(style: haptic).impactOccurred()
                }
            }
    }
}

// MARK: - Staggered Entrance

private struct StaggeredEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: (isVisible || reduceMotion) ? 0 : 12)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    let delay = Double(min(index, 8)) * 0.035
                    withAnimation(AppMotion.gentle.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    func staggeredEntrance(index: Int = 0) -> some View {
        modifier(StaggeredEntranceModifier(index: index))
    }
}

// MARK: - Shimmer Skeleton Loading

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.32),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geo.size.width * 1.4)
                        .offset(x: phase * geo.size.width * 1.8)
                    }
                    .mask(content)
                    .onAppear {
                        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                            phase = 1.2
                        }
                    }
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct SkeletonLoadingView: View {
    var showBannerCard: Bool = true
    var rowCount: Int = 5

    var body: some View {
        List {
            if showBannerCard {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.22))
                            .frame(width: 210, height: 18)

                        HStack(spacing: 18) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 96, height: 28)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 96, height: 28)
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shimmering()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(0..<rowCount, id: \.self) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.secondary.opacity(0.22))
                                .frame(width: 130, height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 84, height: 10)
                        }

                        Spacer()

                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 64, height: 16)
                    }
                    .padding(.vertical, 6)
                    .shimmering()
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .transition(.opacity)
    }
}

// MARK: - User Avatar Badge

struct UserAvatarBadge: View {
    let name: String
    var size: CGFloat = 42
    var ringColor: Color? = nil

    private var baseColor: Color {
        AppTheme.avatarColor(for: name)
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [baseColor.opacity(0.22), baseColor.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(baseColor)
            }
            .overlay {
                if let ringColor {
                    Circle()
                        .strokeBorder(ringColor.opacity(0.5), lineWidth: 2)
                }
            }
    }
}

// MARK: - Tinted Summary Card Surface

extension View {
    func tintedCardSurface(tint: Color, cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Color(.secondarySystemGroupedBackground), in: shape)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: shape
            )
            .overlay(
                shape.strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}
