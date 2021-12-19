import Quick
import Nimble
import SwiftSyntax
@testable import muterCore

class BooleanSwapOperatorSpec: QuickSpec {
    override func spec() {
        describe("") {
            let sourceWithBooleanOperators = sourceCode(fromFileAt: "\(self.fixturesDirectory)/MutationExamples/BooleanSwap/sampleWithBooleanOperators.swift")! //false, true
            
            describe("BooleanSwapOperator.Rewriter") {
                
                it("swaps false to true") {
                    let line2Column15 = MutationPosition(utf8Offset: 40, line: 2, column: 15) //true
                    let expectedSource = sourceCode(fromFileAt: "\(self.fixturesDirectory)/MutationExamples/BooleanSwap/changedFalseBooleanOperator.swift")!
                    
                    let rewriter = BooleanSwapOperator.Rewriter(positionToMutate: line2Column15)
                    let mutatedSource = rewriter.visit(sourceWithBooleanOperators.code)
                    
                    expect(mutatedSource.description) == expectedSource.code.description
                    expect(rewriter.operatorSnapshot.before).to(equal("false"))
                    expect(rewriter.operatorSnapshot.after).to(equal("true"))
                    expect(rewriter.operatorSnapshot.description).to(equal("changed false to true"))
                }
                
                it("swaps true to false") {
                    let line7Column15 = MutationPosition(utf8Offset: 109, line: 7, column: 15)
                    let expectedSource = sourceCode(fromFileAt:
                        "\(self.mutationExamplesDirectory)/BooleanSwap/changedTrueBooleanOperator.swift")!
                    
                    let rewriter = BooleanSwapOperator.Rewriter(positionToMutate: line7Column15)
                    let mutatedSource = rewriter.visit(sourceWithBooleanOperators.code)
                    
                    expect(mutatedSource.description).to(equal(expectedSource.code.description))
                    expect(rewriter.operatorSnapshot.before).to(equal("true"))
                    expect(rewriter.operatorSnapshot.after).to(equal("false"))
                    expect(rewriter.operatorSnapshot.description).to(equal("changed true to false"))
                }
                
            }
            
            describe("BooleanSwapOperator.Visitor") {
                it("records the positions of code that contains a logical operator") {
                    
                    let visitor = BooleanSwapOperator.Visitor(sourceFileInfo: sourceWithBooleanOperators.asSourceFileInfo)
                    visitor.walk(sourceWithBooleanOperators.code)
                    
                    guard visitor.positionsOfToken.count == 2 else {
                        fail("Expected 2 tokens to be discovered, got \(visitor.positionsOfToken.count) instead")
                        return
                    }
                    
                    expect(visitor.positionsOfToken[0].line).to(equal(2))
                    expect(visitor.positionsOfToken[1].line).to(equal(7))
                }
            }
        }
    }
}

