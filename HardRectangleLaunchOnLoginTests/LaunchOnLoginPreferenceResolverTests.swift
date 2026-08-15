/// LaunchOnLoginPreferenceResolverTests.swift

import XCTest

final class LaunchOnLoginPreferenceResolverTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LaunchOnLoginPreferenceResolverTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMissingPreferencePromptsAndPersistsEnabledChoice() {
        var promptCount = 0
        let resolver = LaunchOnLoginPreferenceResolver(userDefaults: userDefaults)

        let enabled = resolver.resolve {
            promptCount += 1
            return true
        }

        XCTAssertTrue(enabled)
        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(userDefaults.object(forKey: LaunchOnLoginPreferenceResolver.preferenceKey) as? Bool, true)
        XCTAssertTrue(resolver.resolve { XCTFail("Persisted choices must not prompt again"); return false })
        XCTAssertEqual(promptCount, 1)
    }

    func testMissingPreferencePersistsDeclinedChoice() {
        let resolver = LaunchOnLoginPreferenceResolver(userDefaults: userDefaults)

        XCTAssertFalse(resolver.resolve { false })
        XCTAssertEqual(userDefaults.object(forKey: LaunchOnLoginPreferenceResolver.preferenceKey) as? Bool, false)
    }

    func testStoredEnabledChoiceDoesNotPrompt() {
        userDefaults.set(true, forKey: LaunchOnLoginPreferenceResolver.preferenceKey)
        let resolver = LaunchOnLoginPreferenceResolver(userDefaults: userDefaults)

        XCTAssertTrue(resolver.resolve { XCTFail("Stored choices must not prompt"); return false })
    }

    func testStoredDisabledChoiceDoesNotPrompt() {
        userDefaults.set(false, forKey: LaunchOnLoginPreferenceResolver.preferenceKey)
        let resolver = LaunchOnLoginPreferenceResolver(userDefaults: userDefaults)

        XCTAssertFalse(resolver.resolve { XCTFail("Stored choices must not prompt"); return true })
    }
}
