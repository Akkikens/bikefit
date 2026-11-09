import SwiftUI

/// Plain language for triathlon shorthand. Every jargon word in the UI is wrapped in `JargonText`, which shows a small
/// info glyph and opens the explanation. Copy rules: no em or en dashes, say what it is for, give a number when it helps.
enum Term: String, CaseIterable, Identifiable {
    case css, ftp, lthr, threshold, brick, rpe, zone, warmUp, coolDown, sweetSpot
    case base, build, peak, taper, recoveryWeek, testWeek
    case load, fitness, form, estimated, transition
    case hrv, restingHeartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .css: "CSS, critical swim speed"
        case .ftp: "FTP, functional threshold power"
        case .lthr: "LTHR, lactate threshold heart rate"
        case .threshold: "Threshold"
        case .brick: "Brick"
        case .rpe: "RPE, rate of perceived exertion"
        case .zone: "Zones"
        case .warmUp: "Warm up"
        case .coolDown: "Cool down"
        case .sweetSpot: "Sweet spot"
        case .base: "Base phase"
        case .build: "Build phase"
        case .peak: "Peak phase"
        case .taper: "Taper"
        case .recoveryWeek: "Recovery week"
        case .testWeek: "Test week"
        case .load: "Load"
        case .fitness: "Fitness"
        case .form: "Form"
        case .estimated: "Estimated"
        case .transition: "Transitions, T1 and T2"
        case .hrv: "Heart rate variability (HRV)"
        case .restingHeartRate: "Resting heart rate"
        }
    }

    /// One short line for a popover or caption.
    var short: String {
        switch self {
        case .css: "Your steady hard swim pace per 100 m."
        case .ftp: "The hardest power you could hold for about an hour on the bike."
        case .lthr: "The heart rate you can hold at that same hard effort."
        case .threshold: "A hard but steady effort you could hold for about an hour."
        case .brick: "A bike ride followed straight away by a run."
        case .rpe: "How hard it feels, from 1 (very easy) to 10 (all out)."
        case .zone: "Effort ranges from easy to very hard, set from your own numbers."
        case .warmUp: "Easy start so your body is ready for the hard part."
        case .coolDown: "Easy finish so your heart rate settles."
        case .sweetSpot: "Just under threshold: hard enough to build strength, not so hard you cannot repeat it."
        case .base: "Weeks of mostly easy training that build your engine."
        case .build: "Harder sessions are added while the weekly total holds steady."
        case .peak: "Race specific sessions and your biggest weeks."
        case .taper: "Less training in the last 1 to 3 weeks so you arrive fresh."
        case .recoveryWeek: "Every fourth week is lighter so your body can absorb the work."
        case .testWeek: "A week with short tests that keep your zones honest."
        case .load: "How much a session asks of your body, in one number."
        case .fitness: "Your Load averaged over about 6 weeks. It rises as you train consistently."
        case .form: "Fitness minus your last week of Load. Higher means fresher."
        case .estimated: "A guess until you do a test. Pace changes never use guesses."
        case .transition: "The switches between swim and bike (T1), then bike and run (T2)."
        case .hrv: "How much the time between your heartbeats varies, measured while you sleep."
        case .restingHeartRate: "How fast your heart beats at rest, in beats per minute."
        }
    }

    /// The longer explanation shown in the sheet.
    var explanation: String {
        switch self {
        case .css:
            return "CSS is how fast you can swim at a steady hard effort. To find it, swim 400 m as fast as you can, rest 5 to 10 minutes, then swim 200 m as fast as you can. Your CSS pace per 100 m is the difference between the two times, divided by 2. Brickline sets every swim pace from it. If you have not tested yet, the app uses an estimate and marks it as one."
        case .ftp:
            return "FTP is the hardest average power you could hold for about an hour. A common test is a 20 minute all out ride; your FTP is 95 percent of your average power. It needs a power meter. No power meter? Brickline uses heart rate or how hard it feels instead, and the plan works the same way."
        case .lthr:
            return "Your lactate threshold heart rate is the heart rate you can sustain at a hard steady effort. A common test is a 30 minute all out run or ride: the average heart rate of the last 20 minutes is your LTHR. Brickline uses it to set heart rate zones when you have no power meter."
        case .threshold:
            return "Threshold is the line between hard and very hard. At threshold you are breathing heavily and can say only a few words, but you can keep going for about an hour. Training just at and below it is how you get faster over longer distances."
        case .brick:
            return "A brick is a bike ride followed straight away by a run. Your legs feel strange when you start running after riding, and bricks teach them the switch. Most plans add one short brick a week once the training gets harder."
        case .rpe:
            return "Rate of perceived exertion is a simple 1 to 10 scale for how hard something feels. 1 to 3 is easy, you could chat. 4 to 6 is steady, short sentences. 7 to 8 is hard. 9 to 10 is all out. It always works, even without a watch or a power meter."
        case .zone:
            return "Zones split your effort into ranges from easy to very hard. Most of your training should be easy, with a few hard sessions each week. Brickline sets each zone from your own swim, bike and run numbers, so it fits you and not an average athlete."
        case .warmUp:
            return "The easy minutes at the start of a session. They raise your heart rate gradually, loosen your muscles and make the hard part safer and more effective."
        case .coolDown:
            return "The easy minutes at the end of a session. They bring your heart rate down gradually and are a good time to stretch."
        case .sweetSpot:
            return "Sweet spot is a bike effort just under threshold, around 88 to 94 percent of your FTP. It builds endurance and strength without the recovery cost of true threshold work, so you can do more of it."
        case .base:
            return "Base is the first part of the plan. Mostly easy swimming, riding and running to build your aerobic engine, plus technique work. It is usually 40 to 50 percent of the plan."
        case .build:
            return "In the build phase, harder sessions like threshold intervals are added in each sport while your total weekly time stays steady. It is usually about 30 percent of the plan."
        case .peak:
            return "The peak phase brings sessions that look like your race: longer bricks, race pace efforts and your biggest weeks. It is usually the last 15 percent before the taper."
        case .taper:
            return "A taper cuts your training volume in the final 1 to 3 weeks and keeps a little intensity, so you arrive at the start line fresh instead of tired."
        case .recoveryWeek:
            return "Every fourth week is lighter, about 30 to 40 percent less training. Fitness is built while you recover, not only while you train, so these weeks matter."
        case .testWeek:
            return "Test weeks include short all out efforts, like the 400 m and 200 m swims, that update your zones. Each sport is retested about every 6 weeks. At most two sports are tested in one week."
        case .load:
            return "Load is one number for how much a session asks of your body. It combines how long and how hard you trained. It is calculated from power when you have it, or from time in heart rate zones when you do not, and it is less precise in that case."
        case .fitness:
            return "Fitness is a 42 day average of your daily Load. It goes up slowly when you train consistently and down slowly when you stop. It is not a prediction of race performance."
        case .form:
            return "Form is your Fitness minus your last 7 days of Load. When it is high you are fresher, when it is low you are carrying fatigue. It is normal to be low during hard weeks and high before a race."
        case .estimated:
            return "Estimated means the number is a guess, for example because you have not done the test yet. Estimated numbers are labelled everywhere, and Brickline never changes your paces based on them."
        case .transition:
            return "A transition is the time between two parts of the race. T1 is swim to bike: wetsuit off, helmet on. T2 is bike to run: shoes swapped. They count toward your finish time, and they are easy to practise."
        case .hrv:
            return "Your heart does not beat like a clock. The gaps between beats change a little, and that change is called heart rate variability, measured in milliseconds. Your watch, band or ring measures it while you sleep. What matters is not the number but how it compares with your own usual range, which Brickline learns over 14 nights. Different devices measure it in different ways, so Brickline never mixes numbers from two devices."
        case .restingHeartRate:
            return "Resting heart rate is how many times your heart beats each minute when you are still, often measured overnight. Everyone has a different usual number. Brickline compares last night with your own usual range, never with anyone else's."
        }
    }
}

/// Text with a small info glyph. Tapping opens the explanation. Use for any term in `Term`.
struct JargonText: View {
    var term: Term
    var label: String? = nil
    var font: Font = .body
    var ink: Color = BL.textPrimary
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 4) {
                Text(label ?? term.title).font(font).foregroundStyle(ink)
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label ?? term.title). Explain")
        .sheet(isPresented: $showing) { GlossarySheet(term: term) }
    }
}

struct GlossarySheet: View {
    var term: Term
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.l) {
                    Text(term.title).font(.title2.weight(.semibold)).foregroundStyle(BL.textPrimary)
                    Text(term.short).font(.title3).foregroundStyle(BL.textPrimary)
                    Text(term.explanation).font(.body).foregroundStyle(BL.textSecondary).lineSpacing(3)
                }
                .padding(BL.Space.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(BL.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(BL.Radius.sheet)
    }
}

/// The full glossary as a list, for Methods.
struct GlossaryList: View {
    var body: some View {
        List {
            ForEach(Term.allCases) { t in
                NavigationLink {
                    GlossarySheetPage(term: t)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title).font(.body.weight(.medium))
                        Text(t.short).font(.subheadline).foregroundStyle(BL.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Glossary")
        .scrollContentBackground(.hidden)
        .background(BL.background.ignoresSafeArea())
    }
}

private struct GlossarySheetPage: View {
    var term: Term
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BL.Space.l) {
                Text(term.short).font(.title3).foregroundStyle(BL.textPrimary)
                Text(term.explanation).font(.body).foregroundStyle(BL.textSecondary).lineSpacing(3)
            }
            .padding(BL.Space.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BL.background.ignoresSafeArea())
        .navigationTitle(term.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
