import XCTest
@testable import TreadmillKit

final class LocalizationTests: XCTestCase {
    func testBothLanguagesHaveMatchingPlaceholdersAndEnglishCoverage() throws {
        func strings(_ language: String) throws -> [String: String] {
            let path = try XCTUnwrap(L10n.bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let ja = try strings("ja"), en = try strings("en")
        XCTAssertEqual(Set(ja.keys), Set(en.keys))
        for (key, value) in en {
            XCTAssertFalse(value.isEmpty, key)
            XCTAssertEqual(key.components(separatedBy: "%@").count, value.components(separatedBy: "%@").count, key)
            XCTAssertNil(value.range(of: "[ぁ-んァ-ン一-龯]", options: .regularExpression), key)
        }
        XCTAssertEqual(L10n.text("スタート", language: "en"), "Start")
        XCTAssertEqual(L10n.text("スタート", language: "ja"), "スタート")
        XCTAssertEqual(L10n.text("スタート", language: "fr"), "Start")
    }

    func testFormattingPreservesPercentSignsAndInsertedText() {
        XCTAssertEqual(L10n.render("Goal %@%", arguments: ["75"]), "Goal 75%")
        XCTAssertEqual(L10n.render("Step %@ / %@ · %@", arguments: ["2", "6", "Hill walk"]), "Step 2 / 6 · Hill walk")
        XCTAssertEqual(L10n.render("Error: %@", arguments: ["50% %@"]), "Error: 50% %@")
    }

    func testPresetArchivesKeepCanonicalMetadataAcrossLanguages() throws {
        let original = WorkoutProgram.presets[0]
        XCTAssertEqual(original.id, "12-3-30")
        XCTAssertEqual(original.name, "12-3-30 ウォーク")
        XCTAssertEqual(L10n.text(original.name, language: "en"), "12-3-30 Walk")
        let restored = try JSONDecoder().decode(WorkoutProgram.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(L10n.text("My custom workout", language: "en"), "My custom workout")
    }
}
