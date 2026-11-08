import Foundation

/// A session already on the calendar, reduced to what the placement rules need. Day numbers count days from the
/// start of the generated sequence, so earlier weeks (and prior history) have smaller numbers.
struct PlacedRecord {
    var day: Int
    var sport: Sport
    var quality: Bool
    var test: Bool
    var longRide: Bool
    var longRun: Bool
    var brick: Bool
}

/// One session waiting for a day.
struct PlacementItem {
    var id: Int
    var sport: Sport
    var quality: Bool
    var test: Bool
    var longRide: Bool
    var longRun: Bool
    var brick: Bool
    /// Lower places first and is dropped last.
    var priority: Int
    /// Day numbers this session may take (declared days, pool days for swims, days before the race).
    var allowed: [Int]
}

/// Deterministic backtracking placement of one week (annex B "Microcycle assembly").
///
/// Hard rules, never broken:
/// - sessions only on allowed days, swims only on pool days;
/// - at most two sessions a day, never two of one sport, never two quality sessions, never a brick sharing a
///   day, and a long session shares only with a short easy session of another sport;
/// - no two quality sessions of one sport on back to back days (annex B);
/// - maximal effort tests at least 48 hours apart (annex A retest rotation);
/// - the long ride and long run at least one full day apart (annex B);
/// - no quality or long session on the eve of the race.
/// Soft rules shape the week: weekend long sessions, spaced quality days, one session a day where possible.
struct WeekPlacer {
    let history: [PlacedRecord]
    let weekdayOfDay: [Int: Weekday]
    let raceEve: Int?
    var nodeBudget = 6000

    private var nodes = 0

    init(history: [PlacedRecord], weekdayOfDay: [Int: Weekday], raceEve: Int?) {
        self.history = history
        self.weekdayOfDay = weekdayOfDay
        self.raceEve = raceEve
    }

    /// Returns item id to day, or nil when the items cannot all be placed under the hard rules.
    mutating func solve(_ items: [PlacementItem]) -> [Int: Int]? {
        nodes = 0
        let ordered = items.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            if $0.allowed.count != $1.allowed.count { return $0.allowed.count < $1.allowed.count }
            return $0.id < $1.id
        }
        var assigned: [Int: Int] = [:]
        return search(0, ordered, &assigned) ? assigned : nil
    }

    private mutating func search(_ position: Int, _ items: [PlacementItem], _ assigned: inout [Int: Int]) -> Bool {
        if position == items.count { return true }
        nodes += 1
        if nodes > nodeBudget { return false }
        let item = items[position]
        let records = currentRecords(items, assigned)
        var candidates: [(score: Int, day: Int)] = []
        for day in item.allowed where isLegal(item, day, records) {
            candidates.append((score(item, day, records), day))
        }
        candidates.sort { $0.score != $1.score ? $0.score < $1.score : $0.day < $1.day }
        for candidate in candidates {
            assigned[item.id] = candidate.day
            if search(position + 1, items, &assigned) { return true }
            assigned[item.id] = nil
            if nodes > nodeBudget { return false }
        }
        return false
    }

    private func currentRecords(_ items: [PlacementItem], _ assigned: [Int: Int]) -> [PlacedRecord] {
        var out = history
        for item in items {
            if let day = assigned[item.id] {
                out.append(PlacedRecord(day: day, sport: item.sport, quality: item.quality, test: item.test,
                                        longRide: item.longRide, longRun: item.longRun, brick: item.brick))
            }
        }
        return out
    }

    private func isLegal(_ item: PlacementItem, _ day: Int, _ records: [PlacedRecord]) -> Bool {
        if let eve = raceEve, day == eve, item.quality || item.test || item.longRide || item.longRun || item.brick {
            return false
        }
        var onDay = 0
        for r in records {
            let gap = abs(r.day - day)
            if gap == 0 {
                onDay += 1
                if onDay >= 2 { return false }
                if r.sport == item.sport { return false }
                if r.quality && item.quality { return false }
                // A long session may share a day with a short easy session of another sport, nothing heavier.
                let rLong = r.longRide || r.longRun
                let iLong = item.longRide || item.longRun
                if r.brick || item.brick { return false }
                if rLong && iLong { return false }
                if (rLong && item.quality) || (iLong && r.quality) { return false }
            }
            if item.quality && r.quality && r.sport == item.sport && gap < 2 { return false }
            if item.test && r.test && gap < 2 { return false }
            if item.longRun && r.longRide && gap < 2 { return false }
            if item.longRide && r.longRun && gap < 2 { return false }
        }
        return true
    }

    private func score(_ item: PlacementItem, _ day: Int, _ records: [PlacedRecord]) -> Int {
        var s = 0
        let weekday = weekdayOfDay[day] ?? .monday
        if item.longRide {
            if weekday == .saturday { s += 0 } else if weekday == .sunday { s += 1 } else { s += 6 }
        } else if item.longRun {
            if weekday == .sunday { s += 0 } else if weekday == .saturday { s += 1 } else { s += 6 }
        }
        for r in records {
            let gap = abs(r.day - day)
            if gap == 0 { s += 40 }
            if gap == 1 {
                s += 1
                if r.sport == item.sport { s += 6 }
                if item.quality && (r.quality || r.test) { s += 8 }
                let rIsLong = r.longRide || r.longRun || r.brick
                let itemIsLong = item.longRide || item.longRun || item.brick
                if item.quality && rIsLong && r.day == day + 1 { s += 5 }
                if itemIsLong && r.quality && r.day == day - 1 { s += 5 }
            }
        }
        return s
    }
}
