#if canImport(UIKit)
import SwiftUI
import UIKit

public struct CodeInput: View {
    @Binding var code: String
    let length: Int
    var isFocused: FocusState<Bool>.Binding

    public init(
        code: Binding<String>,
        length: Int = 6,
        isFocused: FocusState<Bool>.Binding
    ) {
        self._code = code
        self.length = length
        self.isFocused = isFocused
    }

    public var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<length, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quinary)
                        .frame(width: 45, height: 56)

                    if index < code.count {
                        Text(String(code[code.index(code.startIndex, offsetBy: index)]))
                            .font(.title)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .onTapGesture {
            isFocused.wrappedValue = true
        }
        .overlay {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .opacity(0.01)
                .focused(isFocused)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter { $0.isNumber }.prefix(length))
                }
        }
    }
}
#endif
