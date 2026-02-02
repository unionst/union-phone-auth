import SwiftUI
import PhoneNumberKit

@MainActor
@Observable
public class PhoneAuthModel {
    public var phoneNumber: String = ""
    public var verificationCode: String = ""
    public var name: String = ""
    public var username: String = ""
    public var isLoading: Bool = false
    public var error: String?
    public var showError: Bool = false

    private let phoneNumberUtility = PhoneNumberUtility()

    public var sanitizedPhoneNumber: String {
        "+1\(phoneNumber)"
    }

    public var formattedPhoneNumber: String {
        do {
            let parsed = try phoneNumberUtility.parse(phoneNumber, withRegion: "US")
            return phoneNumberUtility.format(parsed, toType: .national)
        } catch {
            return sanitizedPhoneNumber
        }
    }

    public var isPhoneNumberValid: Bool {
        phoneNumber.count >= 10
    }

    public var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var isUsernameValid: Bool {
        username.count >= 3
    }

    public init() {}

    public func reset() {
        phoneNumber = ""
        verificationCode = ""
        name = ""
        username = ""
        isLoading = false
        error = nil
        showError = false
    }
}

public enum PostAuthStep: Hashable, Sendable {
    case name
    case username
}

public struct VerifyResult: Sendable {
    public let postAuthSteps: [PostAuthStep]

    public init(postAuthSteps: [PostAuthStep] = []) {
        self.postAuthSteps = postAuthSteps
    }

    public static let done = VerifyResult(postAuthSteps: [])
}

enum PhoneAuthNavStep: Hashable {
    case verification(phoneNumber: String)
    case postAuth(PostAuthStep)
}

public struct PhoneAuthView: View {
    @Bindable var model: PhoneAuthModel
    let onSendCode: (String) async throws -> Void
    let onVerifyCode: (String, String) async throws -> VerifyResult
    let onComplete: ([PostAuthStep: String]) async throws -> Void
    let onCancel: () -> Void
    let checkUsernameAvailability: ((String) async throws -> Bool)?

    @State private var navigationPath = NavigationPath()
    @State private var formattedPhoneNumber = ""
    @State private var pendingPostAuthSteps: [PostAuthStep] = []
    @State private var currentPostAuthIndex = 0
    @FocusState private var isPhoneFocused: Bool
    private let partialFormatter = PartialFormatter()

    public init(
        model: PhoneAuthModel,
        onSendCode: @escaping (String) async throws -> Void,
        onVerifyCode: @escaping (String, String) async throws -> VerifyResult,
        onComplete: @escaping ([PostAuthStep: String]) async throws -> Void,
        onCancel: @escaping () -> Void,
        checkUsernameAvailability: ((String) async throws -> Bool)? = nil
    ) {
        self.model = model
        self.onSendCode = onSendCode
        self.onVerifyCode = onVerifyCode
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.checkUsernameAvailability = checkUsernameAvailability
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            phoneEntryView
                .navigationDestination(for: PhoneAuthNavStep.self) { step in
                    switch step {
                    case .verification(let phone):
                        VerificationView(
                            phoneNumber: phone,
                            verificationCode: $model.verificationCode,
                            isProcessing: $model.isLoading,
                            onVerify: verifyCode,
                            onResend: resendCode,
                            onCancel: onCancel
                        )
                    case .postAuth(let postStep):
                        postAuthView(for: postStep)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            onCancel()
                        }
                        .tint(.primary)
                    }
                    .sharedBackgroundVisibility(.visible)
                }
        }
        .scrollDismissesKeyboard(.never)
        .interactiveDismissDisabled(!navigationPath.isEmpty)
        .alert("Error", isPresented: $model.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.error ?? "")
        }
    }

    @ViewBuilder
    private func postAuthView(for step: PostAuthStep) -> some View {
        switch step {
        case .name:
            NameEntryView(
                name: $model.name,
                isLoading: $model.isLoading,
                onContinue: advancePostAuth,
                onCancel: onCancel
            )
        case .username:
            UsernameEntryView(
                username: $model.username,
                isLoading: $model.isLoading,
                onContinue: advancePostAuth,
                onCancel: onCancel,
                checkAvailability: checkUsernameAvailability
            )
        }
    }

    private var phoneEntryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "phone")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Log in or Sign up")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Enter your phone number to continue. We'll send you a verification code to confirm it's you.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)

                TextField("", text: $formattedPhoneNumber, prompt: Text("Phone Number"))
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .font(.body)
                    .padding()
                    .frame(height: 56)
                    .background(.quinary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .focused($isPhoneFocused)
                    .onChange(of: formattedPhoneNumber) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        model.phoneNumber = digits

                        let formatted = partialFormatter.formatPartial(digits)
                        if formatted != newValue {
                            formattedPhoneNumber = formatted
                        }
                    }

                Spacer()
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Button(action: sendCode) {
                Group {
                    if model.isLoading {
                        ProgressView()
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.isPhoneNumberValid || model.isLoading)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .onChange(of: model.isLoading) { _, newValue in
            if newValue {
                isPhoneFocused = false
            }
        }
    }

    private func sendCode() {
        guard !model.isLoading else { return }
        model.isLoading = true
        model.error = nil

        Task {
            do {
                try await onSendCode(model.sanitizedPhoneNumber)
                model.error = nil
                navigationPath.append(PhoneAuthNavStep.verification(phoneNumber: model.phoneNumber))
                model.isLoading = false
            } catch {
                model.error = error.localizedDescription
                model.showError = true
                model.isLoading = false
            }
        }
    }

    private func verifyCode() {
        guard !model.isLoading else { return }
        model.isLoading = true
        model.error = nil

        Task {
            do {
                let result = try await onVerifyCode(model.sanitizedPhoneNumber, model.verificationCode)
                model.isLoading = false

                if result.postAuthSteps.isEmpty {
                    try await completeAuth()
                } else {
                    pendingPostAuthSteps = result.postAuthSteps
                    currentPostAuthIndex = 0
                    navigationPath.append(PhoneAuthNavStep.postAuth(result.postAuthSteps[0]))
                }
            } catch {
                model.error = error.localizedDescription
                model.showError = true
                model.verificationCode = ""
                model.isLoading = false
            }
        }
    }

    private func advancePostAuth() {
        guard !model.isLoading else { return }

        currentPostAuthIndex += 1

        if currentPostAuthIndex < pendingPostAuthSteps.count {
            navigationPath.append(PhoneAuthNavStep.postAuth(pendingPostAuthSteps[currentPostAuthIndex]))
        } else {
            model.isLoading = true
            Task {
                do {
                    try await completeAuth()
                } catch {
                    model.error = error.localizedDescription
                    model.showError = true
                    model.isLoading = false
                }
            }
        }
    }

    private func completeAuth() async throws {
        var results: [PostAuthStep: String] = [:]
        for step in pendingPostAuthSteps {
            switch step {
            case .name:
                results[step] = model.name.trimmingCharacters(in: .whitespaces)
            case .username:
                results[step] = model.username
            }
        }
        try await onComplete(results)
    }

    private func resendCode() {
        guard !model.isLoading else { return }
        model.isLoading = true
        model.error = nil
        model.verificationCode = ""

        Task {
            do {
                try await onSendCode(model.sanitizedPhoneNumber)
                model.isLoading = false
            } catch {
                model.error = error.localizedDescription
                model.showError = true
                model.isLoading = false
            }
        }
    }
}

struct VerificationView: View {
    let phoneNumber: String
    @Binding var verificationCode: String
    @Binding var isProcessing: Bool
    let onVerify: () -> Void
    let onResend: () -> Void
    let onCancel: () -> Void

    @FocusState private var isCodeFocused: Bool
    private let phoneNumberUtility = PhoneNumberUtility()

    private var formattedPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }
        do {
            let parsed = try phoneNumberUtility.parse(digits, withRegion: "US")
            return phoneNumberUtility.format(parsed, toType: .national)
        } catch {
            return phoneNumber
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "phone.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Verify Phone Number")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Enter the verification code sent to:")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formattedPhoneNumber)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)

                CodeInput(code: $verificationCode, isFocused: $isCodeFocused)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()

                        Text("Verifying...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                } else {
                    Button(action: onResend) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text("Send a new code")
                        }
                        .font(.body)
                        .foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                }
                .tint(.primary)
                .disabled(isProcessing)
            }
            .sharedBackgroundVisibility(.visible)
        }
        .onAppear {
            isCodeFocused = true
        }
        .onChange(of: isProcessing) { _, newValue in
            if newValue {
                isCodeFocused = false
            }
        }
        .onChange(of: verificationCode) { _, newValue in
            if newValue.count == 6 {
                isCodeFocused = false
                onVerify()
            }
        }
    }
}

struct NameEntryView: View {
    @Binding var name: String
    @Binding var isLoading: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("What's your name?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("This will be displayed on your profile")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)

                TextField("", text: $name, prompt: Text("Your name"))
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .font(.body)
                    .padding()
                    .frame(height: 56)
                    .background(.quinary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .focused($isFocused)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 42 {
                            name = String(newValue.prefix(42))
                        }
                    }

                Spacer()
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Button(action: onContinue) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .disabled(!isValid || isLoading)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                }
                .tint(.primary)
                .disabled(isLoading)
            }
            .sharedBackgroundVisibility(.visible)
        }
        .onAppear {
            isFocused = true
        }
    }
}

struct UsernameEntryView: View {
    @Binding var username: String
    @Binding var isLoading: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void
    var checkAvailability: ((String) async throws -> Bool)?

    @State private var isUsernameValid = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Choose Username")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Pick a unique username to continue.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)

                UsernameField(
                    username: $username,
                    isValid: $isUsernameValid,
                    checkAvailability: checkAvailability
                )
                .focused()
                .padding(.horizontal, 32)
                .padding(.top, 16)

                Spacer()
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Button(action: onContinue) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .disabled(!isUsernameValid || isLoading)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                }
                .tint(.primary)
                .disabled(isLoading)
            }
            .sharedBackgroundVisibility(.visible)
        }
    }
}
