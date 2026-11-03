import BowlingData
import Foundation
import Testing
import UIKit
@testable import Bowling

@Suite struct BallPhotoTests {
    /// A solid JPEG of `width`×`height` pixels.
    private func jpeg(_ width: CGFloat, _ height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    private func pixels(_ data: Data) throws -> CGSize {
        let image = try #require(UIImage(data: data))
        return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    @Test func largePhotoScalesTo1024() throws {
        let data = try #require(BallPhoto.downscaled(jpeg(4000, 3000)))
        #expect(try pixels(data) == CGSize(width: 1024, height: 768))
        #expect(data.count <= BallRepository.maxPhotoBytes)
    }

    @Test func smallPhotoKeepsItsSize() throws {
        let data = try #require(BallPhoto.downscaled(jpeg(500, 400)))
        #expect(try pixels(data) == CGSize(width: 500, height: 400))
    }

    @Test func panoramaScalesByLongestSide() throws {
        let data = try #require(BallPhoto.downscaled(jpeg(12000, 1000)))
        let size = try pixels(data)
        #expect(size.width == 1024)
        #expect(abs(size.height - 85) <= 1)
        #expect(data.count <= BallRepository.maxPhotoBytes)
    }

    @Test func nonImageIsRejected() {
        #expect(BallPhoto.downscaled(Data("hello".utf8)) == nil)
    }
}
