#if canImport(UIKit)
import SwiftUI
import UIKit
import PhoneNumberKit

public struct PhoneNumberField: View {
    @Binding var phoneNumber: String
    let placeholder: String

    @State private var formattedPhoneNumber: String = ""
    private let partialFormatter = PartialFormatter()

    public init(
        phoneNumber: Binding<String>,
        placeholder: String = "Phone Number"
    ) {
        self._phoneNumber = phoneNumber
        self.placeholder = placeholder
    }

    public var body: some View {
        TextField("", text: $formattedPhoneNumber, prompt: Text(placeholder))
            .textContentType(.telephoneNumber)
            .keyboardType(.phonePad)
            .onChange(of: formattedPhoneNumber) { _, newValue in
                let digits = newValue.filter { $0.isNumber }
                phoneNumber = digits

                let formatted = partialFormatter.formatPartial(digits)
                if formatted != newValue {
                    formattedPhoneNumber = formatted
                }
            }
            .onAppear {
                if !phoneNumber.isEmpty {
                    formattedPhoneNumber = partialFormatter.formatPartial(phoneNumber)
                }
            }
    }
}
#endif
