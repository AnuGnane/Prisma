//
//  ShareCardRenderer.swift
//  Prisma
//
//  Renders a ShareCardView to a UIImage using ImageRenderer.
//  Call from a MainActor context (e.g. a button action in a SwiftUI view).
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ShareCardRenderer

@MainActor
enum ShareCardRenderer {

    /// Canvas size matches the fixed dimensions declared in ShareCardView.
    static let canvasSize = CGSize(width: 400, height: 520)

    /// Render scale — 3× produces a 1200 × 1560 px image suitable for sharing.
    static let renderScale: CGFloat = 3

    /// Renders the share card for the given game results.
    /// Returns `nil` only if `ImageRenderer` fails (extremely rare in practice).
    static func render(results: [GameResult]) -> UIImage? {
        let renderer = ImageRenderer(content:
            ShareCardView(results: results)
        )
        renderer.scale = renderScale
        renderer.proposedSize = .init(canvasSize)
        return renderer.uiImage
    }
}

// MARK: - Transferable wrapper

/// `Image` can be shared directly via `ShareLink(item:)`, but to expose the
/// underlying `UIImage` for the system share sheet we use this wrapper.
struct ShareableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shareable in
            shareable.image.pngData() ?? Data()
        }
    }
}
