import BowlingCore
import BowlingData
import SwiftUI
import UIKit

/// A ball's photo in a circle, or a colored circle with its initial when it has none
/// (spec §7, Arsenal 1b). Decorative: the row's label carries the ball's name.
struct BallThumbnail: View {
    /// The no-photo circle. Its colors come from the ball's ID, so a ball keeps them across
    /// launches; `colorDescription` is free text and can't name a color reliably.
    struct Placeholder: Hashable {
        /// Index into `styles`.
        var style: Int
        var initial: String

        static let styleCount = 5

        init(id: BallID, name: String) {
            // UUID's hashValue is seeded per launch; its bytes are not.
            let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
            style = bytes.reduce(0) { $0 + Int($1) } % Self.styleCount
            initial = name.first.map { String($0).uppercased() } ?? ""
        }

        /// Fill and initial color. Each pair is a contrast-tested pair in ThemeTests.
        var colors: (fill: ColorResource, ink: ColorResource) {
            [(.accent, .onAccent), (.strike, .onStrike), (.accentSoft, .accentText),
             (.strikeSoft, .strikeText), (.cautionSoft, .cautionText)][style]
        }
    }

    @Environment(AppModel.self) private var app
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 44
    @State private var image: UIImage?

    var id: BallID
    var hasPhoto: Bool
    var placeholder: Placeholder

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(placeholder.initial)
                    .font(.headline)
                    .foregroundStyle(Color(placeholder.colors.ink))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(placeholder.colors.fill))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
        .task(id: PhotoKey(id: id, hasPhoto: hasPhoto, revision: app.revision)) {
            image = await thumbnail()
        }
    }

    private struct PhotoKey: Hashable {
        var id: BallID
        var hasPhoto: Bool
        var revision: Int
    }

    private func thumbnail() async -> UIImage? {
        guard hasPhoto, let data = try? app.store.balls.photo(for: id) else { return nil }
        guard let photo = UIImage(data: data), min(photo.size.width, photo.size.height) > 0 else { return nil }
        // Fills the circle at 3x, keeping the photo's aspect ratio.
        let scale = size * 3 / min(photo.size.width, photo.size.height)
        return await photo.byPreparingThumbnail(
            ofSize: CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        )
    }
}
