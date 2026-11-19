import Foundation

/// Starting points for a drawing, not a list of apps installed on this iPhone.
enum LayoutStarter: String, CaseIterable, Identifiable {
    case work="Work", sleep="Sleep", travel="Travel", research="Research", minimal="Minimal", onePage="One page", colour="Colour flow"
    var id:String { rawValue }
    var recipe: LayoutRecipe {
        var p=LayoutRecipe();p.page=rawValue
        switch self {
        case .work:p.purpose="Keep the centre free for the wallpaper";p.focus = .middle;p.widget = .medium;p.appLines="Calendar\nMail\nFiles\nNotes"
        case .sleep:p.purpose="Quiet evening page";p.focus = .top;p.widget = .none;p.appLines="Clock\nBooks"
        case .travel:p.purpose="Tickets and directions";p.focus = .top;p.widget = .small;p.appLines="Maps\nWallet\nWeather\nTranslate\nCamera"
        case .research:p.purpose="Reference and capture";p.focus = .bottom;p.widget = .medium;p.appLines="Assay\nFiles\nNotes\nSafari\nShortcuts"
        case .minimal:p.purpose="Two essentials";p.focus = .middle;p.widget = .none;p.appLines="Messages\nMaps"
        case .onePage:p.purpose="Everyday apps on one page";p.focus = .bottom;p.widget = .small;p.appLines="Mail\nCalendar\nCamera\nNotes\nMaps\nFiles\nMusic\nBooks"
        case .colour:p.purpose="Order labels to match your chosen icon colours";p.focus = .middle;p.widget = .none;p.appLines="Music\nBooks\nHome\nMessages\nMail\nPodcasts"
        };return p
    }
}
