import Foundation
import XCTest

final class HermesFixtureBundleToken {}

enum HermesFixtureLoader {
    static func url(named name: String, extension ext: String, subdirectory: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let bundle = Bundle(for: HermesFixtureBundleToken.self)
        let bundledURL = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: ext)
        guard let url = bundledURL else {
            XCTFail("Missing fixture \(subdirectory.map { $0 + "/" } ?? "")\(name).\(ext)", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    static func string(named name: String, extension ext: String, subdirectory: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        try String(contentsOf: url(named: name, extension: ext, subdirectory: subdirectory, file: file, line: line), encoding: .utf8)
    }

    static func data(named name: String, extension ext: String, subdirectory: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        try Data(contentsOf: url(named: name, extension: ext, subdirectory: subdirectory, file: file, line: line))
    }

    static func jsonObject(named name: String, subdirectory: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws -> Any {
        let data = try data(named: name, extension: "json", subdirectory: subdirectory, file: file, line: line)
        return try JSONSerialization.jsonObject(with: data)
    }
}
