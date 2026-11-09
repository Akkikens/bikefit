import SwiftUI

struct SessionDetailView: View {
    var session: Session
    @Binding var playerSession: Session?
    /// Decides between the Apple Watch card and the "how you will follow this" card.
    @ObservedObject private var setup = UserSetup.shared
    @ScaledMetric(relativeTo: .body) private var profileHeight: CGFloat = 120

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                VStack(alignment: .leading, spacing: BL.Space.s) {
                    SportChip(sport: session.sport, second: session.brickSecond)
                    Text(session.name).font(BLFont.sessionName).foregroundStyle(BL.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let idea = session.idea {
                        CompactJargon(term: idea, label: session.ideaLabel, font: BLFont.meta, ink: BL.textPrimary, textHeight: 20)
                    }
                    phaseLine
                    Text(session.purpose).font(BLFont.purpose).foregroundStyle(BL.textPrimary).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let feel = session.feel {
                        Label("How it should feel: \(feel.lowercasedFirst)", systemImage: "gauge.with.dots.needle.33percent")
                            .font(BLFont.meta)
                            .foregroundStyle(BL.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: BL.Space.l) {
                    ProfileView(steps: session.steps, mode: .structure, height: profileHeight, ruler: true, showRepeats: true)
                    ProfileLegend(steps: session.steps, explainsScale: true)
                    ReadoutGrid(items: readouts, maxColumns: 2)
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Steps", trailing: "\(numberedStepCount) steps")
                    VStack(spacing: 0) {
                        ForEach(Array(groupedRows.enumerated()), id: \.offset) { i, row in
                            switch row {
                            case .single(let n, let step):
                                StepRow(number: n, step: step)
                            case .repeatSet(let n, let count, let work, let rest):
                                // The bracket spans only the repeated rows, in the same hairline the Profile uses,
                                // and starts below the count so it never touches the label.
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Repeat \(count) times").font(BLFont.label).foregroundStyle(BL.textSecondary)
                                        .padding(.top, 10).padding(.leading, 12)
                                    VStack(spacing: 0) {
                                        StepRow(number: n, step: work, indented: true)
                                        if let rest { StepRow(number: n + 1, step: rest, indented: true) }
                                    }
                                    .overlay(alignment: .leading) {
                                        Rectangle().fill(BL.textSecondary).frame(width: 0.5).padding(.vertical, 8)
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            if i < groupedRows.count - 1 { Divider().overlay(BL.separator) }
                        }
                    }
                    .card()
                }

                if setup.canSendToWatch {
                    WatchCard(line: session.watchLine)
                } else {
                    FollowCard(tracker: setup.followDevice)
                }

                VStack(spacing: BL.Space.m) {
                    Button { playerSession = session } label: { Label("Start on phone", systemImage: "iphone") }
                        .buttonStyle(PrimaryButtonStyle())
                    if session.sport == .swim && session.isOpenWater {
                        Button { } label: { Label("Pool version", systemImage: "figure.pool.swim") }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            .padding(.horizontal, BL.Space.gutter)
            .padding(.vertical, BL.Space.l)
        }
        .background(BL.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Move", systemImage: "calendar") {}
                    Button("Mark done", systemImage: "checkmark.circle") {}
                    Button("Skip", systemImage: "minus.circle", role: .destructive) {}
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("More") }
            }
        }
    }

    /// Where this session sits in the plan, with the phase name explained.
    private var phaseLine: some View {
        HStack(spacing: BL.Space.s) {
            CompactJargon(term: Demo.currentPhase.glossaryTerm, font: BLFont.meta, ink: BL.textSecondary, textHeight: 20)
            Text(Demo.weekLabel).font(BLFont.meta).foregroundStyle(BL.textSecondary)
            Spacer(minLength: 0)
        }
    }

    /// Distance first for swims, then time, target and an estimated load.
    private var readouts: [Readout] {
        var items: [Readout] = []
        if session.showsDistance, let m = session.totalMeters {
            items.append(Readout(label: "distance", value: "\(m)", unit: "m"))
        }
        items.append(Readout(label: "duration", value: "\(session.minutes)", unit: "min"))
        items.append(Readout(label: session.targetLabel, value: session.headlineTarget?.value ?? "easy", unit: session.headlineTarget?.unit ?? "", ink: session.sport.ink, estimated: session.targetsEstimated))
        items.append(Readout(label: session.state == .done ? "Training load" : "Planned load", value: "\(session.loadPoints)", unit: "points", term: .load, estimated: session.loadEstimated))
        return items
    }

    enum Row { case single(Int, PlanStep), repeatSet(Int, Int, PlanStep, PlanStep?) }

    /// The highest row number the list prints, so the header always matches the numbering the athlete reads.
    private var numberedStepCount: Int {
        groupedRows.reduce(0) { acc, row in
            switch row {
            case .single: return acc + 1
            case .repeatSet(_, _, _, let rest): return acc + (rest == nil ? 1 : 2)
            }
        }
    }

    /// Collapses repeat groups into one "repeat 8 times" row pair, numbering steps as an athlete reads them.
    private var groupedRows: [Row] {
        var rows: [Row] = []
        var seen = Set<Int>()
        var n = 1
        for step in session.steps {
            if let g = step.group {
                if seen.contains(g) { continue }
                seen.insert(g)
                let members = session.steps.filter { $0.group == g }
                let work = members.first { $0.kind == .work } ?? members[0]
                let rest = members.first { $0.kind == .recovery }
                rows.append(.repeatSet(n, step.repeatCount ?? 1, work, rest))
                n += rest == nil ? 1 : 2
            } else {
                rows.append(.single(n, step))
                n += 1
            }
        }
        return rows
    }
}

private extension String {
    /// "Easy. You could chat." becomes "easy. You could chat." so it reads after a colon.
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}
