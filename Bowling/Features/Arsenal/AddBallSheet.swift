import BowlingCore
import SwiftUI

/// Arsenal's Add ball (spec §2): name, brand, weight, and role. Save stays off until a
/// name and a weight are set; a refused save keeps the sheet and its values.
struct AddBallSheet: View {
    @Environment(AppModel.self) private var app
    @State private var draft = BallDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    TextField("Brand", text: $draft.brand)
                        .textInputAutocapitalization(.words)
                }
                .listRowBackground(Color.surface)

                Section {
                    Picker("Weight", selection: $draft.weightPounds) {
                        Text("Choose").tag(Int?.none)
                        ForEach(6...16, id: \.self) { pounds in
                            Text("\(pounds) lb").tag(Int?.some(pounds))
                        }
                    }
                    Picker("Role", selection: $draft.role) {
                        ForEach([BallRole.strike, .spare, .both], id: \.self) { role in
                            Text(ArsenalList.roleTitle(role) ?? "").tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Add ball")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.isAddingBall = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave)
                }
            }
        }
    }

    private func save() {
        do {
            _ = try app.write { try draft.save(to: $0) }
            app.isAddingBall = false
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
#Preview("Light") {
    AddBallSheet().environment(AppModel.preview())
}
#Preview("Dark") {
    AddBallSheet().environment(AppModel.preview()).preferredColorScheme(.dark)
}
#Preview("AX5") {
    AddBallSheet().environment(AppModel.preview()).dynamicTypeSize(.accessibility5)
}
#endif
