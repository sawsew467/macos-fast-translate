import SwiftUI

struct PaymentQRSheetView: View {
    let qrInfo: QRPaymentInfo
    let onDismiss: () -> Void

    @ObservedObject private var creditService = CreditService.shared
    @State private var pollTimer: Timer?
    @State private var secondsRemaining = 120
    @State private var initialBalance: Int
    @State private var paymentConfirmed = false
    @State private var copied = false

    init(qrInfo: QRPaymentInfo, onDismiss: @escaping () -> Void) {
        self.qrInfo = qrInfo
        self.onDismiss = onDismiss
        _initialBalance = State(initialValue: CreditService.shared.balance)
    }

    var body: some View {
        VStack(spacing: 20) {
            if paymentConfirmed {
                successView
            } else {
                qrView
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - QR View

    private var qrView: some View {
        VStack(spacing: 16) {
            Text(String(localized: "payment.title")).font(.title2.bold())

            AsyncImage(url: URL(string: qrInfo.qr_data)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().frame(width: 200, height: 200)
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                detailRow(String(localized: "payment.bank"), qrInfo.bank_name)
                detailRow(String(localized: "payment.accountNumber"), qrInfo.bank_account)
                detailRow(String(localized: "payment.amount"), formatVND(qrInfo.amount))
                HStack {
                    detailRow(String(localized: "payment.transferContent"), qrInfo.transfer_content)
                    Spacer()
                    Button(copied ? String(localized: "payment.copied") : String(localized: "payment.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(qrInfo.transfer_content, forType: .string)
                        copied = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text(String(localized: "payment.waiting \(secondsRemaining)"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button(String(localized: "payment.close")) { onDismiss() }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48)).foregroundStyle(.green)
            Text(String(localized: "payment.success")).font(.title2.bold())
            Text(String(localized: "payment.balance \(creditService.balance)"))
                .font(.headline).foregroundStyle(.secondary)
            Button(String(localized: "payment.close")) { onDismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                self.secondsRemaining -= 5
                await self.creditService.fetchBalance()
                if self.creditService.balance > self.initialBalance {
                    self.paymentConfirmed = true
                    self.stopPolling()
                }
                if self.secondsRemaining <= 0 { self.stopPolling() }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .medium))
        }
    }

    private func formatVND(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)") + "đ"
    }
}
