import SwiftUI

struct SessionDetailView: View {
    var session: Session
    @Binding var playerSession: Session?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                VStack(alignment: .leading, spacing: BL.Space.s) {
                    SportChip(sport: session.sport, second: session.brickSecond)
                    Text(session.name).font(.largeTitle.weight(.semibold)).foregroundStyle(BL.textPrimary)
                    Text("Build phase, week \(Demo.currentWeek)").font(BLFont.meta).foregroundStyle(BL.textSecondary)
                    Text(session.purpose).font(BLFont.purpose).foregroundStyle(BL.textPrimary).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: BL.Space.l) {
                    ProfileView(steps: session.steps, mode: .structure, height: 120, ruler: true, showRepeats: true)
                    ReadoutGrid(items: [
                        Readout(label: "duration", value: "\(session.minutes)", unit: "min"),
                        Readout(label: "target", value: session.headlineTarget?.value ?? "easy", unit: session.headlineTarget?.unit ?? "", ink: session.sport.ink),
                        Readout(label: "load", value: "\(session.minutes * 3 / 2)"),
                    ])
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Steps", trailing: "\(session.steps.count)")
                    VStack(spacing: 0) {
                        ForEach(Array(groupedRows.enumerated()), id: \.offset) { i, row in
                            switch row {
                            case .single(let n, let step):
                                StepRow(number: n, step: step)
                            case .repeatSet(let n, let count, let work, let rest):
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(count)x").font(BLFont.label).foregroundStyle(BL.textSecondary).padding(.top, 8)
                                    StepRow(number: n, step: work, indented: true)
                                    if let rest { StepRow(number: n + 1, step: rest, indented: true) }
                                }
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(BL.separator).frame(width: 1).padding(.vertical, 10)
                                }
                            }
                            if i < groupedRows.count - 1 { Divider().overlay(BL.separator) }
                        }
                    }
                    .card()
                }

                WatchCard(line: session.watchLine)

                VStack(spacing: BL.Space.m) {
                    Button { playerSession = session } label: { Label("Start on phone", systemImage: "iphone") }
                        .buttonStyle(PrimaryButtonStyle())
                    if session.sport == .swim {
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

    enum Row { case single(Int, PlanStep), repeatSet(Int, Int, PlanStep, PlanStep?) }

    /// Collapses repeat groups into one "8x" row pair, numbering steps as an athlete reads them.
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
