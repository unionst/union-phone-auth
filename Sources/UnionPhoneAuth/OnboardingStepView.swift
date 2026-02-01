#if canImport(UIKit)
import SwiftUI
import UIKit

public struct OnboardingStepView<Content: View, Actions: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: () -> Content
    let actions: () -> Actions

    public init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.actions = actions
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                content()
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer()
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            actions()
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
    }
}

public struct OnboardingContinueButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    public init(
        title: String = "Continue",
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.glassProminent)
        .disabled(!isEnabled || isLoading)
    }
}
#endif
