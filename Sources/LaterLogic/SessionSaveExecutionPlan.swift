import Foundation

public enum SessionActivationPolicy: Equatable {
    case regular
    case accessory
}

public struct SessionSaveExecutionPlan: Equatable {
    public let shouldCaptureScreenshot: Bool
    public let preSaveActivationPolicy: SessionActivationPolicy?
    public let postSaveActivationPolicy: SessionActivationPolicy?

    public init(
        shouldCaptureScreenshot: Bool,
        preSaveActivationPolicy: SessionActivationPolicy?,
        postSaveActivationPolicy: SessionActivationPolicy?
    ) {
        self.shouldCaptureScreenshot = shouldCaptureScreenshot
        self.preSaveActivationPolicy = preSaveActivationPolicy
        self.postSaveActivationPolicy = postSaveActivationPolicy
    }
}

public enum SessionSaveSideEffectsPlanner {
    public static func makePlan(isUITestStubMode: Bool) -> SessionSaveExecutionPlan {
        guard !isUITestStubMode else {
            return SessionSaveExecutionPlan(
                shouldCaptureScreenshot: false,
                preSaveActivationPolicy: nil,
                postSaveActivationPolicy: nil
            )
        }

        return SessionSaveExecutionPlan(
            shouldCaptureScreenshot: true,
            preSaveActivationPolicy: .regular,
            postSaveActivationPolicy: .accessory
        )
    }
}
