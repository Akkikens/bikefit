import Foundation

/// All race window wording in one place so a copy pass touches one file. Language rules follow spec section 6:
/// framing is training and endurance, nothing here names a body condition, and no sodium numbers appear.
public enum RaceWindowCopy {
    /// Pacing caveat for Sprint and Olympic (annex F: targets can be off by several percent).
    public static let shortCourseCaveat =
        "Targets can be off by several percent on hilly or windy courses. Read them as ranges, not as splits."

    /// Pacing caveat for the 70.3. Same several percent message (annex F), plus the honest note that a few
    /// percent over a long day is a lot of minutes.
    public static let longCourseCaveat =
        "Targets can be off by several percent on hilly or windy courses, and over a 70.3 that adds up to many minutes. Read them as ranges, not as splits."

    /// Caveat for a full distance race (B29: flat calculators can run 15 to 25 minutes off). Full distance is
    /// not offered in 1.0, so no `RaceDistance` maps to this yet; it is kept here so the wording is reviewed once.
    public static let fullDistanceCaveat =
        "On hilly or windy courses at full distance, flat calculators can run 15 to 25 minutes off. Read these targets as ranges, not as splits."

    /// The one sentence every fueling tier carries (annex F, B29).
    public static let stomachLine =
        "Taking in more than the duration needs mainly raises the chance of stomach trouble, so more is not better."

    /// The two debrief prompts (annex F "Debrief").
    public static let debriefPrompts = [
        "What went well?",
        "What would you change next time?"
    ]

    static let bikeServiceText =
        "Bike service check. If your bike has not been looked over lately, book a tune up this week."
    static let travelPackText =
        "Start packing for travel. Bike, helmet, kit and the fuel you have already tried in training."
    static let travelText =
        "Travel day. When you arrive, rebuild and check your bike, then take a short easy spin to be sure it all works."
    static let carbLoadLongText =
        "Carb load starts today. Add extra carbohydrate at your meals for the next two days, using foods you already know sit well."
    static let carbLoadShortText =
        "Race eve. Have a carbohydrate rich dinner with foods you already know sit well. Nothing new."
    static let packTonightText =
        "Pack tonight. Lay out your swim, bike and run gear and your race morning list."

    static let packAndDinnerText =
        "Pack tonight and keep dinner familiar and carbohydrate rich. Nothing new. Lay out your swim, bike and run gear and your race morning list."

    static func wakeUpText(wake: Int, start: Int, transit: Int, setup: Int, breakfast: Int, clamped: Bool = false) -> String {
        let eat: String
        if breakfast >= 60, breakfast % 60 == 0 {
            eat = breakfast == 60 ? "1 hour" : "\(breakfast / 60) hours"
        } else {
            eat = "\(breakfast) minutes"
        }
        var text = "Wake up at \(RaceFormat.clock(minutesAfterMidnight: wake)). That is a \(RaceFormat.clock(minutesAfterMidnight: start)) start, minus \(transit) minutes of transit, \(setup) minutes of setup and a \(breakfast) minute breakfast lead, so you can eat about \(eat) before the start."
        if clamped {
            text = "Wake up at \(RaceFormat.clock(minutesAfterMidnight: wake)). " + wakeUpClampedWarning
        }
        return text
    }

    /// Shown when transit, setup and breakfast lead add up to more than the time before the start.
    public static let wakeUpClampedWarning =
        "Your transit, setup and breakfast lead add up to more than the time before the start, so shorten them in the race details."

    /// Caveat for a distance (annex F "Pacing card": the caveat scales by distance).
    public static func caveat(for distance: RaceDistance) -> String {
        switch distance {
        case .sprint, .olympic: return shortCourseCaveat
        case .half: return longCourseCaveat
        }
    }
}
