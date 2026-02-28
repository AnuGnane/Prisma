import XCTest
@testable import Prisma // Or the name of your target, adjust if needed

@MainActor
final class CargoGameViewModelTests: XCTestCase {

    var sut: CargoGameViewModel!

    override func setUp() {
        super.setUp()
        sut = CargoGameViewModel(level: 1) // Provide known state
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(sut.gameState, .inProgress)
        XCTAssertEqual(sut.placedPieceIds.count, 0)
        XCTAssertNil(sut.draggingPieceId)
        XCTAssertNil(sut.pendingPieceId)
    }

    func testDraggingStartsCorrectly() {
        let pieceId = sut.pieces.first!.id
        
        sut.beginDrag(pieceId: pieceId)
        
        XCTAssertEqual(sut.draggingPieceId, pieceId)
        XCTAssertNil(sut.ghostOrigin)
    }

    func testDropValidPieceBecomesPending() {
        let piece = sut.pieces.first!
        let validOrigin = sut.grid.validOrigins(for: piece).first!
        
        sut.beginDrag(pieceId: piece.id)
        sut.updateDragLocation(coord: validOrigin)
        sut.dropDraggingPiece()
        
        XCTAssertNil(sut.draggingPieceId)
        XCTAssertEqual(sut.pendingPieceId, piece.id)
        XCTAssertEqual(sut.pendingOrigin, validOrigin)
        XCTAssertTrue(sut.isAwaitingSubmit)
    }

    func testDropInvalidPieceCancelsPending() {
        let piece = sut.pieces.first!
        let invalidOrigin = CellCoord(99, 99) // Way out of bounds
        
        sut.beginDrag(pieceId: piece.id)
        sut.updateDragLocation(coord: invalidOrigin)
        sut.dropDraggingPiece()
        
        XCTAssertNil(sut.draggingPieceId)
        XCTAssertNil(sut.pendingPieceId)
        XCTAssertFalse(sut.isAwaitingSubmit)
    }

    func testSubmitPendingPiecePlacesIt() {
        let piece = sut.pieces.first!
        let validOrigin = sut.grid.validOrigins(for: piece).first!
        
        // Setup pending
        sut.beginDrag(pieceId: piece.id)
        sut.updateDragLocation(coord: validOrigin)
        sut.dropDraggingPiece()
        
        // Submit
        sut.submitPendingPiece()
        
        XCTAssertNil(sut.pendingPieceId)
        XCTAssertTrue(sut.placedPieceIds.contains(piece.id))
    }

    func testCancelDragFromOutsideGrid() {
        let pieceId = sut.pieces.first!.id
        sut.beginDrag(pieceId: pieceId)
        
        sut.cancelDrag()
        
        XCTAssertNil(sut.draggingPieceId)
        XCTAssertNil(sut.ghostOrigin)
        XCTAssertNil(sut.pendingPieceId)
    }

    func testDropPendingPieceInvalidRestoresLastValid() {
        let piece = sut.pieces.first!
        let validOrigin = sut.grid.validOrigins(for: piece).first!
        
        // Step 1: Make it pending on a valid spot
        sut.beginDrag(pieceId: piece.id)
        sut.updateDragLocation(coord: validOrigin)
        sut.dropDraggingPiece()
        
        XCTAssertEqual(sut.pendingOrigin, validOrigin)
        
        // Step 2: Pick it up again and drop it somewhere INVALID
        sut.beginDrag(pieceId: piece.id) // Picking up pending piece
        sut.updateDragLocation(coord: CellCoord(99, 99)) // Invalid
        sut.dropDraggingPiece()
        
        // Step 3: Verify it restored to the last valid position instead of disappearing
        XCTAssertEqual(sut.pendingPieceId, piece.id)
        XCTAssertEqual(sut.pendingOrigin, validOrigin)
    }

    func testCancelDragForPendingPieceRestoresLastValid() {
        let piece = sut.pieces.first!
        let validOrigin = sut.grid.validOrigins(for: piece).first!
        
        // Setup pending
        sut.beginDrag(pieceId: piece.id)
        sut.updateDragLocation(coord: validOrigin)
        sut.dropDraggingPiece()
        
        // Pick it up again
        sut.beginDrag(pieceId: piece.id)
        
        // Cancel the drag directly (e.g. dropped on background view)
        sut.cancelDrag()
        
        // Verify it restored
        XCTAssertEqual(sut.pendingPieceId, piece.id)
        XCTAssertEqual(sut.pendingOrigin, validOrigin)
    }

    func testTransformationOnPendingPiece() {
        let piece = sut.pieces.first!
        let initialRotation = piece.rotationSteps
        let initialFlip = piece.isFlipped
        
        let validOrigin = sut.grid.validOrigins(for: piece).first!
        sut.beginDrag(pieceId: piece.id)
        sut.updateDragLocation(coord: validOrigin)
        sut.dropDraggingPiece()
        
        sut.rotatePendingPiece()
        sut.flipPendingPiece()
        
        let updatedPiece = sut.piece(with: piece.id)!
        XCTAssertEqual(updatedPiece.rotationSteps, (initialRotation + 1) % 4)
        XCTAssertNotEqual(updatedPiece.isFlipped, initialFlip)
    }
}
