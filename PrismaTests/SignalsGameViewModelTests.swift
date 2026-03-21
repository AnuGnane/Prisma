import Testing
@testable import Prisma
import Foundation

@MainActor
struct SignalsGameViewModelTests {

    @Test("Signals initialize daily game")
    func testDailyInit() {
        let vm = SignalsGameViewModel(date: Date())
        #expect(vm.isDaily)
        #expect(vm.maxGuesses == 5)
        #expect(vm.gameState == .inProgress)
        #expect(vm.currentInput.count == 4)
    }

    @Test("Signals initialize progression level")
    func testProgressionInit() {
        let vm = SignalsGameViewModel(level: 10)
        #expect(!vm.isDaily)
        #expect(vm.activeLevelId == 10)
        #expect(vm.gameState == .inProgress)
    }
    
    @Test("Signals correctly handles input")
    func testInputHandling() {
        let vm = SignalsGameViewModel(level: 1)
        #expect(!vm.isInputComplete)
        
        vm.inputDigit(5)
        vm.inputDigit(3)
        vm.inputDigit(9)
        vm.inputDigit(1)
        
        #expect(vm.isInputComplete)
        #expect(vm.currentInput == [5, 3, 9, 1])
        
        vm.deleteLastDigit()
        #expect(!vm.isInputComplete)
        #expect(vm.currentInput == [5, 3, 9, nil])
    }
}
