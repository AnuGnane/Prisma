//
//  ShareCardTests.swift
//  PrismaTests
//
//  Tests for ShareCardRenderer — verifies that ImageRenderer produces
//  a correctly-sized, non-nil image from a ShareCardView.
//
//  These are lightweight integration tests, not pixel-level snapshots.
//  Pixel comparisons would be brittle across OS/font versions; we instead
//  assert the contract: "renderer returns a valid image at the expected
//  dimensions."
//

import Foundation
import Testing
import UIKit
@testable import Prisma

@MainActor
struct ShareCardRendererTests {

    // MARK: - Helpers

    private func makeFiveResults() -> [GameResult] {
        [
            GameResult(gameType: .signals,  score: 900, shareString: "", guessCount: 3,  isDaily: true, durationSeconds: 0),
            GameResult(gameType: .archive,  score: 800, shareString: "", guessCount: 1,  isDaily: true, durationSeconds: 0),
            GameResult(gameType: .cargo,    score: 870, shareString: "", guessCount: 0,  isDaily: true, durationSeconds: 47),
            GameResult(gameType: .shift,    score: 750, shareString: "", guessCount: 12, isDaily: true, durationSeconds: 68),
            GameResult(gameType: .circuit,  score: 960, shareString: "", guessCount: 24, isDaily: true, durationSeconds: 95),
        ]
    }

    // MARK: - Tests

    @Test func rendererProducesNonNilImage() {
        let image = ShareCardRenderer.render(results: makeFiveResults())
        #expect(image != nil, "ShareCardRenderer must return a non-nil UIImage")
    }

    @Test func renderedImageHasExpectedWidth() {
        guard let image = ShareCardRenderer.render(results: makeFiveResults()) else {
            Issue.record("Renderer returned nil")
            return
        }
        let expectedWidth = ShareCardRenderer.canvasSize.width * ShareCardRenderer.renderScale
        #expect(
            image.size.width == expectedWidth,
            "Expected image width \(expectedWidth) px, got \(image.size.width) px"
        )
    }

    @Test func renderedImageHasExpectedHeight() {
        guard let image = ShareCardRenderer.render(results: makeFiveResults()) else {
            Issue.record("Renderer returned nil")
            return
        }
        let expectedHeight = ShareCardRenderer.canvasSize.height * ShareCardRenderer.renderScale
        #expect(
            image.size.height == expectedHeight,
            "Expected image height \(expectedHeight) px, got \(image.size.height) px"
        )
    }

    @Test func rendererHandlesEmptyResults() {
        // Edge case: no results — renderer must not crash
        let image = ShareCardRenderer.render(results: [])
        #expect(image != nil, "ShareCardRenderer must not crash on empty results")
    }

    @Test func rendererHandlesPartialResults() {
        // Only 3 games played — remaining rows show "—"
        let partial: [GameResult] = [
            GameResult(gameType: .signals, score: 800, shareString: "", guessCount: 2, isDaily: true),
            GameResult(gameType: .archive, score: 700, shareString: "", guessCount: 3, isDaily: true),
            GameResult(gameType: .cargo,   score: 850, shareString: "", guessCount: 0, isDaily: true, durationSeconds: 55),
        ]
        let image = ShareCardRenderer.render(results: partial)
        #expect(image != nil)
    }

    @Test func shareableImageConformance() throws {
        guard let uiImage = ShareCardRenderer.render(results: makeFiveResults()) else {
            Issue.record("Renderer returned nil")
            return
        }
        let shareable = ShareableImage(image: uiImage)
        // The wrapped UIImage must round-trip through PNG data
        let pngData = uiImage.pngData()
        #expect(pngData != nil, "UIImage must produce valid PNG data")
        #expect(shareable.image.size == uiImage.size)
    }
}
