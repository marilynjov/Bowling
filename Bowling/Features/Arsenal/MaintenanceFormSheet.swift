import BowlingCore
import BowlingData
import SwiftUI

/// Ball detail's Log maintenance (spec §7 "Ball detail", Maintenance): kind, date, the
/// surface after a resurface or polish, and notes. A refused save keeps the sheet.
struct MaintenanceFormSheet: View {
    @Environment(AppModel.self) private var app
    @State private var draft = MaintenanceDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(MaintenanceDraft.kinds, id: \.self) { kind in
                            Text(BallDetailData.kindTitle(kind)).tag(kind)
                        }
                    }
                    DatePicker("Date", selection: $draft.date, in: ...Date.now, displayedComponents: .date)
                    if draft.takesGrit {
                        LabeledContent("Surface after") {
                            TextField("Surface after", text: $draft.surfaceGrit, prompt: Text("e.g. 2000 Abralon"))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } footer: {
                    if draft.takesGrit {
                        Text("Becomes the ball's current surface.")
                    }
                }
                .listRowBackground(Color.surface)
                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Log maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.loggingMaintenance = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try app.logMaintenance(draft) } catch { app.error = error }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let app = AppModel.preview()
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MaintenanceFormSheet().environment(app)
        }
}
#endif
