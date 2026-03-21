//
//  PrismaUITests.swift
//  PrismaUITests
//
//  Created by Anu Gnana on 27/02/2026.
//

import XCTest

final class PrismaUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLaunchShowsMainTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // Critical journey baseline: all primary tabs are visible after launch.
        XCTAssertTrue(app.tabBars.buttons["Daily"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Local"].exists)
        XCTAssertTrue(app.tabBars.buttons["You"].exists)
    }

    @MainActor
    func testProfileTabCanOpenSettings() throws {
        let app = XCUIApplication()
        app.launch()

        let profileTab = app.tabBars.buttons["You"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
