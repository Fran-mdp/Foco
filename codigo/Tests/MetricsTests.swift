import Foundation
@main struct MetricsTests {
 static func main() throws {
    var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(secondsFromGMT:0)!
    func date(_ text:String)->Date {ISO8601DateFormatter().date(from:text)!}
    let now=date("2026-01-02T12:00:00Z")
    var state=FocusState()
    state.records=[FocusRecord(id:"midnight",startedAt:date("2025-12-31T23:30:00Z").timeIntervalSince1970,seconds:3600,completed:true),FocusRecord(id:"jan1",startedAt:date("2026-01-01T10:00:00Z").timeIntervalSince1970,seconds:1200,completed:false)]
    state.session=FocusSession(startedAt:now.timeIntervalSince1970-600,duration:nil,firm:false)
    func metrics(_ period:FocusPeriod,anchor:Date=now)->FocusMetrics { FocusMetrics(state:state,now:now,calendar:cal,period:period,anchor:anchor,customStart:date("2026-01-01T00:00:00Z"),customEnd:now) }
    let day=metrics(.day)
    precondition(day.total==600 && day.points.count==24,"Live session/day hours")
    precondition(day.sessions.count==0 && day.sessionAverage==0,"Running sessions excluded from finished-session mean")
    let month=metrics(.month)
    precondition(month.total==3600 && month.dailyAverage==1800 && month.dayCount==2,"Month includes midnight overlap and excludes future days from average")
    precondition(month.sessionAverage==1200 && month.sessions.count==1,"Session assigned by start date")
    precondition(month.activeDays==2,"Active days")
    let previousDay=metrics(.day,anchor:date("2026-01-01T12:00:00Z"))
    precondition(previousDay.total==3000,"Cross-midnight time split between dates")
    let year=metrics(.year)
    precondition(year.chartUnit == .month && year.points.count == 1,"Current year groups elapsed months")
    let custom=metrics(.custom)
    precondition(custom.total==3600 && custom.dayCount==2,"Custom end date inclusive")
    let comparison=month.comparison!
    precondition(comparison.days==1 && comparison.current==3000 && comparison.previous==1800,"Comparison excludes partial today, equal complete-day intervals")
    let json=Data("{\"startedAt\":0,\"duration\":60,\"firm\":false,\"id\":\"old\"}".utf8)
    let old=try JSONDecoder().decode(FocusSession.self,from:json)
    precondition(old.blockWhatsAppApp==nil && old.blockWhatsAppWeb==nil,"Backward compatible existing sessions")
    let marchNow=date("2026-12-15T12:00:00Z")
    var long=year
    long=FocusMetrics(state:state,now:marchNow,calendar:cal,period:.year,anchor:marchNow,customStart:now,customEnd:now)
    precondition(long.points.count==12 && long.chartUnit == .month,"Yearly month buckets")
    var breaks = FocusState()
    let midnight = date("2026-01-02T00:00:00Z").timeIntervalSince1970
    breaks.records = [FocusRecord(id: "break", startedAt: midnight-600, seconds: 900, completed: false, intervals: [FocusInterval(start: midnight-600, end: midnight-300), FocusInterval(start: midnight+300, end: midnight+900)])]
    let breakMetrics = FocusMetrics(state: breaks, now: now, calendar: cal, period: .day, anchor: now, customStart: now, customEnd: now)
    precondition(breakMetrics.total == 600 && breakMetrics.sessionAverage == 0, "Dashboard excludes midnight pause and assigns record by start date")
    let week = metrics(.week)
    precondition(week.points.count == 7 && cal.component(.weekday, from: week.points.first!.date) == 2, "Week chart includes Monday through Sunday")
    precondition(week.dayCount == 5 && week.daily.count == 5, "Future days never enter daily average denominator")
    precondition(week.points.suffix(2).allSatisfy { $0.seconds == 0 }, "Remaining weekend has no future focus time")
    precondition(week.chartEnd == week.bounds.end, "Weekly chart domain includes entire final day")
    let emptyWeek = FocusMetrics(state: FocusState(), now: now, calendar: cal, period: .week, anchor: now, customStart: now, customEnd: now)
    precondition(emptyWeek.points.count == 7 && emptyWeek.points.allSatisfy { $0.seconds == 0 }, "Empty week retains all seven dates")
    let closedWeek = metrics(.week, anchor: date("2025-12-15T12:00:00Z"))
    precondition(closedWeek.points.count == 7 && closedWeek.dayCount == 7, "Past week retains seven chart and statistical days")
    var dstCal = cal; dstCal.timeZone = TimeZone(identifier: "America/New_York")!
    let dstNow = date("2026-03-04T17:00:00Z")
    let dstWeek = FocusMetrics(state: FocusState(), now: dstNow, calendar: dstCal, period: .week, anchor: dstNow, customStart: dstNow, customEnd: dstNow)
    precondition(dstWeek.points.count == 7 && dstCal.component(.weekday, from: dstWeek.points.last!.date) == 1, "DST week still ends on Sunday")
    precondition(dstWeek.bounds.duration == 167 * 3600 && dstWeek.dayCount == 3, "DST week uses calendar boundaries while average ends today")
    print("Metrics checks passed: midnight, averages, filters, full Monday–Sunday chart, future days, empty/past/DST weeks and year buckets")
 }
}
