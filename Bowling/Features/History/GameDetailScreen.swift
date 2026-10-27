import BowlingCore
import BowlingData
import SwiftUI

/// One game (spec §3): the full scorecard, each frame's leave, the balls used, Edit into
/// Scoring on this game, and Delete game with the same confirmation as the swipe.
struct GameDetailScreen: View {
    @Environment(AppModel.self) private var app
    let id: GameID
    @State private var data: GameDetailData?
    @State private var isDeleted = false
    @State private var pendingDelete: DeleteRequest?

    var body: some View {
        Group {
            if isDeleted {
                RecordDeletedView(message: "This game was deleted.")
            } else if let data {
                list(data)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .navigationTitle(isDeleted ? "" : data?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let data, !isDeleted {
                Button("Edit") { app.scoring = data.editTarget }
            }
        }
        .deleteConfirmation($pendingDelete)
        .task(id: app.revision) { reload() }
    }

    private func list(_ data: GameDetailData) -> some View {
        List {
            Section {
                ScorecardStrip(scorecard: data.scorecard, currentFrame: nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            .listRowBackground(Color.surface)
            leaves(data.leaves)
            if !data.ballsUsed.isEmpty {
                Section("Balls used") {
                    ForEach(data.ballsUsed) { use in
                        Text(use.text)
                            .foregroundStyle(Color.ink)
                            .accessibilityLabel(AccessibilityText.ballUse(use))
                    }
                }
                .listRowBackground(Color.surface)
            }
            Section {
                Button("Delete game", role: .destructive) { pendingDelete = data.deleteRequest }
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
    }

    /// Diagrams wrap into rows, so they stack at accessibility sizes. Each reads as
    /// "Frame 3, Leave 7, 10, split".
    @ViewBuilder private func leaves(_ leaves: GameDetailData.Leaves) -> some View {
        switch leaves {
        case .frames(let frames):
            Section("Leaves") {
                if frames.isEmpty {
                    Text("No leaves").foregroundStyle(Color.inkMuted)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), alignment: .top)], alignment: .leading, spacing: 12) {
                        ForEach(frames) { frame in
                            VStack(spacing: 4) {
                                Text("\(frame.frameIndex)").monoLabel()
                                LeaveDiagramView(leave: frame.leave, size: .small)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                String(localized: "Frame \(frame.frameIndex)") + ", " + AccessibilityText.leave(frame.leave)
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(Color.surface)
        case .enterPins:
            Section("Leaves") {
                Text("Enter pins to see leaves.").foregroundStyle(Color.inkMuted)
            }
            .listRowBackground(Color.surface)
        case .hidden:
            EmptyView()
        }
    }

    /// Ball names come from the active balls; a retired one reads "Deleted ball" until
    /// #106's `detail(for:)` is used. A missing game shows the deleted state, unless this
    /// screen is already being popped after its own delete.
    private func reload() {
        let store = app.store
        let balls = store.balls.activeBalls()
        do {
            data = try GameDetailData.load(id, from: store, ballName: { id in balls.first { $0.id == id }?.name })
            isDeleted = false
        } catch RepositoryError.notFound {
            if app.historyPath.contains(.game(id)) { isDeleted = true }
        } catch {
            app.error = error
        }
    }
}

#if DEBUG
private struct GameDetailScreenPreview: View {
    /// A pin-by-pin game when the demo has one, so the leaves grid shows.
    @State private var app: AppModel = {
        let app = AppModel.preview()
        let store = app.store
        let games = store.sessions.sessions().flatMap { session in
            ((try? store.sessions.session(session.id).bowlers) ?? []).flatMap(\.games)
        }
        if let game = games.first(where: { $0.entryMode == .pinByPin }) ?? games.first, let session = game.sessionID {
            app.historyPath = [.session(session), .game(game.id)]
        }
        return app
    }()

    var body: some View {
        HistoryStack()
            .environment(app)
    }
}

#Preview("Light") { GameDetailScreenPreview() }
#Preview("Dark") { GameDetailScreenPreview().preferredColorScheme(.dark) }
#Preview("AX5") { GameDetailScreenPreview().dynamicTypeSize(.accessibility5) }
#endif
