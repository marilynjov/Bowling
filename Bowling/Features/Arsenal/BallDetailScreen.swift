import BowlingCore
import BowlingData
import Charts
import SwiftUI
#if DEBUG
import BowlingFixtures
#endif

/// A ball's page (spec §7 "Ball detail"): header, specs, maintenance (read-only until
/// #32), performance under the Stats filter (chips read-only until #33), by condition,
/// strike % over time with maintenance markers, and recent games.
struct BallDetailScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var data: BallDetailData?

    var id: BallID

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            if let data {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header(data)
                        if !data.specs.isEmpty { specs(data.specs) }
                        maintenance(data.maintenance)
                        performance(data)
                        conditions(String(localized: "By pattern"), data.byPattern)
                        conditions(String(localized: "By center"), data.byCenter)
                        overTime(data.trend, empty: data.overTimeEmptyText)
                        if !data.recent.isEmpty { recent(data.recent) }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(data?.header.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { app.ballForm = .edit(id) }
            }
        }
        // The Stats filter changes without a write, so it is part of the key: a ball detail
        // left open on Arsenal follows a filter changed on Stats.
        .task(id: LoadKey(revision: app.revision, filter: app.statsFilter)) { load() }
    }

    private struct LoadKey: Hashable {
        var revision: Int
        var filter: StatsFilterDraft?
    }

    /// One column at accessibility sizes, so long tile titles don't break up, as on Home.
    static func tileColumns(isAccessibilitySize: Bool) -> [GridItem] {
        isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 8), GridItem(.flexible())]
    }

    private func load() {
        guard let filter = StatsFilterDraft.current(app.statsFilter, in: app.store) else { return }
        do {
            data = try BallDetailData.load(id: id, store: app.store, filter: filter)
        } catch RepositoryError.notFound {
            // Deleted from Edit: back to the list.
            dismiss()
        } catch {
            app.error = error
        }
    }

    // MARK: Sections

    private func header(_ data: BallDetailData) -> some View {
        let header = data.header
        return VStack(alignment: .leading, spacing: 12) {
            BallThumbnail(id: id, hasPhoto: data.hasPhoto,
                          placeholder: BallThumbnail.Placeholder(id: id, name: header.name), size: 96)
                .saturation(header.isRetired ? 0 : 1)
                // An image, so capping its growth hides no text; uncapped it reaches ~300 pt at AX5.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(header.name).font(.title2.weight(.bold))
                    if header.isRetired {
                        Text("Retired")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.inkMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.inset, in: .capsule)
                    }
                }
                Group {
                    Text(header.subtitle)
                    ForEach([header.construction, header.role, header.surface, header.serial].compactMap { $0 }, id: \.self) {
                        Text($0)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func specs(_ rows: [BallDetailData.SpecRow]) -> some View {
        Card(String(localized: "Specs")) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(Color.hairline) }
                LabeledContent(row.label, value: row.value)
                    .font(.subheadline)
            }
        }
    }

    private func maintenance(_ m: BallDetailData.Maintenance) -> some View {
        Card(String(localized: "Maintenance")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(m.summary).font(.subheadline.weight(.semibold))
                if let progress = m.progress {
                    ProgressView(value: progress)
                        .tint(m.isDue ? .caution : .accent)
                }
                if m.isDue { ResurfaceDueBadge() }
            }
            .accessibilityElement(children: .combine)
            if m.log.isEmpty {
                Text("No maintenance logged.").font(.subheadline).foregroundStyle(.inkMuted)
            } else {
                ForEach(Array(m.log.enumerated()), id: \.offset) { _, row in
                    Divider().overlay(Color.hairline)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(row.date).font(.figure).foregroundStyle(.inkMuted)
                        }
                        if let detail = row.detail {
                            Text(detail).font(.subheadline).foregroundStyle(.inkMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder private func performance(_ data: BallDetailData) -> some View {
        chips(data.chips)
        if data.performance.isEmpty {
            Text("No games with this ball in this filter.")
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
        } else {
            ForEach(data.performance, id: \.title) { block in
                VStack(alignment: .leading, spacing: 8) {
                    // Side by side when they fit; stacked at large text sizes.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(block.title).monoLabel().fixedSize()
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            Text(block.sample).font(.figure).foregroundStyle(.inkMuted).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.title).monoLabel()
                                .accessibilityAddTraits(.isHeader)
                            Text(block.sample).font(.figure).foregroundStyle(.inkMuted)
                        }
                    }
                    if let empty = block.emptyText {
                        Text(empty).font(.subheadline).foregroundStyle(.inkMuted)
                    } else {
                        LazyVGrid(columns: Self.tileColumns(isAccessibilitySize: typeSize.isAccessibilitySize), spacing: 8) {
                            ForEach(block.tiles, id: \.title) { StatTile($0) }
                        }
                    }
                }
            }
            if !data.leaves.isEmpty {
                Card(String(localized: "Leaves")) { LeavesCard(rows: data.leaves) }
            }
        }
    }

    /// The Stats filter, read-only until #33 makes the chips editable.
    /// Scrolls sideways at regular sizes; stacked at accessibility sizes, where a chip
    /// alone can be wider than the screen.
    @ViewBuilder private func chips(_ chips: [String]) -> some View {
        let row = ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
            Text(chip)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.surface, in: .capsule)
                .overlay(Capsule().stroke(.hairline))
        }
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { row }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { row.lineLimit(1) }
                }
            }
        }
        // Read as one element that says what the chips are: "Filter: All time, All games, Sam".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.filterChips(chips))
    }

    @ViewBuilder
    private func conditions(_ title: String, _ rows: [BallDetailData.ConditionRowText]) -> some View {
        if !rows.isEmpty {
            Card(title) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(Color.hairline) }
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(row.name).font(.subheadline)
                            Spacer()
                            Text(row.strikes).font(.figure)
                            Text(row.firstBallAverage).font(.figure).foregroundStyle(.inkMuted)
                        }
                        VStack(alignment: .leading) {
                            Text(row.name).font(.subheadline)
                            Text("\(row.strikes) · \(row.firstBallAverage)").font(.figure)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "\(row.name), strikes \(row.strikes), first ball average \(row.firstBallAverage)"))
                }
            }
        }
    }

    private func overTime(_ trend: BallDetailData.Trend?, empty: String) -> some View {
        Card(String(localized: "Over time")) {
            if let trend {
                Chart {
                    ForEach(trend.markers, id: \.self) { marker in
                        RuleMark(x: .value("Date", marker.date))
                            .foregroundStyle(Color.inkMuted)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: marker.isResurface ? [] : [4, 3]))
                    }
                    ForEach(trend.points, id: \.self) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Strike %", point.percent))
                            .foregroundStyle(Color.accent)
                        PointMark(x: .value("Date", point.date), y: .value("Strike %", point.percent))
                            .foregroundStyle(Color.accent)
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(trend.accessibilityLabel)
            } else {
                Text(empty).font(.subheadline).foregroundStyle(.inkMuted)
            }
        }
    }

    private func recent(_ games: [BallDetailData.RecentGame]) -> some View {
        Card(String(localized: "Recent games")) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                if index > 0 { Divider().overlay(Color.hairline) }
                Button {
                    app.historyPath = [.game(game.id)]
                    app.selectedTab = .history
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.date).font(.subheadline)
                            Text(game.eventType).font(.footnote).foregroundStyle(.inkMuted)
                        }
                        Spacer()
                        Text(game.score).font(.frameTotal)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.inkMuted)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A Surface card under a mono title, as on Stats.
private struct Card<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).monoLabel()
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.hairline))
    }
}

#if DEBUG
private struct BallDetailPreview: View {
    @State private var app = AppModel.preview()
    var ball: (BowlingStore) -> BallID

    var body: some View {
        NavigationStack { BallDetailScreen(id: ball(app.store)) }
            .environment(app)
    }

    static let demo: (BowlingStore) -> BallID = { _ in DemoBall.ownerStrike.id }
    static let new: (BowlingStore) -> BallID = { try! $0.balls.addBall(BallFields(name: "Phaze II", weightPounds: 15)).id }
    static let retired: (BowlingStore) -> BallID = { store in
        let id = try! store.balls.addBall(BallFields(name: "Black Widow", brand: "Hammer", weightPounds: 15)).id
        try! store.balls.setRetired(true, for: id)
        return id
    }
}

#Preview("Demo, light") { BallDetailPreview(ball: BallDetailPreview.demo) }
#Preview("Demo, dark") { BallDetailPreview(ball: BallDetailPreview.demo).preferredColorScheme(.dark) }
#Preview("Demo, AX5") { BallDetailPreview(ball: BallDetailPreview.demo).dynamicTypeSize(.accessibility5) }
#Preview("New, light") { BallDetailPreview(ball: BallDetailPreview.new) }
#Preview("New, dark") { BallDetailPreview(ball: BallDetailPreview.new).preferredColorScheme(.dark) }
#Preview("New, AX5") { BallDetailPreview(ball: BallDetailPreview.new).dynamicTypeSize(.accessibility5) }
#Preview("Retired, light") { BallDetailPreview(ball: BallDetailPreview.retired) }
#Preview("Retired, dark") { BallDetailPreview(ball: BallDetailPreview.retired).preferredColorScheme(.dark) }
#Preview("Retired, AX5") { BallDetailPreview(ball: BallDetailPreview.retired).dynamicTypeSize(.accessibility5) }
#endif
