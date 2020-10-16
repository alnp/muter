import Foundation
import SwiftSyntax

struct PerformMutationTesting: RunCommandStep {
    private let ioDelegate: MutationTestingIODelegate
    private let notificationCenter: NotificationCenter
    private let buildErrorsThreshold: Int = 5
    private let fileManager = FileManager.default
    
    init(ioDelegate: MutationTestingIODelegate = MutationTestingDelegate(),
         notificationCenter: NotificationCenter = .default) {
        self.ioDelegate = ioDelegate
        self.notificationCenter = notificationCenter
    }
    
    func run(with state: AnyRunCommandState) -> Result<[RunCommandState.Change], MuterError> {
        fileManager.changeCurrentDirectoryPath(state.tempDirectoryURL.path)

        let result = performMutationTesting(using: state)
        switch result {
        case .success(let outcomes):
            notificationCenter.post(name: .mutationTestingFinished, object: outcomes)
            return .success([.mutationTestOutcomesGenerated(outcomes)])
        case .failure(let reason):
            return .failure(reason)
        }
    }
}

private extension PerformMutationTesting {
    func performMutationTesting(using state: AnyRunCommandState) -> Result<[MutationTestOutcome], MuterError> {
        notificationCenter.post(name: .mutationTestingStarted, object: nil)

        let initialTime = Date()
        let (testSuiteOutcome, testLog) = ioDelegate.runTestSuite(using: state.muterConfiguration,
                                                                  savingResultsIntoFileNamed: "baseline run")
        let timeAfterRunningTestSuite = Date()
        let timePerBuildTestCycle = DateInterval(start: initialTime, end: timeAfterRunningTestSuite).duration
        
        guard testSuiteOutcome == .passed else {
            return .failure(.mutationTestingAborted(reason: .baselineTestFailed(log: testLog)))
        }
        
        let mutationLog = MutationTestLog(
            mutationPoint: .none,
            testLog: testLog,
            timePerBuildTestCycle: timePerBuildTestCycle,
            remainingMutationPointsCount: state.mutationPoints.count
        )
        
        notificationCenter.post(name: .newTestLogAvailable, object: mutationLog)
        
        return insertMutants(using: state)
    }
    
    func insertMutants(using state: AnyRunCommandState) -> Result<[MutationTestOutcome], MuterError> {
        var outcomes: [MutationTestOutcome] = []
        outcomes.reserveCapacity(state.mutationPoints.count)
        var buildErrors = 0
        
        for mutationPoint in state.mutationPoints {

            ioDelegate.backupFile(at: mutationPoint.filePath, using: state.swapFilePathsByOriginalPath)
            
            let sourceCode = state.sourceCodeByFilePath[mutationPoint.filePath]!
            let mutantDescription = insertMutant(at: mutationPoint, within: sourceCode)
            
            let (testSuiteOutcome, testLog) = ioDelegate.runTestSuite(using: state.muterConfiguration,
                                                                      savingResultsIntoFileNamed: logFileName(for: mutationPoint))

            ioDelegate.restoreFile(at: mutationPoint.filePath, using: state.swapFilePathsByOriginalPath)

            let outcome = MutationTestOutcome(testSuiteOutcome: testSuiteOutcome,
                                              mutationPoint: mutationPoint,
                                              operatorDescription: mutantDescription,
                                              originalProjectDirectoryUrl: state.projectDirectoryURL)
            outcomes.append(outcome)
            
            let mutationLog = MutationTestLog(
                mutationPoint: mutationPoint,
                testLog: testLog,
                timePerBuildTestCycle: .none,
                remainingMutationPointsCount: .none
            )
            
            notificationCenter.post(name: .newMutationTestOutcomeAvailable,
                                    object: outcome)
            notificationCenter.post(name: .newTestLogAvailable, object: mutationLog)
            
            buildErrors = testSuiteOutcome == .buildError ? (buildErrors + 1) : 0
            if buildErrors >= buildErrorsThreshold {
                return .failure(.mutationTestingAborted(reason: .tooManyBuildErrors))
            }
        }
        
        return .success(outcomes)
    }
    
    func insertMutant(at mutationPoint: MutationPoint, within sourceCode: SourceFileSyntax) -> String {
        let (mutatedSource, description) = mutationPoint.mutationOperator(sourceCode)
        try! ioDelegate.writeFile(to: mutationPoint.filePath, contents: mutatedSource.description)
        
        return description
    }
    
    func logFileName(for mutationPoint: MutationPoint) -> String {
        return "\(mutationPoint.fileName)_\(mutationPoint.mutationOperatorId.rawValue)_\(mutationPoint.position).log"
    }
}
