import XCTest

@available(OSX 10.13, *)
class CLITests: XCTestCase {
    
    func test_runningItWithNoArgumentsPrintsAUsageStatement() throws {

        let (output, terminationStatus) = try runMuter(with: [])
        
        XCTAssertEqual(terminationStatus, 1)
        XCTAssertTrue(output.contains("usage"), "expected a usage statement to be printed")
    }
    
    func test_runningItWithOneArgumentCausesItToMutateThatFile() throws {
      
        let arguments = ["/Users/seandorian/Code/Swift/muter/Tests/muterTests/fixtures/sample.swift"]
        
        let (output, terminationStatus) = try runMuter(with: arguments)

        XCTAssertEqual(terminationStatus, 0)
        XCTAssertEqual(numberOfMutatedPathsIn(output), 1)
    }
}

@available(OSX 10.13, *)
private extension CLITests {
    
    var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }
    
    func runMuter(with arguments: [String]) throws -> (output: String, terminationStatus: Int32) {
        let muter = productsDirectory.appendingPathComponent("muter")
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = muter
        process.arguments = arguments
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (
            output: String(data: data, encoding: .utf8) ?? "",
            terminationStatus: process.terminationStatus
        )
    }
    
    func numberOfMutatedPathsIn(_ output: String) -> Int {
        let filePathRegex = try! NSRegularExpression(pattern: "(/[^/ ]*)+/?", options: .anchorsMatchLines)
        let entireString = NSRange(location: 0, length: output.count)
        return filePathRegex.numberOfMatches(in: output,
                                             options: .withoutAnchoringBounds,
                                             range: entireString)
    }
}