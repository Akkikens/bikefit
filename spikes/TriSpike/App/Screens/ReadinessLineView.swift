import SwiftUI

/// The readiness line on Today: how last night compares with the athlete's usual, in plain words. It never tells the
/// athlete to rest and never names a cause. When a session was eased, one tap puts the planned one back.
struct ReadinessLineView: View {
    var model: ReadinessLineModel
    var onKeep: () -> Void

    private var ink: Color {
        switch model.tone {
        case .neutral: BL.textSecondary
        case .steady: BL.success
        case .notice: BL.warning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: BL.Space.s) {
                Image(systemName: model.symbol).foregroundStyle(ink).accessibilityHidden(true)
                Text("Readiness").font(BLFont.label).foregroundStyle(BL.textSecondary)
            }
            Text(model.headline)
                .font(.headline)
                .foregroundStyle(BL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = model.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.mentionsHRV {
                CompactJargon(term: .hrv, label: "What is heart rate variability?", font: .subheadline, ink: BL.textSecondary, textHeight: 20)
            }
            if model.offersKeep {
                Button(action: onKeep) {
                    Label(ReadinessPlainCopy.keepButtonTitle, systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Puts your original session back on today")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .contain)
    }
}
