import WidgetKit
import SwiftUI
struct SchoolEntry: TimelineEntry {let date:Date;let title:String;let body:String;var link:URL? = nil}
struct SchoolProvider: TimelineProvider {
 let kind:String
 func placeholder(in context:Context)->SchoolEntry {SchoolEntry(date:Date(),title:kind=="timetable" ? "Today’s timetable":"Homework due",body:"Open Schoolday to view school updates")}
 func getSnapshot(in context:Context,completion:@escaping(SchoolEntry)->Void){completion(read())}
 func getTimeline(in context:Context,completion:@escaping(Timeline<SchoolEntry>)->Void){completion(Timeline(entries:[read()],policy:.after(Date().addingTimeInterval(1800))))}
 func read()->SchoolEntry {
  let data=UserDefaults(suiteName:"group.app.schoolday.schoolerp")
  let enabled=data?.bool(forKey:"enabled") ?? false
  let updated=data?.string(forKey:"updated") ?? ""
  let formatter=DateFormatter();formatter.calendar=Calendar(identifier:.gregorian);formatter.locale=Locale(identifier:"en_US_POSIX");formatter.dateFormat="yyyy-MM-dd"
  let valid=enabled && (kind != "timetable" || updated.hasPrefix(formatter.string(from:Date())))
  let content=valid ? (data?.string(forKey:kind) ?? "") : ""
  return SchoolEntry(date:Date(),title:kind=="timetable" ? "Today’s timetable":"Homework due",body: !enabled ? "Enable widgets in Schoolday settings" : !valid ? "Open Schoolday to refresh today’s lessons" : content.isEmpty ? "Nothing published yet" : content,link: valid ? data?.string(forKey:"\(kind)_url").flatMap { URL(string:$0) } : nil)
 }
}
struct SchoolWidgetView: View {
 let entry:SchoolEntry;let kind:String
 var body: some View {
  VStack(alignment:.leading,spacing:10){Text("SCHOOLDAY").font(.caption2.weight(.bold)).foregroundColor(Color(red:0.086,green:0.482,blue:0.408));Text(entry.title).font(.headline);Text(entry.body).font(.caption).lineLimit(5);Spacer(minLength:0)}.padding().frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).modifier(SchoolWidgetBackground()).privacySensitive().widgetURL(entry.link ?? URL(string:"schoolday://\(kind)"))
 }
}
struct SchooldayTimetable:Widget {let kind="SchooldayTimetable";var body:some WidgetConfiguration {StaticConfiguration(kind:kind,provider:SchoolProvider(kind:"timetable")){SchoolWidgetView(entry:$0,kind:"timetable")}.configurationDisplayName("Today’s timetable").description("Your selected child’s published lessons.").supportedFamilies([.systemSmall,.systemMedium])}}
struct SchooldayHomework:Widget {let kind="SchooldayHomework";var body:some WidgetConfiguration {StaticConfiguration(kind:kind,provider:SchoolProvider(kind:"homework")){SchoolWidgetView(entry:$0,kind:"homework")}.configurationDisplayName("Homework due").description("Published homework for the selected child.").supportedFamilies([.systemSmall,.systemMedium])}}
@main struct SchooldayWidgets:WidgetBundle {var body:some Widget {SchooldayTimetable();SchooldayHomework()}}

private struct SchoolWidgetBackground:ViewModifier {
 @ViewBuilder func body(content:Content)->some View {
  if #available(iOS 17.0,*) {content.containerBackground(for:.widget){Color(red:0.969,green:0.976,blue:0.961)}}
  else {content.background(Color(red:0.969,green:0.976,blue:0.961))}
 }
}
