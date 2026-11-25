import SwiftUI

/// A section heading (Android Business Profile `SectionLabel`).
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .appText(.labelLarge, weight: .semiBold)
            .foregroundStyle(AppPalette.primary)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A text field with a caption label above it (stands in for Material's `OutlinedTextField`
/// with a floating label).
struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>?
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var suffix: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appText(.labelMedium)
                .foregroundStyle(focused ? AppPalette.primary : AppPalette.onSurfaceVariant)
            HStack(spacing: 4) {
                field
                if let suffix {
                    Text(suffix).appText(.bodyLarge).foregroundStyle(AppPalette.onSurfaceVariant)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                AppPalette.surface.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focused ? AppPalette.primary : AppPalette.outlineVariant, lineWidth: focused ? 2 : 1)
            )
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var field: some View {
        let base = TextField(
            "", text: $text,
            prompt: Text(placeholder).foregroundStyle(AppPalette.onSurfaceVariant.opacity(0.7)),
            axis: axis
        )
        .appText(.bodyLarge)
        .focused($focused)
        .keyboardType(keyboard)
        .textInputAutocapitalization(capitalization)
        .accessibilityLabel(title)

        if let lineLimit {
            base.lineLimit(lineLimit)
        } else {
            base.lineLimit(1)
        }
    }
}

/// A decimal text field bound to a `Double`. Keeps its own text so partial input such as "1." or
/// "0," survives while typing; the value is committed whenever the text parses as a number.
struct NumberField: View {
    let title: String
    let value: Double
    /// When true a value of 0 is shown as an empty field.
    var blankWhenZero = false
    var placeholder: String = ""
    var suffix: String?
    let onCommit: (Double) -> Void

    @State private var text = ""
    @State private var initialised = false

    var body: some View {
        LabeledTextField(
            title: title,
            text: $text,
            placeholder: placeholder,
            keyboard: .decimalPad,
            capitalization: .never,
            suffix: suffix
        )
        .onAppear {
            guard !initialised else { return }
            initialised = true
            text = display(value)
        }
        .onChange(of: text) { _, newText in
            let trimmed = newText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if value != 0 { onCommit(0) }
            } else if let parsed = Fmt.parseDecimal(trimmed), parsed != value {
                onCommit(parsed)
            }
        }
        .onChange(of: value) { _, newValue in
            // Re-format only when the change did not come from what the user typed.
            let typed = Fmt.parseDecimal(text) ?? 0
            if typed != newValue { text = display(newValue) }
        }
    }

    private func display(_ number: Double) -> String {
        if blankWhenZero && number == 0 { return "" }
        return Fmt.editableNumber(number)
    }
}
