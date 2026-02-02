import SwiftUI

public enum OnboardingStep: Hashable, Sendable {
    case name
    case username
    case custom(id: String)
}

@MainActor
@Observable
public class PostAuthOnboardingModel {
    public var name: String = ""
    public var username: String = ""
    public var customValues: [String: String] = [:]
    public var isLoading: Bool = false
    public var error: String?
    public var showError: Bool = false

    public var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var isUsernameValid: Bool {
        !username.isEmpty && username.count >= 3
    }

    public init() {}

    public func reset() {
        name = ""
        username = ""
        customValues = [:]
        isLoading = false
        error = nil
        showError = false
    }
}

public struct PostAuthOnboardingView: View {
    @Bindable var model: PostAuthOnboardingModel
    let steps: [OnboardingStep]
    let onComplete: ([OnboardingStep: String]) async throws -> Void
    let onCancel: () -> Void
    let customStepView: ((OnboardingStep, Binding<String>, FocusState<Bool>.Binding, @escaping () -> Void) -> AnyView)?

    @State private var currentStepIndex = 0
    @FocusState private var isFocused: Bool

    public init(
        model: PostAuthOnboardingModel,
        steps: [OnboardingStep],
        onComplete: @escaping ([OnboardingStep: String]) async throws -> Void,
        onCancel: @escaping () -> Void,
        customStepView: ((OnboardingStep, Binding<String>, FocusState<Bool>.Binding, @escaping () -> Void) -> AnyView)? = nil
    ) {
        self.model = model
        self.steps = steps
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.customStepView = customStepView
    }

    private var currentStep: OnboardingStep {
        steps[currentStepIndex]
    }

    private var isLastStep: Bool {
        currentStepIndex == steps.count - 1
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .name:
                    nameStepView
                case .username:
                    usernameStepView
                case .custom(let id):
                    if let customStepView {
                        customStepView(
                            currentStep,
                            Binding(
                                get: { model.customValues[id] ?? "" },
                                set: { model.customValues[id] = $0 }
                            ),
                            $isFocused,
                            continueAction
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentStepIndex > 0 {
                        Button {
                            withAnimation {
                                currentStepIndex -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                        }
                        .tint(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        onCancel()
                    }
                    .tint(.primary)
                }
                .sharedBackgroundVisibility(.visible)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(currentStepIndex > 0 || model.isLoading)
        .alert("Error", isPresented: $model.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.error ?? "")
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onChange(of: currentStepIndex) { _, _ in
            isFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private var nameStepView: some View {
        OnboardingStepView(
            icon: "person.crop.circle",
            title: "What's your name?",
            subtitle: "This will be displayed on your profile"
        ) {
            OnboardingTextField(
                text: $model.name,
                placeholder: "Your name",
                contentType: .name,
                isFocused: $isFocused
            )
        } actions: {
            OnboardingContinueButton(
                isEnabled: model.isNameValid,
                isLoading: model.isLoading,
                action: continueAction
            )
        }
    }

    private var usernameStepView: some View {
        OnboardingStepView(
            icon: "at",
            title: "Pick a username",
            subtitle: "This is how others will find you"
        ) {
            OnboardingTextField(
                text: $model.username,
                placeholder: "username",
                prefix: "@",
                keyboardType: .asciiCapable,
                characterLimit: 30,
                transform: { value in
                    value.lowercased().replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
                },
                isFocused: $isFocused
            )
        } actions: {
            OnboardingContinueButton(
                isEnabled: model.isUsernameValid,
                isLoading: model.isLoading,
                action: continueAction
            )
        }
    }

    private func continueAction() {
        guard !model.isLoading else { return }

        if isLastStep {
            completeOnboarding()
        } else {
            withAnimation {
                currentStepIndex += 1
            }
        }
    }

    private func completeOnboarding() {
        model.isLoading = true
        isFocused = false

        Task {
            do {
                var results: [OnboardingStep: String] = [:]
                for step in steps {
                    switch step {
                    case .name:
                        results[step] = model.name.trimmingCharacters(in: .whitespaces)
                    case .username:
                        results[step] = model.username
                    case .custom(let id):
                        results[step] = model.customValues[id] ?? ""
                    }
                }
                try await onComplete(results)
                model.isLoading = false
            } catch {
                model.error = error.localizedDescription
                model.showError = true
                model.isLoading = false
            }
        }
    }
}
