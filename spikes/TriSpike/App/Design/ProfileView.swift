import SwiftUI

/// The Contour signature (spec section 5): a session drawn as a course profile.
/// Width is duration, height is intensity, color is sport. Never any text inside blocks.
struct ProfileView: View {
    enum Mode: Equatable {
        /// Session structure: work solid, warm and cool at 0.55 with a full fill edge, recovery hollow.
        case structure
        /// Week states: planned hollow, done solid, skipped hollow with a slash.
        case state(SessionState)
        /// Player: completed solid, remaining dimmed per sport (see `remainingOpacity`), current block taller,
        /// playhead at `progress` seconds.
        case player(progress: TimeInterval)
    }

    var steps: [PlanStep]
    var mode: Mode = .structure
    var height: CGFloat = 56
    var ruler: Bool = false
    var onBlack: Bool = false
    var showRepeats: Bool = false
    /// Force the compact (one block per repeat set) drawing. Nil means compact when `height` is 28 or less.
    /// Callers whose height scales with Dynamic Type, like the week strip cell, pass true.
    var compact: Bool? = nil

    @Environment(\.colorSchemeContrast) private var contrast
    /// Bands for the repeat bracket and the ruler scale with Dynamic Type so their labels never collide with the blocks.
    @ScaledMetric(relativeTo: .footnote) private var repeatBand: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote) private var rulerBand: CGFloat = 26

    var body: some View {
        Canvas { ctx, size in
            draw(&ctx, size: size)
        }
        .frame(height: height + (ruler ? rulerBand : 0) + (showRepeats ? repeatBand : 0) + headroom)
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Derived geometry

    private var isPlayer: Bool { if case .player = mode { return true } else { return false } }
    /// Room above the tallest block for the playhead cap (2 pt line start plus 6 pt cap).
    private var headroom: CGFloat { isPlayer ? 8 : 0 }

    /// Compact Profiles (height 28 or less, or `compact` set; the week strip) draw one block per repeat set. At that size every rep
    /// would hit the 3 pt floor, a 1.5 pt stroke would fill it solid and planned could not read as hollow.
    private var drawnSteps: [PlanStep] {
        guard compact ?? (height <= 28) else { return steps }
        var out: [PlanStep] = []
        for s in steps {
            if let g = s.group, let last = out.last, last.group == g {
                out[out.count - 1].seconds += s.seconds
                out[out.count - 1].level = max(out[out.count - 1].level, s.level)
                if out[out.count - 1].repeatCount == nil { out[out.count - 1].repeatCount = s.repeatCount }
            } else {
                out.append(s)
            }
        }
        return out
    }

    private var total: TimeInterval { max(1, drawnSteps.reduce(0) { $0 + $1.seconds }) }

    /// Swim rests are gaps, not blocks (spec section 4). They keep their proportional width.
    private func isGap(_ s: PlanStep) -> Bool { s.sport == .swim && s.kind == .recovery }

    /// Smallest drawn width: 3 pt for blocks, a little more for swim rests so the break between reps reads at 56 pt.
    private func floorWidth(_ s: PlanStep) -> CGFloat { isGap(s) ? 4.5 : 3 }

    /// Total meters when every non-recovery step is a swim step that carries a distance, otherwise nil.
    private func meterTotal(_ list: [PlanStep]) -> Int? {
        let counted = list.filter { $0.kind != .recovery }
        guard !counted.isEmpty,
              counted.allSatisfy({ $0.sport == .swim && $0.profileMeters != nil }) else { return nil }
        let sum = counted.reduce(0) { $0 + ($1.profileMeters ?? 0) }
        return sum > 0 ? sum : nil
    }

    private func fill(_ s: Sport) -> Color {
        if onBlack {
            switch s { case .swim: return BL.Player.swimFill; case .bike: return BL.Player.bikeFill; case .run: return BL.Player.runFill }
        }
        switch s { case .swim: return BL.swimFill; case .bike: return BL.bikeFill; case .run: return BL.runFill }
    }

    /// Remaining player blocks on black. Lowest opacity per sport whose composite clears 3:1 (WCAG 1.4.11).
    private func remainingOpacity(_ s: Sport) -> Double {
        switch s { case .run: return 0.45; case .bike: return 0.55; case .swim: return 0.60 }
    }

    private func blockHeight(_ level: Int) -> CGFloat {
        let table: [CGFloat] = [0.30, 0.475, 0.65, 0.825, 1.0]
        return height * table[max(0, min(4, level - 1))]
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let list = drawnSteps
        let total = max(1, list.reduce(0) { $0 + $1.seconds })
        let top: CGFloat = (showRepeats ? repeatBand : 0) + headroom
        let baseline = top + height
        let gap: CGFloat = 1.5
        let available = size.width - gap * CGFloat(max(0, list.count - 1))
        guard available > 0 else { return }

        // Proportional widths with a floor, renormalized so the row still fits.
        let floors = list.map { floorWidth($0) }
        var widths = list.indices.map { max(floors[$0], available * list[$0].seconds / total) }
        let overflow = widths.reduce(0, +) - available
        if overflow > 0 {
            let flexible = widths.indices.filter { widths[$0] > floors[$0] }
            let flexTotal = flexible.reduce(0) { $0 + widths[$1] }
            for i in flexible { widths[i] -= overflow * widths[i] / max(1, flexTotal) }
        }
        // When every block already sits on its floor the row can still overflow: shrink uniformly to keep it in the frame.
        let widthSum = widths.reduce(0, +)
        if widthSum > available, widthSum > 0 {
            let scale = available / widthSum
            widths = widths.map { $0 * scale }
        }

        // Player bookkeeping.
        var playerIndex = -1
        var progress: TimeInterval = 0
        if case .player(let p) = mode {
            progress = p
            var acc: TimeInterval = 0
            for (i, s) in list.enumerated() {
                if p < acc + s.seconds { playerIndex = i; break }
                acc += s.seconds
            }
            if playerIndex == -1 { playerIndex = list.count }
        }

        var x: CGFloat = 0
        var spans: [(start: CGFloat, end: CGFloat)] = []
        var groupSpans: [Int: (start: CGFloat, end: CGFloat, count: Int)] = [:]
        for (i, step) in list.enumerated() {
            let w = widths[i]
            spans.append((x, x + w))

            if let g = step.group {
                let span = groupSpans[g] ?? (x, x + w, step.repeatCount ?? 0)
                groupSpans[g] = (span.start, x + w, max(span.count, step.repeatCount ?? 0))
            }

            // Swim rests are gaps: no block in any mode, but they keep width, extend the bracket and count as progress.
            if isGap(step) {
                x += w + gap
                continue
            }

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
                    faded.opacity = remainingOpacity(step.sport)
                    drawStructure(&faded, step: step, path: path, rect: rect, color: color)
                }
            }
            x += w + gap
        }

        // Skipped: one corner to corner slash across the whole profile, full opacity.
        if case .state(.skipped) = mode, let first = list.first {
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

        // Repeat brackets with small caps count, centered in the (scaled) repeat band.
        if showRepeats {
            for (_, span) in groupSpans where span.count > 1 {
                // Bracket with a gap around the label, so the count never sits on the line.
                let ink = onBlack ? BL.Player.textSecondary : BL.textSecondary
                let label = ctx.resolve(Text("\(span.count) times").font(BLFont.label).foregroundStyle(ink))
                let labelSize = label.measure(in: CGSize(width: 200, height: repeatBand))
                let mid = (span.start + span.end) / 2
                let y: CGFloat = headroom + repeatBand / 2
                let leg: CGFloat = min(5, repeatBand * 0.28)
                let gapHalf = labelSize.width / 2 + 4
                var b = Path()
                b.move(to: CGPoint(x: span.start, y: y + leg))
                b.addLine(to: CGPoint(x: span.start, y: y))
                b.addLine(to: CGPoint(x: max(span.start, mid - gapHalf), y: y))
                b.move(to: CGPoint(x: min(span.end, mid + gapHalf), y: y))
                b.addLine(to: CGPoint(x: span.end, y: y))
                b.addLine(to: CGPoint(x: span.end, y: y + leg))
                ctx.stroke(b, with: .color(ink), lineWidth: 0.5)
                ctx.draw(label, at: CGPoint(x: mid, y: y), anchor: .center)
            }
        }

        // Ruler (spec section 5): distance for swims, time for everything else. Labels never leave the band.
        if ruler {
            let ink = onBlack ? BL.Player.textSecondary : BL.textSecondary
            let meters = meterTotal(list)
            let minutes = Int(total / 60)

            func tick(_ tx: CGFloat, major: Bool) {
                var t = Path()
                t.move(to: CGPoint(x: tx, y: baseline + 1))
                t.addLine(to: CGPoint(x: tx, y: baseline + (major ? 8 : 4)))
                ctx.stroke(t, with: .color(ink), lineWidth: 0.5)
            }

            // The closing label sits at the right edge; mid labels must stay clear of it.
            let endText = meters.map { "\($0) m" } ?? "\(minutes) min"
            let end = ctx.resolve(Text(endText).font(BLFont.unit.monospacedDigit()).foregroundStyle(ink))
            let endSize = end.measure(in: CGSize(width: 200, height: rulerBand))
            let endFits = endSize.height + 9 <= rulerBand
            if endFits { ctx.draw(end, at: CGPoint(x: size.width, y: baseline + 9), anchor: .topTrailing) }
            let labelLimit = size.width - (endFits ? endSize.width + 6 : 0)

            /// Draws the label when it fits and says so, so a tall tick is only ever drawn over a label.
            @discardableResult
            func midLabel(_ s: String, at tx: CGFloat) -> Bool {
                let r = ctx.resolve(Text(s).font(BLFont.unit.monospacedDigit()).foregroundStyle(ink))
                let sz = r.measure(in: CGSize(width: 200, height: rulerBand))
                guard sz.height + 9 <= rulerBand, tx - sz.width / 2 >= 0, tx + sz.width / 2 <= labelLimit else { return false }
                ctx.draw(r, at: CGPoint(x: tx, y: baseline + 9), anchor: .top)
                return true
            }

            if let totalMeters = meters {
                // Ticks every 100 m placed inside the block that contains that distance (rests add none),
                // 8 pt tick and a label every 500 m. The total closes the axis.
                var before = 0
                var cursor = 100
                for (i, s) in list.enumerated() {
                    guard let m = s.profileMeters, m > 0 else { continue }
                    let span = spans[i]
                    while cursor <= before + m && cursor < totalMeters {
                        let tx = span.start + (span.end - span.start) * CGFloat(cursor - before) / CGFloat(m)
                        let wantsLabel = cursor % 500 == 0
                        let drew = wantsLabel ? midLabel("\(cursor) m", at: tx) : false
                        tick(tx, major: drew)
                        cursor += 100
                    }
                    before += m
                }
                tick(size.width, major: true)
            } else {
                // Courses over two hours get a sparser axis so the labels stay readable.
                let labelEvery = minutes > 120 ? 30 : 15
                let tickEvery = minutes > 120 ? 10 : 5
                for m in stride(from: 0, through: minutes, by: tickEvery) {
                    let tx = size.width * CGFloat(Double(m * 60) / total)
                    let wantsLabel = m % labelEvery == 0
                    // The origin keeps its tall tick as the axis start; every other tall tick must carry a label.
                    let drew = wantsLabel && m > 0 ? midLabel("\(m)", at: tx) : false
                    tick(tx, major: drew || m == 0)
                }
                tick(size.width, major: true)
            }
        }

        // Player playhead: the 2 pt line and the 6 pt cap are clamped so neither is clipped at an edge.
        if case .player = mode {
            let raw = size.width * CGFloat(progress / total)
            let px = min(size.width - 3, max(3, raw))
            var line = Path()
            line.move(to: CGPoint(x: px, y: top - 2))
            line.addLine(to: CGPoint(x: px, y: baseline))
            ctx.stroke(line, with: .color(BL.Player.accent), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: px - 3, y: top - 8, width: 6, height: 6)), with: .color(BL.Player.accent))
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
        var lead = "\(sports.joined(separator: " then ")), \(minutes) minutes"
        if let meters = meterTotal(steps) {
            lead = "\(sports.joined(separator: " then ")), \(meters) meters, \(minutes) minutes"
        }
        var parts = [lead]
        if let reps, reps > 1, let work = steps.first(where: { $0.kind == .work }) {
            parts.append("\(reps) by \(work.distance ?? "\(Int(work.seconds / 60)) minutes") at \(work.target ?? "target")")
        }
        if case .state(let s) = mode { parts.append(s == .done ? "done" : s == .skipped ? "skipped" : "planned") }
        return parts.joined(separator: ", ")
    }
}

/// Says what the bars in a Profile mean, so nobody has to guess which are easy and which are hard.
/// Only the kinds of step the session really has are listed.
struct ProfileLegend: View {
    var steps: [PlanStep]
    var onBlack = false
    /// Adds a line on what the scale under the chart counts.
    var explainsScale = false

    private var sport: Sport { steps.first(where: { $0.kind == .work })?.sport ?? steps.first?.sport ?? .run }
    private var color: Color {
        if onBlack { switch sport { case .swim: return BL.Player.swimFill; case .bike: return BL.Player.bikeFill; case .run: return BL.Player.runFill } }
        return sport.fill
    }
    private var ink: Color { onBlack ? BL.Player.textSecondary : BL.textSecondary }
    private var hasEasyEnds: Bool { steps.contains { $0.kind == .warm || $0.kind == .cool } }
    private var hasRest: Bool { steps.contains { $0.kind == .recovery } }
    private var workLevel: Int { steps.filter { $0.kind == .work }.map(\.level).max() ?? 2 }
    private var workWord: String {
        if workLevel >= 4 { return sport == .swim ? "Fast swim" : "Hard part" }
        return workLevel == 3 ? "Steady part" : "Easy part"
    }
    private var isSwim: Bool { steps.allSatisfy { $0.sport == .swim } }
    private var scaleText: String { isSwim ? "The scale under the chart is the distance swum so far." : "The scale under the chart is minutes so far." }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BL.Space.l) { items; Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 4) { items }
            }
            if explainsScale {
                Text(scaleText).font(.caption).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts: [String] = []
        if hasEasyEnds { parts.append("light bars are the easy warm up and cool down") }
        parts.append("solid bars are the \(workWord.lowercased()), and taller means harder")
        if hasRest { parts.append(sport == .swim ? "gaps are rest" : "outlined bars are easy rest") }
        return "Chart key: " + parts.joined(separator: ", ") + "."
    }

    @ViewBuilder private var items: some View {
        if hasEasyEnds {
            item("Easy warm up and cool down") {
                RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1))
            }
        }
        item(workWord) { RoundedRectangle(cornerRadius: 2).fill(color) }
        if hasRest {
            if sport == .swim {
                Text("Gaps are rest").font(.caption.weight(.medium)).foregroundStyle(ink).lineLimit(1)
            } else {
                item("Easy rest") { RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1.5) }
            }
        }
    }

    private func item<G: View>(_ text: String, @ViewBuilder glyph: () -> G) -> some View {
        HStack(spacing: 6) {
            glyph().frame(width: 14, height: 10).accessibilityHidden(true)
            Text(text).font(.caption.weight(.medium)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

private extension PlanStep {
    /// Meters parsed from the display distance ("300 m"), so the swim ruler needs no model change.
    /// Kilometer strings and anything else return nil.
    var profileMeters: Int? {
        guard let distance else { return nil }
        let text = distance.trimmingCharacters(in: .whitespaces)
        guard text.hasSuffix(" m") else { return nil }
        return Int(text.dropLast(2).trimmingCharacters(in: .whitespaces))
    }
}

private extension Path {
    func insetBy(_ d: CGFloat) -> Path {
        let r = boundingRect.insetBy(dx: d, dy: d)
        guard r.width > 0, r.height > 0 else { return self }
        return Path(roundedRect: r, cornerRadius: BL.Radius.block, style: .continuous)
    }
}
