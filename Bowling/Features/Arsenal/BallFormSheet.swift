import BowlingCore
import BowlingData
import PhotosUI
import SwiftUI

/// Arsenal's Add ball and Edit ball (spec §7, Arsenal 1b): every ball field in Identity,
/// Construction, Use, and Notes, the photo, and on edit Retire and Delete. Save stays off
/// until a name, a weight, and valid numbers are set; a refused save keeps the sheet.
struct BallFormSheet: View {
    @Environment(AppModel.self) private var app
    @State private var form: BallForm
    @State private var storedPhoto: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var photoError = false
    @State private var isConfirmingDelete = false
    @State private var retireInstead: String?

    init(target: BallFormTarget, store: BowlingStore) {
        switch target {
        case .add:
            _form = State(initialValue: BallForm())
        case .edit(let id):
            // The Arsenal row was just loaded; a ball deleted meanwhile opens an empty form.
            let detail = try? store.balls.detail(for: id)
            _form = State(initialValue: detail.map { BallForm(editing: id, detail: $0) } ?? BallForm())
            _storedPhoto = State(initialValue: (try? store.balls.photo(for: id)).flatMap(UIImage.init(data:)))
        }
    }

    var body: some View {
        NavigationStack {
            fieldsForm
                .navigationTitle(form.editing == nil ? "Add ball" : "Edit ball")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .onChange(of: pickedItem) { _, item in
                    Task { await load(item) }
                }
                .confirmationDialog(
                    "Delete this ball? Its photo and maintenance log are deleted too.",
                    isPresented: $isConfirmingDelete, titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) { form.editing.map(delete) }
                }
                .alert("Can't delete this ball", isPresented: isOfferingRetire) {
                    Button("Retire") { form.editing.map(retire) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(retireInstead ?? "")
                }
        }
    }

    private var fieldsForm: some View {
        Form {
            identity
            construction
            use
            notes
            if let id = form.editing {
                manage(id)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { app.ballForm = nil }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(!form.canSave)
        }
    }

    private var isOfferingRetire: Binding<Bool> {
        Binding(get: { retireInstead != nil }, set: { if !$0 { retireInstead = nil } })
    }

    // MARK: Sections

    private var identity: some View {
        Section("Identity") {
            photoRow
            TextField("Name", text: $form.name)
                .textInputAutocapitalization(.words)
            TextField("Brand", text: $form.brand)
                .textInputAutocapitalization(.words)
            Picker("Weight", selection: $form.weightPounds) {
                if form.editing == nil {
                    Text("Choose").tag(Int?.none)
                }
                ForEach(6...16, id: \.self) { pounds in
                    Text("\(pounds) lb").tag(Int?.some(pounds))
                }
            }
            TextField("Color", text: $form.colorDescription)
            TextField("Serial number", text: $form.serialNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
        .listRowBackground(Color.surface)
    }

    private var construction: some View {
        Section("Construction") {
            Picker("Coverstock", selection: $form.coverstock) {
                ForEach(Coverstock.allCases, id: \.self) { Text(BallForm.title(for: $0)).tag($0) }
            }
            TextField("Coverstock name", text: $form.coverstockName)
            Picker("Core type", selection: $form.coreType) {
                ForEach(CoreType.allCases, id: \.self) { Text(BallForm.title(for: $0)).tag($0) }
            }
            TextField("Core name", text: $form.coreName)
            number("RG", text: $form.rg, field: .rg)
            number("Differential", text: $form.differential, field: .differential)
            if form.coreType == .asymmetric {
                number("Intermediate differential", text: $form.intermediateDifferential, field: .intermediateDifferential)
            }
            TextField("Factory finish", text: $form.factoryFinish)
            optionalDate(String(localized: "Release date"), add: String(localized: "Add release date"),
                         date: $form.releaseDate, range: nil)
        }
        .listRowBackground(Color.surface)
    }

    private var use: some View {
        Section("Use") {
            Picker("Role", selection: $form.intendedRole) {
                ForEach([BallRole.strike, .spare, .both], id: \.self) { role in
                    Text(ArsenalList.roleTitle(role) ?? "").tag(role)
                }
            }
            .pickerStyle(.segmented)
            optionalDate(String(localized: "Purchase date"), add: String(localized: "Add purchase date"),
                         date: $form.purchaseDate, range: ...Date.now)
            LabeledContent("Current surface") {
                TextField("Current surface", text: $form.surfaceGrit,
                          prompt: form.editing == nil ? Text("Same as factory finish") : nil)
                    .multilineTextAlignment(.trailing)
            }
            number("Resurface every … games", text: $form.resurfaceInterval, field: .resurfaceInterval,
                   keyboard: .numberPad)
        }
        .listRowBackground(Color.surface)
    }

    private var notes: some View {
        Section("Notes") {
            TextField("Notes", text: $form.notes, axis: .vertical)
                .lineLimit(3...)
        }
        .listRowBackground(Color.surface)
    }

    private func manage(_ id: BallID) -> some View {
        Section {
            if form.isRetired {
                Button("Return to arsenal") { run { try app.setBallRetired(id, false) } }
            } else {
                Button("Retire ball") { retire(id) }
            }
            Button("Delete ball", role: .destructive) { isConfirmingDelete = true }
        }
        .listRowBackground(Color.surface)
    }

    // MARK: Rows

    private var photoRow: some View {
        let pickTitle = hasPhoto ? String(localized: "Change photo") : String(localized: "Choose photo")
        return HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 8) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Text(pickTitle)
                }
                if hasPhoto {
                    Button("Remove photo", role: .destructive) {
                        form.photo = .removed
                        pickedItem = nil
                    }
                }
                if photoError {
                    Text("Couldn't use that photo.")
                        .font(.footnote)
                        .foregroundStyle(.cautionText)
                }
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var thumbnail: some View {
        let image: UIImage? = switch form.photo {
        case .set(let data): UIImage(data: data)
        case .removed: nil
        case .unchanged: storedPhoto
        }
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                // On add there's no ID yet, so the first style stands in.
                let placeholder = form.editing.map { BallThumbnail.Placeholder(id: $0, name: form.name) }
                Text(placeholder?.initial ?? form.name.first.map { String($0).uppercased() } ?? "")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Color(placeholder?.colors.ink ?? .onAccent))
                    .background(Color(placeholder?.colors.fill ?? .accent))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var hasPhoto: Bool {
        switch form.photo {
        case .set: true
        case .removed: false
        case .unchanged: storedPhoto != nil
        }
    }

    private func number(_ title: LocalizedStringKey, text: Binding<String>, field: BallForm.NumberField,
                        keyboard: UIKeyboardType = .decimalPad) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                TextField(title, text: text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
            }
            if let error = form.fieldError(field) {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.cautionText)
            }
        }
    }

    /// "Add …" until set; then the picker and a clear button.
    @ViewBuilder
    private func optionalDate(_ title: String, add: String, date: Binding<Date?>,
                              range: PartialRangeThrough<Date>?) -> some View {
        if let value = date.wrappedValue {
            let binding = Binding(get: { value }, set: { date.wrappedValue = $0 })
            HStack {
                if let range {
                    DatePicker(title, selection: binding, in: range, displayedComponents: .date)
                } else {
                    DatePicker(title, selection: binding, displayedComponents: .date)
                }
                Button {
                    date.wrappedValue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Clear \(title)"))
            }
        } else {
            Button(add) { date.wrappedValue = Calendar.current.startOfDay(for: .now) }
        }
    }

    // MARK: Actions

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let data = try? await item.loadTransferable(type: Data.self)
        if let photo = data.flatMap(BallPhoto.downscaled) {
            form.photo = .set(photo)
            photoError = false
        } else {
            photoError = true
        }
    }

    private func retire(_ id: BallID) {
        run { try app.setBallRetired(id, true) }
    }

    private func save() {
        run { try app.saveBall(form) }
    }

    private func delete(_ id: BallID) {
        do {
            try app.deleteBall(id)
        } catch let error as RepositoryError {
            if case .ballHasGames = error {
                retireInstead = ErrorText.message(for: error)
            } else {
                app.error = error
            }
        } catch {
            app.error = error
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct BallFormSheetPreview: View {
    @State private var app = AppModel.preview()
    var target: (BowlingStore) -> BallFormTarget

    var body: some View {
        BallFormSheet(target: target(app.store), store: app.store)
            .environment(app)
    }

    /// The demo's first ball with every field filled.
    static func filled(retired: Bool = false) -> (BowlingStore) -> BallFormTarget {
        { store in
            let ball = try! store.balls.addBall(BallFields(
                name: "Phaze II", brand: "Storm", weightPounds: 15, coverstock: .reactiveSolid,
                coverstockName: "TX-16", coreType: .asymmetric, coreName: "Velocity", rg: 2.48,
                differential: 0.051, intermediateDifferential: 0.015, colorDescription: "Pine/Silver",
                purchaseDate: .now, factoryFinish: "1500 Polished", resurfaceIntervalGames: 60
            ))
            if retired { try! store.balls.setRetired(true, for: ball.id) }
            return .edit(ball.id)
        }
    }
}

#Preview("Add, light") { BallFormSheetPreview { _ in .add } }
#Preview("Add, dark") { BallFormSheetPreview { _ in .add }.preferredColorScheme(.dark) }
#Preview("Add, AX5") { BallFormSheetPreview { _ in .add }.dynamicTypeSize(.accessibility5) }
#Preview("Edit, light") { BallFormSheetPreview(target: BallFormSheetPreview.filled()) }
#Preview("Edit, dark") { BallFormSheetPreview(target: BallFormSheetPreview.filled()).preferredColorScheme(.dark) }
#Preview("Edit, AX5") { BallFormSheetPreview(target: BallFormSheetPreview.filled()).dynamicTypeSize(.accessibility5) }
#Preview("Edit, retired") { BallFormSheetPreview(target: BallFormSheetPreview.filled(retired: true)) }
#endif
