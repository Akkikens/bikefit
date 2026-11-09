import SwiftUI

/// Step 2: the safety note (annex K string 1, verbatim). The "I understand" button lives in the flow's bottom bar.
struct OnboardingSafetyStep: View {
    @ObservedObject var setup: UserSetup

    /// Annex K, Safety.strings entry 1. Do not rephrase without updating the annex and the scan test.
    static let acknowledgement = "TriSpike builds training plans for sport. It is not medical advice. Check with a doctor before starting a new training program, especially if you have a heart condition, are pregnant, or are returning from injury. Stop training and seek help if you feel chest pain, dizziness or shortness of breath."

    /// `acknowledgement` split at its sentences into three short lines. Joined with a space they are the annex string again.
    static var lines: [String] {
        let sentences = acknowledgement.components(separatedBy: ". ").enumerated().map { i, part in
            part.hasSuffix(".") ? part : part + "."
        }
        guard sentences.count >= 4 else { return [acknowledgement] }
        return [sentences[0] + " " + sentences[1], sentences[2], sentences[3]]
    }

    var body: some View {
        OBPage(title: "A note on safety",
               why: "We say this once, up front, because training should leave you better off.") {
            VStack(alignment: .leading, spacing: BL.Space.l) {
                HStack(alignment: .top, spacing: BL.Space.m) {
                    Image(systemName: "heart.text.square")
                        .font(.title2)
                        .foregroundStyle(BL.textPrimary)
                        .accessibilityHidden(true)
                    // The same words as the annex string, one sentence group per line so it reads in short pieces.
                    VStack(alignment: .leading, spacing: BL.Space.m) {
                        ForEach(Self.lines, id: \.self) { line in
                            Text(line)
                                .font(.body)
                                .foregroundStyle(BL.textPrimary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .card()

                if setup.data.acknowledged {
                    Label("You have confirmed this.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BL.success)
                } else {
                    Text("Tap I understand to continue.")
                        .font(.subheadline)
                        .foregroundStyle(BL.textSecondary)
                }
            }
        }
    }
}
