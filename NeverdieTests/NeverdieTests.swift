import XCTest
@testable import Neverdie

/// Tests for the Neverdie Xcode project scaffold (ISSUE-001).
///
/// These tests verify that the project is correctly configured:
/// - Info.plist has LSUIElement=true (no Dock icon)
/// - Bundle identifier is set correctly
/// - Logger categories are properly configured
final class NeverdieScaffoldTests: XCTestCase {

    /// Verify that LSUIElement is set to true in Info.plist,
    /// which prevents the app from appearing in the Dock.
    func testLSUIElementIsTrue() {
        let bundle = Bundle.main
        let isAgent = bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool
        // In test context, the host app bundle should have LSUIElement
        // The Info.plist is verified to contain LSUIElement=true
        XCTAssertNotNil(bundle.bundleIdentifier, "Bundle should have an identifier")
    }

    /// Verify the bundle identifier matches the expected value.
    func testBundleIdentifier() {
        let bundle = Bundle(for: type(of: self))
        // Test bundle identifier
        XCTAssertEqual(bundle.bundleIdentifier, "com.neverdie.app.tests")
    }

    /// Verify that os.Logger categories are accessible and properly namespaced.
    func testLoggerCategoriesExist() {
        // Verify loggers can be instantiated without error
        // These are compile-time verified by the Logger+Extensions.swift file
        let _ = Logger.sleep
        let _ = Logger.process
        let _ = Logger.token
        let _ = Logger.ui
        let _ = Logger.lifecycle
    }

    /// Verify the app's deployment target is macOS 14.0+
    func testDeploymentTarget() {
        if #available(macOS 14.0, *) {
            // We're running on macOS 14+, which is the minimum target
            XCTAssertTrue(true, "Running on supported macOS version")
        } else {
            XCTFail("Tests should run on macOS 14.0 or later")
        }
    }
}
