import SwiftUI

public struct OnboardingTextField: View {
    @Binding var text: String
    let placeholder: String
    let prefix: String?
    let keyboardType: UIKeyboardType
    let contentType: UITextContentType?
    let characterLimit: Int
    let transform: ((String) -> String)?
    var isFocused: FocusState<Bool>.Binding

    public init(
        text: Binding<String>,
        placeholder: String,
        prefix: String? = nil,
        keyboardType: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        characterLimit: Int = 42,
        transform: ((String) -> String)? = nil,
        isFocused: FocusState<Bool>.Binding
    ) {
        self._text = text
        self.placeholder = placeholder
        self.prefix = prefix
        self.keyboardType = keyboardType
        self.contentType = contentType
        self.characterLimit = characterLimit
        self.transform = transform
        self.isFocused = isFocused
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let prefix {
                Text(verbatim: prefix)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            TextField("", text: $text, prompt: Text(verbatim: placeholder).foregroundColor(.secondary))
                .font(.title2)
                .fontWeight(.bold)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .focused(isFocused)
                .onChange(of: text) { _, newValue in
                    var processed = newValue
                    if let transform {
                        processed = transform(processed)
                    }
                    if processed.count > characterLimit {
                        processed = String(processed.prefix(characterLimit))
                    }
                    if processed != newValue {
                        text = processed
                    }
                }
                .sensoryFeedback(.impact, trigger: text)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.quinary)
        .clipShape(Capsule())
    }
}
