import Testing
@testable import Prisma
import Foundation

@MainActor
struct CargoGameViewModelTests {

    @Test("ViewModel initializes with correct fallback state")
    func testInitFallback() {
        let vm = CargoGameViewModel(level: 1)
        #expect(vm.gameState == .inProgress)
        #expect(vm.pieces.count == 4)
        #expect(vm.isDaily == false)
        #expect(!vm.showingSolution)
    }

    @Test("Drag and drop logic behaves correctly")
    func testValidDragAndDrop() {
        let vm = CargoGameViewModel(level: 1)
        #expect(vm.pendingPieceId == nil)
        
        vm.beginDrag(pieceId: 1)
        #expect(vm.draggingPieceId == 1)
        
        // Drop ghost somewhere
        vm.updateDragLocation(coord: CellCoord(1, 1))
        #expect(vm.ghostOrigin != nil)
        
        vm.dropDraggingPiece()
        
        // It becomes pending if it can be placed.
        #expect(vm.pendingPieceId != nil, "Piece should be pending after valid drop")
        
        vm.submitPendingPiece()
        #expect(vm.isPiecePlaced(id: 1))
        #expect(vm.undoCount == 0)
        
        vm.undoLastPlacement()
        #expect(!vm.isPiecePlaced(id: 1))
        #expect(vm.undoCount == 1)
    }
}
