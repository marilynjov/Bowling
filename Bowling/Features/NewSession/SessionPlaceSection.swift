import BowlingCore
import BowlingData
import SwiftUI

/// Center, league (league nights only, filtered by the center), oil pattern, and lanes.
/// Shared by New session and the session details form so both rows read the same.
struct SessionPlaceSection: View {
    @Environment(AppModel.self) private var app
    @Binding var details: SessionDetailsDraft
    let centers: [NamedRef]
    let leagues: [LeagueRecord]
    let oilPatterns: [NamedRef]

    var body: some View {
        Section {
            NavigationLink {
                NamedRefPicker(title: "Center", items: centers, selection: $details.centerID) { name in
                    try app.write { try $0.sessions.createCenter(name: name) }
                }
            } label: {
                LabeledContent("Center", value: name(of: details.centerID, in: centers))
            }
            if details.eventType == .league {
                NavigationLink {
                    NamedRefPicker(title: "League", items: details.leagues(from: leagues), selection: $details.leagueID) { name in
                        let centerID = details.centerID
                        return try app.write { try $0.sessions.createLeague(name: name, centerID: centerID) }
                    }
                } label: {
                    LabeledContent("League", value: name(of: details.leagueID, in: leagues))
                }
            }
            NavigationLink {
                NamedRefPicker(title: "Oil pattern", items: oilPatterns, selection: $details.oilPatternID) { name in
                    try app.write { try $0.sessions.createOilPattern(name: name) }
                }
            } label: {
                LabeledContent("Oil pattern", value: name(of: details.oilPatternID, in: oilPatterns))
            }
            LabeledContent("Lanes") {
                TextField("Lanes", text: $details.lanes, prompt: Text("13–14"))
                    .multilineTextAlignment(.trailing)
            }
        }
        .listRowBackground(Color.surface)
    }

    private func name(of id: UUID?, in items: [some NamedItem]) -> String {
        items.first { $0.id == id }?.name ?? "None"
    }
}
