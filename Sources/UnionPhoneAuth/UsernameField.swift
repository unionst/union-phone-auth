import SwiftUI

public struct UsernameField: View {
    public enum Style {
        case capsule
        case plain
    }

    @Binding var username: String
    @Binding var isValid: Bool
    var checkAvailability: ((String) async throws -> Bool)?
    var style: Style

    @FocusState private var isFocused: Bool
    @State private var isValidFormat = false
    @State private var isAvailable = false
    @State private var isCheckingAvailability = false
    @State private var validationMessage = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var shouldFocusOnAppear = false

    public init(
        username: Binding<String>,
        isValid: Binding<Bool>,
        checkAvailability: ((String) async throws -> Bool)? = nil,
        style: Style = .capsule
    ) {
        self._username = username
        self._isValid = isValid
        self.checkAvailability = checkAvailability
        self.style = style
    }

    public var body: some View {
        VStack(spacing: 8) {
            statusView
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 20)

            textFieldContent
                .onChange(of: username) { _, newValue in
                    let processed = newValue
                        .lowercased()
                        .replacingOccurrences(of: "[^a-z0-9_.]", with: "", options: .regularExpression)
                    if processed != newValue || processed.count > 30 {
                        username = String(processed.prefix(30))
                    } else {
                        validateUsername(processed)
                    }
                }
        }
        .onAppear {
            if shouldFocusOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var textFieldContent: some View {
        let field = HStack(spacing: 12) {
            TextField("", text: $username, prompt: Text("Username"))
                .textContentType(.username)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .focused($isFocused)

            if checkAvailability != nil && !username.isEmpty {
                statusIcon
                    .font(.title3)
            }
        }

        switch style {
        case .capsule:
            field
                .padding()
                .frame(height: 56)
                .background(.quinary)
                .clipShape(Capsule())
        case .plain:
            field
        }
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 8) {
            if isCheckingAvailability {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Checking availability...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if isValidFormat && isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                Text("Username is available")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else if !validationMessage.isEmpty {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Username must be 3-30 characters")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isCheckingAvailability {
            ProgressView()
                .scaleEffect(0.8)
        } else if isValidFormat && isAvailable {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if !validationMessage.isEmpty {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    public func focused(_ shouldFocus: Bool = true) -> UsernameField {
        var copy = self
        copy.shouldFocusOnAppear = shouldFocus
        return copy
    }

    private func updateIsValid() {
        isValid = isValidFormat && isAvailable && !isCheckingAvailability
    }

    private func validateUsername(_ value: String) {
        debounceTask?.cancel()

        isValidFormat = false
        isAvailable = false
        validationMessage = ""
        updateIsValid()

        guard !value.isEmpty else { return }

        if value.count < 3 {
            validationMessage = "Username must be at least 3 characters"
            return
        }

        if value.count > 30 {
            validationMessage = "Username must be 30 characters or less"
            return
        }

        if value.hasPrefix(".") || value.hasSuffix(".") {
            validationMessage = "Username cannot start or end with a period"
            return
        }

        if value.contains("..") {
            validationMessage = "Username cannot have consecutive periods"
            return
        }

        isValidFormat = true

        guard let checkAvailability else {
            isAvailable = true
            updateIsValid()
            return
        }

        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                isCheckingAvailability = true
                updateIsValid()
            }

            do {
                let available = try await checkAvailability(value)

                await MainActor.run {
                    isAvailable = available
                    isCheckingAvailability = false
                    if !available {
                        validationMessage = "Username is already taken"
                    }
                    updateIsValid()
                }
            } catch {
                await MainActor.run {
                    isCheckingAvailability = false
                    validationMessage = "Unable to check availability"
                    updateIsValid()
                }
            }
        }
    }
}
