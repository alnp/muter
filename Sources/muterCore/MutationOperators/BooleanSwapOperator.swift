import SwiftSyntax

extension BooleanSwapOperator {
    class Rewriter: OperatorAwareRewriter {
        required init(positionToMutate: MutationPosition) {
            super.init(positionToMutate: positionToMutate)
            oppositeOperatorMapping = [
                "true": "false",
                "false": "true",
            ]
        }
    }
}
