import SwiftUI

/// The Contour signature (spec section 5): a session drawn as a course profile.
/// Width is duration, height is intensity, color is sport. Never any text inside blocks.
struct ProfileView: View {
    enum Mode: Equatable {
        /// Session structure: work solid, warm and cool at 0.55 with a full fill edge, recovery hollow.
        case structure
        /// Week states: planned hollow, done solid, skipped hollow with a slash.
        case state(SessionState)
        /// Player: completed solid, remaining at 0.35, current block taller, playhead at `progress` seconds.
        case player(progress: TimeInterval)
    }

    var steps: [PlanStep]
    var mode: Mode = .structure
    var height: CGFloat = 56
    var ruler: Bool = false
    var onBlack: Bool = false
    var showRepeats: Bool = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Canvas { ctx, size in
            draw(&ctx, size: size)
        }
        .frame(height: height + (ruler ? 18 : 0) + (showRepeats ? 14 : 0))
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    private var total: TimeInterval { max(1, steps.reduce(0) { $0 + $1.seconds }) }

    private func fill(_ s: Sport) -> Color {
        if onBlack {
            switch s { case .swim: return BL.Player.swimFill; case .bike: return BL.Player.bikeFill; case .run: return BL.Player.runFill }
        }
        switch s { case .swim: return BL.swimFill; case .bike: return BL.bikeFill; case .run: return BL.runFill }
    }

    private func blockHeight(_ level: Int) -> CGFloat {
        let table: [CGFloat] = [0.30, 0.475, 0.65, 0.825, 1.0]
        return height * table[max(0, min(4, level - 1))]
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let top: CGFloat = showRepeats ? 14 : 0
        let baseline = top + height
        let gap: CGFloat = 1.5
        let available = size.width - gap * CGFloat(max(0, steps.count - 1))
        // Proportional widths with a 3 pt floor, renormalized so the row still fits.
        var widths = steps.map { max(3, available * $0.seconds / total) }
        let overflow = widths.reduce(0, +) - available
        if overflow > 0 {
            let flexible = widths.enumerated().filter { $0.element > 3 }.map(\.offset)
            let flexTotal = flexible.reduce(0) { $0 + widths[$1] }
            for i in flexible { widths[i] -= overflow * widths[i] / max(1, flexTotal) }
        }

        // Player bookkeeping.
        var playerIndex = -1
        var progress: TimeInterval = 0
        if case .player(let p) = mode {
            progress = p
            var acc: TimeInterval = 0
            for (i, s) in steps.enumerated() {
                if p < acc + s.seconds { playerIndex = i; break }
                acc += s.seconds
            }
            if playerIndex == -1 { playerIndex = steps.count }
        }

        var x: CGFloat = 0
        var groupSpans: [Int: (start: CGFloat, end: CGFloat, count: Int)] = [:]
        for (i, step) in steps.enumerated() {
            let w = widths[i]
            var h = blockHeight(step.level)
            if i == playerIndex { h = min(height + 2, h + 2) }
            let rect = CGRect(x: x, y: baseline - h, width: w, height: h)
            let path = Path(roundedRect: rect, cornerRadius: BL.Radius.block, style: .continuous)
            let color = fill(step.sport)

            switch mode {
            case .structure:
                drawStructure(&ctx, step: step, path: path, rect: rect, color: color)
            case .state(let state):
                switch state {
                case .done:
                    ctx.fill(path, with: .color(color))
                case .planned:
                    ctx.stroke(path.insetBy(0.75), with: .color(color), lineWidth: 1.5)
                case .skipped:
                    ctx.stroke(path.insetBy(0.75), with: .color(color), lineWidth: 1.5)
                }
            case .player:
                if i < playerIndex {
                    ctx.fill(path, with: .color(color))
                } else if i == playerIndex {
                    drawStructure(&ctx, step: step, path: path, rect: rect, color: color)
                } else if contrast == .increased {
                    ctx.stroke(path.insetBy(0.75), with: .color(color), lineWidth: 1.5)
                } else {
                    var faded = ctx
                    faded.opacity = 0.35
                    drawStructure(&faded, step: step, path: path, rect: rect, color: color)
                }
            }

            if let g = step.group {
                let span = groupSpans[g] ?? (x, x + w, step.repeatCount ?? 0)
                groupSpans[g] = (span.start, x + w, max(span.count, step.repeatCount ?? 0))
            }
            x += w + gap
        }

        // Skipped: one corner to corner slash across the whole profile, full opacity.
        if case .state(.skipped) = mode, let first = steps.first {
            var slash = Path()
            slash.move(to: CGPoint(x: 0, y: baseline))
            slash.addLine(to: CGPoint(x: size.width, y: top))
            ctx.stroke(slash, with: .color(fill(first.sport)), lineWidth: 1.5)
        }

        // Baseline.
        var base = Path()
        base.move(to: CGPoint(x: 0, y: baseline + 0.25))
        base.addLine(to: CGPoint(x: size.width, y: baseline + 0.25))
        ctx.stroke(base, with: .color(onBlack ? BL.Player.textSecondary.opacity(0.6) : BL.separator), lineWidth: 0.5)

        // Repeat brackets with small caps count.
        if showRepeats {
            for (_, span) in groupSpans where span.count > 1 {
                var b = Path()
                b.move(to: CGPoint(x: span.start, y: 10))
                b.addLine(to: CGPoint(x: span.start, y: 6))
                b.addLine(to: CGPoint(x: span.end, y: 6))
                b.addLine(to: CGPoint(x: span.end, y: 10))
                let ink = onBlack ? BL.Player.textSecondary : BL.textSecondary
                ctx.stroke(b, with: .color(ink), lineWidth: 0.5)
                ctx.draw(Text("\(span.count)x").font(BLFont.label).foregroundStyle(ink),
                         at: CGPoint(x: (span.start + span.end) / 2, y: 0), anchor: .top)
            }
        }

        // Time ruler: ticks every 5 minutes, labels every 15.
        if ruler {
            let ink = onBlack ? BL.Player.textSecondary : BL.textSecondary
            let minutes = Int(total / 60)
            for m in stride(from: 0, through: minutes, by: 5) {
                let tx = size.width * CGFloat(Double(m * 60) / total)
                let major = m % 15 == 0
                var t = Path()
                t.move(to: CGPoint(x: tx, y: baseline + 1))
                t.addLine(to: CGPoint(x: tx, y: baseline + (major ? 8 : 4)))
                ctx.stroke(t, with: .color(ink), lineWidth: 0.5)
                if major, m > 0, tx < size.width - 16 {
                    ctx.draw(Text("\(m)").font(.caption2.monospacedDigit()).foregroundStyle(ink),
                             at: CGPoint(x: tx, y: baseline + 9), anchor: .top)
                }
            }
        }

        // Player playhead.
        if case .player = mode {
            let px = min(size.width, size.width * CGFloat(progress / total))
            var line = Path()
            line.move(to: CGPoint(x: px, y: top - 2))
            line.addLine(to: CGPoint(x: px, y: baseline))
            ctx.stroke(line, with: .color(BL.Player.accent), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: px - 3, y: top - 6, width: 6, height: 6)), with: .color(BL.Player.accent))
        }
    }

    private func drawStructure(_ ctx: inout GraphicsContext, step: PlanStep, path: Path, rect: CGRect, color: Color) {
        switch step.kind {
        case .work:
            ctx.fill(path, with: .color(color))
        case .warm, .cool:
            ctx.fill(path, with: .color(color.opacity(0.55)))
            ctx.stroke(path.insetBy(0.5), with: .color(color), lineWidth: 1)
        case .recovery:
            ctx.stroke(path.insetBy(0.75), with: .color(color), lineWidth: 1.5)
        }
    }

    private var accessibilitySummary: String {
        let minutes = Int((total / 60).rounded())
        let sports = Array(NSOrderedSet(array: steps.map(\.sport.word))) as? [String] ?? []
        let reps = steps.compactMap(\.repeatCount).max()
        var parts = ["\(sports.joined(separator: " then ")), \(minutes) minutes"]
        if let reps, reps > 1, let work = steps.first(where: { $0.kind == .work }) {
            parts.append("\(reps) by \(work.distance ?? "\(Int(work.seconds / 60)) minutes") at \(work.target ?? "target")")
        }
        if case .state(let s) = mode { parts.append(s == .done ? "done" : s == .skipped ? "skipped" : "planned") }
        return parts.joined(separator: ", ")
    }
}

private extension Path {
    func insetBy(_ d: CGFloat) -> Path {
        let r = boundingRect.insetBy(dx: d, dy: d)
        guard r.width > 0, r.height > 0 else { return self }
        return Path(roundedRect: r, cornerRadius: BL.Radius.block, style: .continuous)
    }
}
