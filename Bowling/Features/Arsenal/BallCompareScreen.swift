import BowlingCore
import BowlingData
import SwiftUI

/// Arsenal's Compare (spec §7, Arsenal 1b): the active balls side by side under the Stats
/// filter, as on ball detail. A column header sorts by it, again to flip it. The Columns
/// menu picks what shows: three columns by default on an iPhone, all of them with room.
/// At accessibility sizes each ball becomes a card and a Sort menu replaces the headers.
/// A row opens the ball.
struct BallCompareScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var table: BallCompareTable?
    @State private var sort = BallCompareTable.Sort()
    /// Nil until the bowler picks: the default for the width.
    @State private var picked: Set<BallCompareTable.Column>?
    @ScaledMetric(relativeTo: .subheadline) private var columnWidth: CGFloat = 58

    private struct LoadKey: Hashable {
        var revision: Int
        var filter: StatsFilterDraft?
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            if let table {
                if table.rows.isEmpty {
                    ContentUnavailableView("No balls to compare.", systemImage: "circle.circle")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AccessibilityText.filterChips(table.chips))
                                .font(.subheadline)
                                .foregroundStyle(.inkMuted)
                            if typeSize.isAccessibilitySize {
                                cards(table)
                            } else {
                                grid(table)
                            }
                            Text("Small numbers are the games, first balls, or spare attempts behind each figure.")
                                .font(.footnote)
                                .foregroundStyle(.inkMuted)
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { columnsMenu }
        }
        .task(id: LoadKey(revision: app.revision, filter: app.statsFilter)) { load() }
    }

    private func load() {
        guard let filter = StatsFilterDraft.current(app.statsFilter, in: app.store) else { return }
        table = BallCompareTable.load(store: app.store, filter: filter)
    }

    /// The picked columns in table order; three by default in compact width.
    private var columns: [BallCompareTable.Column] {
        let shown = picked ?? (sizeClass == .regular ? Set(BallCompareTable.Column.allCases) : [.average, .strikes, .spares])
        return BallCompareTable.Column.allCases.filter(shown.contains)
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(BallCompareTable.Column.allCases) { column in
                Toggle(column.title, isOn: Binding(
                    get: { columns.contains(column) },
                    set: { isOn in
                        var shown = Set(columns)
                        if isOn { shown.insert(column) } else { shown.remove(column) }
                        // At least one figure stays.
                        if !shown.isEmpty { picked = shown }
                    }
                ))
            }
        } label: {
            Label("Columns", systemImage: "tablecells")
        }
    }

    // MARK: Table

    private func grid(_ table: BallCompareTable) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                header(String(localized: "Ball"), key: .name, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(columns) { column in
                    header(column.title, key: .column(column), alignment: .trailing)
                        .frame(width: columnWidth, alignment: .trailing)
                }
                chevronSpace
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            ForEach(table.sorted(by: sort)) { row in
                Divider().overlay(Color.hairline)
                NavigationLink(value: ArsenalRoute.ball(row.id)) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.ink)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(columns) { column in
                            figure(row.cells[column])
                                .frame(width: columnWidth, alignment: .trailing)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.inkMuted)
                            .frame(width: 12)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
                .accessibilityAddTraits(.isButton)
            }
        }
        .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.hairline))
    }

    /// Keeps the headers over their figures, past the rows' chevrons.
    private var chevronSpace: some View {
        Color.clear.frame(width: 12, height: 1).accessibilityHidden(true)
    }

    private func header(_ title: String, key: BallCompareTable.SortKey, alignment: HorizontalAlignment) -> some View {
        let isSorted = sort.key == key
        return Button {
            sort = sort.tapping(key)
        } label: {
            HStack(spacing: 2) {
                if alignment == .trailing, isSorted { arrow }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSorted ? Color.accentText : Color.inkMuted)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                if alignment == .leading, isSorted { arrow }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("compare.header")
        .accessibilityValue(isSorted ? sortDescription : "")
        .accessibilityHint(Text("Sorts by this column."))
        .accessibilityAddTraits(isSorted ? [.isHeader, .isSelected] : .isHeader)
    }

    private var arrow: some View {
        Image(systemName: sort.ascending ? "chevron.up" : "chevron.down")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.accentText)
            .accessibilityHidden(true)
    }

    private var sortDescription: String {
        if sort.key == .name {
            sort.ascending ? String(localized: "Sorted A to Z") : String(localized: "Sorted Z to A")
        } else {
            sort.ascending ? String(localized: "Sorted low to high") : String(localized: "Sorted high to low")
        }
    }

    private func figure(_ cell: BallCompareTable.Cell?) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(cell?.value ?? "–")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.ink)
            if let sample = cell?.sample {
                Text(sample)
                    .font(.figure)
                    .foregroundStyle(.inkMuted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    // MARK: Cards

    /// One card per ball at accessibility sizes, where columns would break up the figures.
    private func cards(_ table: BallCompareTable) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Sort by", selection: Binding(get: { sort.key }, set: { sort = Sort(key: $0, ascending: $0 == .name) })) {
                Text("Ball").tag(BallCompareTable.SortKey.name)
                ForEach(BallCompareTable.Column.allCases) { Text($0.title).tag(BallCompareTable.SortKey.column($0)) }
            }
            .pickerStyle(.menu)
            ForEach(table.sorted(by: sort)) { row in
                NavigationLink(value: ArsenalRoute.ball(row.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.name).font(.headline).foregroundStyle(.ink)
                        ForEach(columns) { column in
                            let cell = row.cells[column]
                            VStack(alignment: .leading, spacing: 0) {
                                Text(column.title).font(.subheadline).foregroundStyle(.inkMuted)
                                Text([cell?.value ?? "–", cell?.sample].compactMap { $0 }.joined(separator: " · "))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.ink)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.hairline))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private typealias Sort = BallCompareTable.Sort
}

#if DEBUG
private struct BallComparePreview: View {
    @State private var app = AppModel.preview()

    var body: some View {
        NavigationStack { BallCompareScreen() }
            .environment(app)
    }
}

#Preview("Light") { BallComparePreview() }
#Preview("Dark") { BallComparePreview().preferredColorScheme(.dark) }
#Preview("AX5") { BallComparePreview().dynamicTypeSize(.accessibility5) }
#Preview("iPhone SE width") { BallComparePreview().frame(width: 320) }
#endif
