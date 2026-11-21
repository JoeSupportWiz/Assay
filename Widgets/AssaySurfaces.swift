import Foundation
import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

private struct WorkbenchEntry: TimelineEntry {let date:Date}
private struct WorkbenchProvider:TimelineProvider {
    func placeholder(in context:Context)->WorkbenchEntry {WorkbenchEntry(date:.now)}
    func getSnapshot(in context:Context,completion:@escaping (WorkbenchEntry)->Void){completion(.init(date:.now))}
    func getTimeline(in context:Context,completion:@escaping(Timeline<WorkbenchEntry>)->Void) {completion(Timeline(entries:[.init(date:.now)],policy:.never))}
}
private struct WorkbenchFace:View {
    @Environment(\.widgetFamily) var family
    var body:some View { Group {
        if family == .accessoryCircular {Image(systemName:"clock.badge.checkmark").widgetAccentable().widgetURL(URL(string:"assay://open/clock"))}
        else if family == .accessoryRectangular {Label("Check the clock",systemImage:"clock").widgetURL(URL(string:"assay://open/clock"))}
        else if family == .systemMedium { VStack(alignment:.leading,spacing:8){Text("Assay").font(.headline);HStack{link("Clock","clock","clock");Spacer();link("Scenes","square.2.layers.3d","scenes");Spacer();link("Files","tray.full","vault")}} }
        else {VStack(alignment:.leading,spacing:12){Image(systemName:"clock").font(.title);Text("Clock check").font(.headline);Text("Open Assay").font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).widgetURL(URL(string:"assay://open/clock"))}
    }.containerBackground(for:.widget) {Color(.secondarySystemBackground)} }
    func link(_ title:String,_ icon:String,_ route:String)->some View {Link(destination:URL(string:"assay://open/"+route)!){VStack{Image(systemName:icon).font(.title3);Text(title).font(.caption)}}}
}
struct WorkbenchWidget:Widget {
    var body:some WidgetConfiguration {StaticConfiguration(kind:"AssayWorkbench",provider:WorkbenchProvider()){_ in WorkbenchFace()}.configurationDisplayName("Assay workbench").description("Open a clock check, your Scenes, or File Vault. No action runs automatically.").supportedFamilies([.systemSmall,.systemMedium,.accessoryCircular,.accessoryRectangular])}
}
struct VaultProgressWidget: Widget {
    var body:some WidgetConfiguration {
        ActivityConfiguration(for:AssayVaultActivity.self) { ctx in
            VStack(alignment:.leading,spacing:5){Label(ctx.attributes.restoring ? "Restoring file copy":"Saving file checkpoint",systemImage:"tray.full").font(.headline);Text(ctx.state.phase);if ctx.isStale && !ctx.state.finished {Text("No recent update · open Assay to check").font(.caption)};Text(ctx.state.reported,style:.time).font(.caption).foregroundStyle(.secondary)}.padding().widgetURL(URL(string:"assay://open/vault"))
        } dynamicIsland: {ctx in DynamicIsland {
            DynamicIslandExpandedRegion(.leading){Image(systemName:"tray.full")}
            DynamicIslandExpandedRegion(.center){Text(ctx.attributes.restoring ? "Restore copy":"File checkpoint")}
            DynamicIslandExpandedRegion(.bottom){Text(ctx.isStale && !ctx.state.finished ? "Waiting for an update":ctx.state.phase)}
        } compactLeading: {Image(systemName:"tray.full")} compactTrailing: {Image(systemName:ctx.state.finished ? "checkmark.circle":"ellipsis")} minimal: {Image(systemName:"tray.full")}.widgetURL(URL(string:"assay://open/vault")) }
    }
}
@available(iOSApplicationExtension 18.0, *)
struct AssayOpenControl:ControlWidget {
    var body:some ControlWidgetConfiguration { StaticControlConfiguration(kind:"AssayOpenWorkbenchControl"){ControlWidgetButton(action:OpenWorkbenchIntent()){Label("Open Assay",systemImage:"square.2.layers.3d")}}.displayName("Open Assay").description("Bring the workbench into the foreground. Does not run a device operation.") }
}
@main struct AssaySurfaces:WidgetBundle {
    @WidgetBundleBuilder var body:some Widget {WorkbenchWidget(); VaultProgressWidget(); if #available(iOSApplicationExtension 18.0, *) {AssayOpenControl()} }
}
