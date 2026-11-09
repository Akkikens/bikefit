import SwiftUI

/// Step 7: a plan preview computed locally from the answers. The "Start training" button lives in the flow's bottom bar.
struct OnboardingPlanStep: View {
    @ObservedObject var setup: UserSetup

    private var data: SetupData { setup.data }
    private var model: EngineModel { OBPlan.model(data) }
    private var weeks: Int { model.totalWeeks }
    private var sessions: Int { model.sessionsPerWeek }
    private var hoursText: String {
        let h = model.hoursPerWeek
        return h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h)
    }
    private var phases: [OBPhase] { OBPlan.phases(for: data) }
    private var firstWeek: [OBFirstWeekItem] { OBPlan.firstWeek(data) }

    var body: some View {
        OBPage(title: "Your plan",
               why: "Built on this phone from your answers. It can shift a little as you train.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                summary
                phaseSection
                alsoInPlan
                firstWeekSection
                trackerNote
            }
        }
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            Text(headline)
                .font(.headline)
                .foregroundStyle(BL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ReadoutGrid(items: [
                Readout(label: "Length", value: "\(weeks)", unit: "weeks"),
                Readout(label: "Hours", value: hoursText, unit: "per week"),
                Readout(label: "Sessions", value: "\(sessions)", unit: "per week")
            ])
            if let note = leadTimeNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var headline: String {
        if data.noRaceYet { return "A \(weeks) week start, with no race date yet" }
        let name = data.raceName.trimmingCharacters(in: .whitespaces)
        let race = name.isEmpty ? data.raceChoice.title : name
        let date = data.raceDate.formatted(.dateTime.day().month(.wide).year())
        return "\(race), \(date)"
    }

    /// Honest notes from the engine: why the plan differs from what was asked, and what it changed on the way.
    private var leadTimeNote: String? {
        guard !data.noRaceYet else { return model.warnings.first }
        var lines: [String] = []
        if let problem = model.problem { lines.append(problem) }
        let w = OBPlan.weeksUntil(data.raceDate)
        if model.problem == nil, w > weeks {
            lines.append("Your race is \(w) weeks away. The plan covers the last \(weeks) weeks. Until then, easy base weeks keep you moving.")
        }
        lines.append(contentsOf: model.warnings.prefix(2))
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    // MARK: Phases

    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "The shape of your plan")
            VStack(alignment: .leading, spacing: BL.Space.l) {
                phaseBar
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    ForEach(phases) { phase in
                        HStack(alignment: .top, spacing: BL.Space.m) {
                            RoundedRectangle(cornerRadius: BL.Radius.block, style: .continuous)
                                .fill(BL.accent.opacity(phase.opacity))
                                .overlay(RoundedRectangle(cornerRadius: BL.Radius.block, style: .continuous).strokeBorder(BL.textSecondary, lineWidth: 1))
                                .frame(width: 14, height: 14)
                                .padding(.top, 5)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 0) {
                                CompactJargon(term: phase.term,
                                              label: "\(phase.name), \(OBFormat.plural(phase.weeks, "week", "weeks"))",
                                              font: .body.weight(.semibold), ink: BL.textPrimary, textHeight: 22)
                                    .fixedSize()
                                Text(phase.blurb)
                                    .font(.subheadline)
                                    .foregroundStyle(BL.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var phaseBar: some View {
        let items = phases
        let total = CGFloat(max(1, items.reduce(0) { $0 + $1.weeks }))
        let summaryText = items.map { "\($0.name) \(OBFormat.plural($0.weeks, "week", "weeks"))" }.joined(separator: ", ")
        return GeometryReader { geo in
            let gap: CGFloat = 2
            let usable = max(0, geo.size.width - gap * CGFloat(max(0, items.count - 1)))
            HStack(spacing: gap) {
                ForEach(items) { item in
                    RoundedRectangle(cornerRadius: BL.Radius.block, style: .continuous)
                        .fill(BL.accent.opacity(item.opacity))
                        .overlay(RoundedRectangle(cornerRadius: BL.Radius.block, style: .continuous).strokeBorder(BL.textSecondary, lineWidth: 1))
                        .frame(width: usable * CGFloat(item.weeks) / total)
                }
            }
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan phases, in order: \(summaryText)")
    }

    // MARK: Lighter weeks and tests

    private var alsoInPlan: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Also in your plan")
            VStack(alignment: .leading, spacing: BL.Space.s) {
                VStack(alignment: .leading, spacing: 0) {
                    JargonText(term: .recoveryWeek, label: "Easier weeks", font: .body.weight(.semibold))
                    Text("Every fourth week is lighter, so your body can catch up.")
                        .font(.subheadline).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().overlay(BL.separator)
                VStack(alignment: .leading, spacing: 0) {
                    JargonText(term: .testWeek, label: "Test weeks", font: .body.weight(.semibold))
                    Text(data.useEstimates
                         ? "Short tests in your first weeks replace the estimates with your own numbers."
                         : "Short tests every 6 weeks or so keep your numbers honest.")
                        .font(.subheadline).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: First week

    private var firstWeekSection: some View {
        let items = firstWeek
        let total = items.reduce(0) { $0 + $1.minutes }
        return VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Your first week")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                Text(firstWeekNote)
                    .font(.subheadline)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: BL.Space.m) {
                        Text(OBDays.short(item.day))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BL.textSecondary)
                            .frame(minWidth: 40, alignment: .leading)
                        Image(systemName: item.sport.symbol())
                            .foregroundStyle(item.sport.ink)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(item.name)
                            .font(.body)
                            .foregroundStyle(BL.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: BL.Space.s)
                        Text("\(item.minutes) min")
                            .font(BLFont.rowNumeral)
                            .foregroundStyle(BL.textPrimary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(OBDays.full(item.day)), \(item.name), \(item.minutes) minutes")
                }
                if !items.isEmpty {
                    Divider().overlay(BL.separator)
                    HStack {
                        Text("About").font(.subheadline).foregroundStyle(BL.textSecondary)
                        Spacer()
                        Text(OBFormat.duration(minutes: total))
                            .font(BLFont.rowNumeral)
                            .foregroundStyle(BL.textPrimary)
                        Text("this week").font(.subheadline).foregroundStyle(BL.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var firstWeekNote: String {
        var note = model.firstWeekIsPartial
            ? "Your first week starts part way through, so it is short."
            : "A first look at a normal week of your plan."
        if firstWeek.contains(where: \.isTest) { note += " It includes a short test that sets your own paces." }
        return note
    }

    // MARK: How sessions reach you

    private var deviceLine: String {
        var line = data.canSendToWatch
            ? "Each session can go to your watch, or you can follow it on your phone."
            : "You follow each session on your phone with voice cues."
        if data.hasHRVSource {
            line += " After 14 nights of sleep and heart data, a hard session can be eased when you are below your usual range. You can always keep the planned one."
        }
        if data.hasRecoverySource, !data.hasHRVSource {
            line += " Sleep and resting heart rate are shown as notes. Your plan does not change from them."
        }
        return line
    }

    private var trackerNote: some View {
        HStack(alignment: .top, spacing: BL.Space.m) {
            Image(systemName: data.followDevice.symbol)
                .font(.title3)
                .foregroundStyle(BL.textPrimary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BL.Space.xs) {
                Text(data.orderedDevices.map(\.title).joined(separator: ", ")).font(.subheadline.weight(.semibold)).foregroundStyle(BL.textPrimary)
                Text(deviceLine).font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
