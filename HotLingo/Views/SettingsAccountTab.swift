import SwiftUI

struct SettingsAccountTab: View {
    @ObservedObject private var authService = SupabaseAuthService.shared
    @ObservedObject private var creditService = CreditService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var otp = ""
    @State private var pendingOTPEmail: String?
    @State private var pendingPasswordResetEmail: String?
    @State private var resetOTP = ""
    @State private var newPassword = ""
    @State private var showPasswordResetAction = false
    @State private var packages: [TopupPackage] = []
    @State private var qrInfo: QRPaymentInfo?

    var body: some View {
        SettingsPage(title: "Account", subtitle: "Manage your AI Translation account and credits.") {
            if authService.authState.isLoggedIn {
                loggedInContent
            } else {
                loggedOutContent
            }
        }
        .task {
            if authService.authState.isLoggedIn {
                await creditService.fetchBalance()
                await loadPackages()
            }
        }
        .sheet(item: $qrInfo) { qr in
            PaymentQRSheetView(qrInfo: qr) { qrInfo = nil }
        }
    }

    // MARK: - Logged In

    @ViewBuilder
    private var loggedInContent: some View {
        SettingsCard(systemImage: "creditcard", title: "Balance",
                     subtitle: LocalizedStringKey(authService.authState.email ?? "")) {
            HStack {
                Text("\(creditService.balance)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("credits").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { Task { await creditService.fetchBalance() } }
                    .font(.caption).buttonStyle(.bordered)
            }
        }

        if !packages.isEmpty {
            SettingsCard(systemImage: "bag", title: "Top Up",
                         subtitle: "Purchase more credits.") {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(packages) { pkg in
                        PackageCard(package: pkg) {
                            Task { await purchasePackage(pkg) }
                        }
                    }
                }
            }
        }

        HStack {
            SettingsButton("Log Out", systemImage: "rectangle.portrait.and.arrow.right") {
                authService.logout()
            }
            Spacer()
        }
    }

    // MARK: - Logged Out

    @ViewBuilder
    private var loggedOutContent: some View {
        if let resetEmail = pendingPasswordResetEmail {
            passwordResetCard(email: resetEmail)
        } else if let otpEmail = pendingOTPEmail {
            otpCard(email: otpEmail)
        } else {
            authCard
        }
    }

    private var authCard: some View {
        SettingsCard(
            systemImage: "person.crop.circle",
            title: isSignup ? "Sign Up" : "Log In",
            subtitle: "Create an account to use AI Translation."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Email", text: $email).textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password).textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    SettingsButton(isSignup ? "Sign Up" : "Log In", systemImage: "arrow.right", isPrimary: true) {
                        Task {
                            if isSignup {
                                showPasswordResetAction = false
                                await authService.signup(email: email, password: password)
                                if authService.authError == nil { pendingOTPEmail = email }
                            } else {
                                await authService.login(email: email, password: password)
                                if authService.authState.isLoggedIn {
                                    showPasswordResetAction = false
                                    await creditService.fetchBalance()
                                    await loadPackages()
                                    if !creditService.trialClaimed {
                                        await creditService.claimTrial()
                                    }
                                } else {
                                    showPasswordResetAction = authService.authError != nil
                                }
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)

                    SettingsButton(isSignup ? "Have account? Log in" : "New? Sign up", systemImage: isSignup ? "person.fill" : "person.badge.plus") {
                        isSignup.toggle()
                        showPasswordResetAction = false
                        authService.authError = nil
                    }

                    if !isSignup && showPasswordResetAction {
                        SettingsButton("Reset password", systemImage: "lock.rotation") {
                            Task {
                                await authService.sendPasswordResetOTP(email: email)
                                if authService.authError == nil {
                                    pendingPasswordResetEmail = email
                                    resetOTP = ""
                                    newPassword = ""
                                    showPasswordResetAction = false
                                }
                            }
                        }
                        .disabled(email.isEmpty || authService.authState == .loading)
                    }

                    if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
                }

                if let error = authService.authError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    private func otpCard(email: String) -> some View {
        SettingsCard(
            systemImage: "envelope.badge",
            title: "Verify your email",
            subtitle: "Enter the 6-digit code sent to \(email)"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("000000", text: $otp)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .onChange(of: otp) { newValue in
                        otp = String(newValue.filter(\.isNumber).prefix(6))
                    }

                HStack(spacing: 10) {
                    SettingsButton("Verify", systemImage: "checkmark", isPrimary: true) {
                        Task {
                            await authService.verifySignupOTP(email: email, token: otp)
                            if authService.authState.isLoggedIn {
                                pendingOTPEmail = nil
                                await creditService.fetchBalance()
                                await loadPackages()
                                await creditService.claimTrial()
                            }
                        }
                    }
                    .disabled(otp.count < 6)

                    SettingsButton("Resend code", systemImage: "arrow.clockwise") {
                        Task {
                            await authService.resendSignupOTP(email: email)
                            if authService.authError == nil { otp = "" }
                        }
                    }
                    .disabled(authService.authState == .loading)

                    Button("Back") {
                        pendingOTPEmail = nil
                        otp = ""
                        authService.authError = nil
                    }
                    .font(.caption)

                    if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
                }

                if let error = authService.authError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    private func passwordResetCard(email: String) -> some View {
        SettingsCard(
            systemImage: "lock.rotation",
            title: "Reset Password",
            subtitle: "Enter the 6-digit code sent to \(email)"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("000000", text: $resetOTP)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .onChange(of: resetOTP) { newValue in
                        resetOTP = String(newValue.filter(\.isNumber).prefix(6))
                    }

                SecureField("New password", text: $newPassword)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    SettingsButton("Update Password", systemImage: "checkmark", isPrimary: true) {
                        Task {
                            await authService.resetPassword(
                                email: email,
                                token: resetOTP,
                                newPassword: newPassword
                            )
                            if authService.authState.isLoggedIn {
                                pendingPasswordResetEmail = nil
                                resetOTP = ""
                                newPassword = ""
                                await creditService.fetchBalance()
                                await loadPackages()
                            }
                        }
                    }
                    .disabled(resetOTP.count < 6 || newPassword.count < 6)

                    SettingsButton("Resend code", systemImage: "arrow.clockwise") {
                        Task {
                            await authService.sendPasswordResetOTP(email: email)
                            if authService.authError == nil { resetOTP = "" }
                        }
                    }
                    .disabled(authService.authState == .loading)

                    Button("Back") {
                        pendingPasswordResetEmail = nil
                        resetOTP = ""
                        newPassword = ""
                        authService.authError = nil
                    }
                    .font(.caption)

                    if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
                }

                if let error = authService.authError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Private

    private func loadPackages() async {
        do {
            packages = try await PaymentService().fetchPackages()
        } catch {
            print("[SettingsAccountTab] loadPackages failed: \(error)")
        }
    }

    private func purchasePackage(_ pkg: TopupPackage) async {
        do {
            qrInfo = try await PaymentService().createQR(packageId: pkg.id)
        } catch {
            print("[SettingsAccountTab] createQR failed: \(error)")
        }
    }
}

// MARK: - PackageCard

private struct PackageCard: View {
    let package: TopupPackage
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Text("\(package.credits)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("credits").font(.caption2).foregroundStyle(.secondary)
                Text(package.formattedPrice)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Get Now")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.08)) }
        }
        .buttonStyle(.plain)
    }
}
