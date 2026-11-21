import Foundation
@main enum Test {
 static func main() throws {
  let formatter=ISO8601DateFormatter();func dt(_ s:String)->Date {formatter.date(from:s)!}
  var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(identifier:"Europe/London")!; let now=dt("2026-11-02T12:00:00Z")
  let events:[ReceiptCalendar.Event]=[.init(date:dt("2026-10-24T23:30:00Z"),engine:"iphone",preview:true), .init(date:dt("2026-10-25T01:30:00Z"),engine:"iphone",preview:false),.init(date:now,engine:"demo",preview:false),.init(date:dt("2026-11-02T13:00:00Z"),engine:"iphone",preview:false),.init(date:dt("2026-10-05T13:00:00Z"),engine:"iphone",preview:false),.init(date:now,engine:"iphone",preview:true)]
  let d=ReceiptCalendar.days(events,engine:"iphone",now:now,calendar:cal);precondition(d.count==28 && d.last?.previews==1 && Set(d.map(\.date)).count==28);precondition(d.reduce(0){$0+$1.total}==3);let dst=d.first{cal.component(.day,from:$0.date)==25}!;precondition(dst.previews==1 && dst.other==1);let demo=ReceiptCalendar.days(events,engine:"demo",now:now,calendar:cal);precondition(demo.reduce(0){$0+$1.total}==1);let empty=ReceiptCalendar.days([],engine:"iphone",now:now,calendar:cal);precondition(empty.allSatisfy{$0.total==0});print("PASS: 28 local days, DST boundary, selected engine, preview split, empty and future/out-of-window exclusion")
 }
}
