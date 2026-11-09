import SwiftUI
import UIKit

/// Step 7: the three numbers TriSpike uses to set effort. Estimates by default, optional entry for people who know theirs.
struct OnboardingNumbersStep: View {
    @ObservedObject var setup: UserSetup

    @State private var swimText = ""
    @State private var bikeText = ""
    @State private var runText = ""
    @State private var loaded = false
    @FocusState private var focused: Field?

    private enum Field { case swim, bike, run }

    private static let swimRange: ClosedRange<Double> = 50...240    // seconds per 100 m
    private static let runRange: ClosedRange<Double> = 150...600    // seconds per km

    var body: some View {
        OBPage(title: "How hard should training feel?",
               why: "TriSpike sets your paces from three short tests. You can start with estimates and test later.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                VStack(alignment: .leading, spacing: BL.Space.s) {
                    OBToggleRow(title: "Use estimates for now (recommended)",
                                detail: "We will schedule the tests in your first weeks.",
                                isOn: $setup.data.useEstimates)
                    JargonText(term: .estimated, label: "What is an estimate?", font: .subheadline, ink: BL.textSecondary)
                }
                .card()

                if setup.data.useEstimates {
                    estimatesCard
                } else {
                    VStack(spacing: BL.Space.cardGap) {
                        swimRow
                        bikeRow
                        runRow
                    }
                }

                Text(setup.data.useEstimates
                     ? "Already know your numbers? Turn off the switch above to enter them."
                     : "Leave any box empty and that one stays an estimate.")
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: loadOnce)
        .onChange(of: swimText) { _, text in
            setup.data.cssSecondsPer100 = OBFormat.parseMMSS(text, range: Self.swimRange)
        }
        .onChange(of: bikeText) { _, text in
            setup.data.ftpWatts = OBFormat.parseWatts(text)
        }
        .onChange(of: runText) { _, text in
            setup.data.thresholdPaceSecondsPerKm = OBFormat.parseMMSS(text, range: Self.runRange)
        }
    }

    // MARK: Estimates summary

    /// With estimates on there is nothing to enter, so the three tests sit behind one disclosure.
    private var estimatesCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            Text("Your swim, bike and run start on estimated paces. Short tests in your first weeks replace them with your own numbers.")
                .font(.subheadline)
                .foregroundStyle(BL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("See the three tests") {
                VStack(alignment: .leading, spacing: BL.Space.l) {
                    testSummary(.swim, term: .css, label: "Swim speed (CSS)",
                                text: "Swim 400 m as fast as you can, rest 5 to 10 minutes, then swim 200 m as fast as you can.")
                    testSummary(.bike, term: .ftp, label: "Bike power (FTP)",
                                text: setup.data.hasPowerMeter
                                    ? "Ride 20 minutes as hard as you can keep steady."
                                    : "Needs a power meter. You said you do not have one, so bike sessions use how hard it feels.")
                    testSummary(.run, term: .threshold, label: "Run pace (threshold)",
                                text: "Run 30 minutes as hard as you can keep steady.")
                }
                .padding(.top, BL.Space.m)
            }
            .font(.body.weight(.semibold))
            .tint(BL.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func testSummary(_ sport: Sport, term: Term, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: BL.Space.m) {
            Image(systemName: sport.symbol())
                .font(.title3)
                .foregroundStyle(sport.ink)
                .frame(width: 28, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                JargonText(term: term, label: label, font: .body.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Rows

    private var swimRow: some View {
        row(sport: .swim, term: .css, label: "Swim speed (CSS)",
            detail: "Your steady hard pace for every 100 m. Found with a 400 m swim and a 200 m swim.") {
            entryField(prompt: "1:45", text: $swimText, field: .swim, unit: "per 100 m",
                       keyboard: .numbersAndPunctuation,
                       problem: invalid(swimText, OBFormat.parseMMSS(swimText, range: Self.swimRange) == nil)
                           ? "Use minutes and seconds, like 1:45." : nil)
        }
    }

    @ViewBuilder private var bikeRow: some View {
        if setup.data.hasPowerMeter {
            row(sport: .bike, term: .ftp, label: "Bike power (FTP)",
                detail: "The hardest power you could hold for about an hour. Found with a 20 minute all out ride.") {
                entryField(prompt: "205", text: $bikeText, field: .bike, unit: "watts",
                           keyboard: .numberPad,
                           problem: invalid(bikeText, OBFormat.parseWatts(bikeText) == nil)
                               ? "Use a whole number of watts, from 50 to 600." : nil)
            }
        } else {
            row(sport: .bike, term: .ftp, label: "Bike power (FTP)",
                detail: "Needs a power meter. You said you do not have one, so bike sessions use how hard it feels.",
                showsField: false) { EmptyView() }
        }
    }

    private var runRow: some View {
        row(sport: .run, term: .threshold, label: "Run pace (threshold)",
            detail: "A hard but steady pace you could hold for about an hour. Found with a 30 minute hard run.") {
            entryField(prompt: "5:30", text: $runText, field: .run, unit: "per km",
                       keyboard: .numbersAndPunctuation,
                       problem: invalid(runText, OBFormat.parseMMSS(runText, range: Self.runRange) == nil)
                           ? "Use minutes and seconds, like 5:30." : nil)
        }
    }

    private func row<F: View>(sport: Sport, term: Term, label: String, detail: String,
                              showsField: Bool = true, @ViewBuilder field: () -> F) -> some View {
        HStack(alignment: .top, spacing: BL.Space.m) {
            Image(systemName: sport.symbol())
                .font(.title2)
                .foregroundStyle(sport.ink)
                .frame(width: 32, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BL.Space.xs) {
                JargonText(term: term, label: label, font: .body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if showsField {
                    if setup.data.useEstimates {
                        JargonText(term: .estimated, label: "Estimated for now", font: .footnote, ink: BL.textSecondary)
                    } else {
                        field()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func entryField(prompt: String, text: Binding<String>, field: Field, unit: String,
                            keyboard: UIKeyboardType, problem: String?) -> some View {
        VStack(alignment: .leading, spacing: BL.Space.xs) {
            HStack(spacing: BL.Space.s) {
                TextField(prompt, text: text)
                    .font(BLFont.rowNumeral)
                    .keyboardType(keyboard)
                    .focused($focused, equals: field)
                    .multilineTextAlignment(.center)
                    .frame(width: 96, height: 44)
                    .background(BL.background, in: RoundedRectangle(cornerRadius: BL.Radius.chip, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: BL.Radius.chip, style: .continuous).strokeBorder(BL.separator, lineWidth: 1))
                Text(unit).font(BLFont.unit).foregroundStyle(BL.textSecondary)
            }
            if let problem {
                Text(problem).font(.footnote).foregroundStyle(BL.warning)
            }
        }
    }

    private func invalid(_ text: String, _ failed: Bool) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && failed
    }

    // MARK: Persistence

    /// Fill the boxes from saved numbers the first time the step appears.
    private func loadOnce() {
        guard !loaded else { return }
        loaded = true
        let d = setup.data
        if let css = d.cssSecondsPer100 { swimText = OBFormat.mmss(css) }
        if let ftp = d.ftpWatts { bikeText = String(ftp) }
        if let pace = d.thresholdPaceSecondsPerKm { runText = OBFormat.mmss(pace) }
    }
}
