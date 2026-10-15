import ATUIKit
import SwiftUI

struct IDCReminderSheet: View {
    var onScheduled: ((Date) -> Void)?

    private enum Step: Equatable {
        case options
        case custom
        case confirmed(message: String)
    }

    private enum TimeColumn: Int, CaseIterable {
        case spacer, hour, colon, minute, meridiem
    }

    @State private var step: Step
    @State private var selectedDayOffset = 0
    @State private var timeSelections: [Int]
    @State private var referenceDate = Date()

    private static let hourItems = (1...12).map { String(format: "%02d", $0) }
    private static let minuteItems = (0...59).map { String(format: "%02d", $0) }
    private static let meridiemItems = ["AM", "PM"]

    init(onScheduled: ((Date) -> Void)? = nil) {
        self.init(initialStep: .options, onScheduled: onScheduled)
    }

    private init(initialStep: Step, onScheduled: ((Date) -> Void)?) {
        self.onScheduled = onScheduled
        _step = State(initialValue: initialStep)
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let hour24 = components.hour ?? 9
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        var selections = Array(repeating: 0, count: TimeColumn.allCases.count)
        selections[TimeColumn.hour.rawValue] = hour12 - 1
        selections[TimeColumn.minute.rawValue] = components.minute ?? 0
        selections[TimeColumn.meridiem.rawValue] = hour24 >= 12 ? 1 : 0
        _timeSelections = State(initialValue: selections)
    }

    var body: some View {
        Group {
            switch step {
            case .options:
                optionsStep
            case .custom:
                customStep
            case .confirmed(let message):
                confirmedStep(message: message)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.pureWhite)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Steps

    private var optionsStep: some View {
        VStack(spacing: 0) {
            eyebrowHeader

            bell(sparkleTint: Color.pureBlack)
                .padding(.top, IDCTheme.Layout.reminderBellTopPadding)

            Text(IDCStrings.Reminder.sheetTitle)
                .typoGraphy(.H5InterSemibold20)
                .foregroundStyle(Color.pureBlack)
                .multilineTextAlignment(.center)
                .padding(.top, 25)

            VStack(spacing: 20) {
                ATButton(IDCStrings.Reminder.remindTonight, size: .large, variant: .primary, colorStyle: .black) {
                    IDCHaptics.tap()
                    schedule(tonight, confirmation: IDCStrings.Reminder.confirmedTonight)
                }
                .titleTypography(.B1InterSemibold14)
                ATButton(IDCStrings.Reminder.remindTomorrowMorning, size: .large, variant: .outlineSubtle, colorStyle: .black) {
                    IDCHaptics.tap()
                    schedule(tomorrowMorning, confirmation: IDCStrings.Reminder.confirmedTomorrow)
                }
                .titleTypography(.B1InterSemibold14)
                Button {
                    IDCHaptics.tap()
                    step = .custom
                } label: {
                    Text(IDCStrings.Reminder.pickCustomTime)
                        .typoGraphy(.B1InterSemibold14)
                        .underline()
                        .foregroundStyle(Color.pureBlack)
                }
                .buttonStyle(.idcHaptic)
            }
            .padding(.top, IDCTheme.Layout.reminderActionsTopPadding)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }

    private var customStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                IDCIcon(ATIcon.SwiftUIImage.calendarToday, size: 24)
                    .foregroundStyle(Color.pureBlack)

                Text(IDCStrings.Reminder.selectDateTime)
                    .typoGraphy(.H5InterSemibold20)
                    .foregroundStyle(Color.pureBlack)
                    .padding(.top, 20)

                Text(IDCStrings.Reminder.selectDateTimeMessage)
                    .typoGraphy(.B1InterMedium14)
                    .foregroundStyle(Color.pureBlack)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                backButton
                    .offset(y: -20)
            }
            .padding(.top, 48)

            dayChips
                .padding(.top, 40)
                .padding(.horizontal, 30)

            Rectangle()
                .fill(Color.borderLightLight100)
                .frame(height: 1)
                .padding(.top, 50)
                .padding(.horizontal, 30)

            ATFlatWheel(
                columns: [
                    ATFlatWheelColumn(items: [""], flex: 3),
                    ATFlatWheelColumn(
                        items: Self.hourItems,
                        textAlignment: .center,
                        flex: 3,
                        accessibilityLabel: IDCStrings.A11y.reminderHour
                    ),
                    ATFlatWheelColumn(items: [":"], flex: 1),
                    ATFlatWheelColumn(
                        items: Self.minuteItems,
                        textAlignment: .center,
                        flex: 3,
                        accessibilityLabel: IDCStrings.A11y.reminderMinute
                    ),
                    ATFlatWheelColumn(
                        items: Self.meridiemItems,
                        textAlignment: .right,
                        flex: 3,
                        accessibilityLabel: IDCStrings.A11y.reminderMeridiem
                    ),
                ],
                selections: $timeSelections,
                highlightStyle: .separators,
                selectedScale: 20 / 16
            )
            .frame(height: IDCTheme.Layout.reminderWheelHeight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, IDCTheme.Layout.reminderWheelVerticalPadding)
            .padding(.horizontal, 30)

            ATButton(IDCStrings.Reminder.setReminderCTA, size: .large, variant: .primary, colorStyle: .black) {
                IDCHaptics.tap()
                let date = customDate
                schedule(date, confirmation: IDCStrings.Reminder.confirmedCustom(Self.customFormatter.string(from: date)))
            }
            .titleTypography(.B1InterSemibold14)
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    private func confirmedStep(message: String) -> some View {
        VStack(spacing: 0) {
            eyebrowHeader

            bell(sparkleTint: Color(at: .accentEmerald500))
                .padding(.top, 86)

            Text(IDCStrings.Reminder.confirmedTitle)
                .typoGraphy(.H5InterSemibold20)
                .foregroundStyle(Color.pureBlack)
                .padding(.top, 25)

            Text(message)
                .typoGraphy(.B1InterMedium14)
                .foregroundStyle(Color.pureBlack)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 15)
                .padding(.bottom, IDCTheme.Layout.reminderConfirmedBottomPadding)
        }
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [Color(at: .accentEmerald50).opacity(0), Color(at: .accentEmerald50)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)
        }
        .task {
            IDCHaptics.success()
            try? await Task.sleep(nanoseconds: IDCTheme.Animation.reminderConfirmDismissNanoseconds)
            guard !Task.isCancelled else { return }
            ATBottomSheetWindowPresenter.dismiss()
        }
    }

    // MARK: - Pieces

    private var eyebrowHeader: some View {
        VStack(spacing: 0) {
            Text(IDCStrings.Reminder.eyebrow)
                .typoGraphy(.T2InterBold12)
                .textCase(.uppercase)
                .foregroundStyle(Color.pureBlack)
                .padding(.top, 30)

            Rectangle()
                .fill(Color.borderLightLight100)
                .frame(height: 1)
                .padding(.top, 25)
                .padding(.horizontal, 30)
        }
    }

    private func bell(sparkleTint: Color) -> some View {
        Image("reminder_bell")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(sparkleTint)
                    .offset(x: 4, y: 5)
            }
            .overlay(alignment: .leading) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(sparkleTint.opacity(0.35))
                    .offset(x: -12, y: 5)
            }
    }

    private var backButton: some View {
        Button {
            IDCHaptics.tap()
            step = .options
        } label: {
            IDCIcon(ATIcon.SwiftUIImage.chevronLeft, size: 24)
                .foregroundStyle(Color.pureBlack)
                .frame(width: 50, height: 50)
                .overlay(Circle().stroke(Color.pureBlack.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.idcHaptic)
        .padding(.leading, 30)
        .accessibilityLabel(IDCStrings.A11y.back)
    }

    private var dayChips: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
                let selected = offset == selectedDayOffset
                Button {
                    IDCHaptics.tap()
                    selectedDayOffset = offset
                } label: {
                    VStack(spacing: 4) {
                        Text(Self.weekdayFormatter.string(from: date))
                            .typoGraphy(.B1InterSemibold14)
                            .foregroundStyle(selected ? Color.neutralGrey300 : Color.neutralGrey400)
                        Text(Self.dayFormatter.string(from: date))
                            .typoGraphy(.H6InterSemibold18)
                            .foregroundStyle(selected ? Color.pureWhite : Color.pureBlack)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: IDCTheme.Layout.reminderDayChipHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(selected ? Color.pureBlack : Color.clear)
                            .padding(IDCTheme.Layout.reminderDayChipInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.borderLightLight200, lineWidth: 1)
                    )
                }
                .buttonStyle(.idcHaptic)
            }
        }
    }

    // MARK: - Dates & scheduling

    private var tonight: Date { IDCReminderPlanner.tonight() }

    private var tomorrowMorning: Date { IDCReminderPlanner.tomorrowMorning() }

    private var customDate: Date {
        IDCReminderPlanner.customDate(
            dayOffset: selectedDayOffset,
            hour12: timeSelections[TimeColumn.hour.rawValue] + 1,
            minute: timeSelections[TimeColumn.minute.rawValue],
            isPM: timeSelections[TimeColumn.meridiem.rawValue] == 1,
            reference: referenceDate
        )
    }

    private func schedule(_ date: Date, confirmation: String) {
        Task {
            let notified = await IDCReminderScheduler.schedule(at: date)
            onScheduled?(date)
            step = .confirmed(
                message: notified ? confirmation : IDCStrings.Reminder.confirmedNoNotificationAccess
            )
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let customFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return formatter
    }()
}

#if DEBUG
extension IDCReminderSheet {
    static var previewCustomStep: IDCReminderSheet {
        IDCReminderSheet(initialStep: .custom, onScheduled: nil)
    }

    static var previewConfirmedStep: IDCReminderSheet {
        IDCReminderSheet(
            initialStep: .confirmed(message: IDCStrings.Reminder.confirmedTonight),
            onScheduled: nil
        )
    }
}

#Preview("Reminder — options") {
    IDCReminderSheet()
}

#Preview("Reminder — custom time") {
    IDCReminderSheet.previewCustomStep
}

#Preview("Reminder — confirmed") {
    IDCReminderSheet.previewConfirmedStep
}

#Preview("Reminder — flow") {
    Color.pureBlack.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            IDCReminderSheet()
                .presentationDragIndicator(.visible)
        }
}
#endif
