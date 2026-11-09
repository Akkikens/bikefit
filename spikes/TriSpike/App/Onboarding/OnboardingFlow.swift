import SwiftUI
import UIKit

/// First launch onboarding: eight short screens, each with a plain reason for asking.
/// Reads and writes `UserSetup.shared` live, so quitting mid flow loses nothing.
///
/// Steps: 0 Welcome, 1 How it works, 2 Safety note, 3 Your race, 4 About you,
/// 5 Connect your devices, 6 Your fitness numbers, 7 Your plan.
struct OnboardingFlow: View {
    var initialStep: Int = 0
    var onFinish: () -> Void

    @ObservedObject private var setup = UserSetup.shared
    @State private var step: Int
    @State private var goingForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let stepCount = 8
    private static let safetyStep = 2
    private static let lastStep = stepCount - 1
    /// Steps where the defaults are fine, so a Skip is offered.
    private static let skippable: Set<Int> = [1, 4, 5, 6]
    private static let stepNames = ["Welcome", "How it works", "Safety note", "Your race", "Experience and time", "Your devices", "Effort numbers", "Your plan"]

    init(initialStep: Int = 0, onFinish: @escaping () -> Void) {
        self.initialStep = initialStep
        self.onFinish = onFinish
        _step = State(initialValue: min(max(initialStep, 0), Self.stepCount - 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                stepContent
                    .padding(.horizontal, BL.Space.gutter)
                    .padding(.bottom, BL.Space.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)))
        }
        .background(BL.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .onChange(of: step) { _, _ in
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    // MARK: Steps

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: OnboardingWelcomeStep()
        case 1: OnboardingHowItWorksStep()
        case 2: OnboardingSafetyStep(setup: setup)
        case 3: OnboardingRaceStep(setup: setup)
        case 4: OnboardingAboutYouStep(setup: setup)
        case 5: OnboardingDevicesStep(setup: setup)
        case 6: OnboardingNumbersStep(setup: setup)
        default: OnboardingPlanStep(setup: setup)
        }
    }

    // MARK: Top bar: progress and Skip

    private var topBar: some View {
        VStack(spacing: BL.Space.xs) {
            HStack(spacing: 4) {
                ForEach(0..<Self.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? BL.accent : BL.textSecondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of \(Self.stepCount), \(Self.stepNames[min(step, Self.stepCount - 1)])")

            HStack {
                Text("Step \(step + 1) of \(Self.stepCount), \(Self.stepNames[min(step, Self.stepCount - 1)])")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BL.textSecondary)
                    .accessibilityHidden(true)
                Spacer()
                if Self.skippable.contains(step) {
                    Button("Skip") { go(to: step + 1) }
                        .font(.body)
                        .contentShape(Rectangle())
                        .foregroundStyle(BL.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Keeps the answers shown and moves on")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, BL.Space.gutter)
        .padding(.top, BL.Space.s)
    }

    // MARK: Bottom bar: Back and the primary action

    private var bottomBar: some View {
        HStack(spacing: BL.Space.m) {
            if step > 0 {
                Button { go(to: step - 1) } label: {
                    Text("Back").lineLimit(1).minimumScaleFactor(0.7)
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: 120)
            }
            Button(action: primaryAction) {
                Text(primaryTitle).lineLimit(2).multilineTextAlignment(.center)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, BL.Space.gutter)
        .padding(.top, BL.Space.m)
        .padding(.bottom, BL.Space.s)
        .background(BL.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider().overlay(BL.separator) }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Get started"
        case Self.safetyStep: return setup.data.acknowledged ? "Next" : "I understand"
        case Self.lastStep: return setup.data.acknowledged ? "Start training" : "Read the safety note"
        default: return "Next"
        }
    }

    private func primaryAction() {
        switch step {
        case Self.safetyStep:
            setup.data.acknowledged = true
            go(to: step + 1)
        case Self.lastStep:
            if setup.data.acknowledged {
                setup.data.hasOnboarded = true
                onFinish()
            } else {
                go(to: Self.safetyStep)
            }
        default:
            go(to: step + 1)
        }
    }

    private func go(to target: Int) {
        let clamped = min(max(target, 0), Self.lastStep)
        guard clamped != step else { return }
        goingForward = clamped > step
        withAnimation(Motion(reduce: reduceMotion).animation(.easeInOut(duration: 0.25))) {
            step = clamped
        }
    }
}
