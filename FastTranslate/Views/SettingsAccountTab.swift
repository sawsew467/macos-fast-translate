import SwiftUI

struct SettingsAccountTab: View {
    @ObservedObject private var authService = SupabaseAuthService.shared
    @ObservedObject private var creditService = CreditService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var packages: [TopupPackage] = []
    @State private var showingQRSheet = false
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
        .sheet(isPresented: $showingQRSheet) {
            if let qr = qrInfo {
                PaymentQRSheetView(qrInfo: qr) { showingQRSheet = false }
            }
        }
    }

    // MARK: - Logged In

    @ViewBuilder
    private var loggedInContent: some View {
        SettingsCard(systemImage: "creditcard", title: "Balance",
                     subtitle: authService.authState.email ?? "") {
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
                                await authService.signup(email: email, password: password)
                            } else {
                                await authService.login(email: email, password: password)
                                if authService.authState.isLoggedIn {
                                    await creditService.fetchBalance()
                                    await loadPackages()
                                }
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)

                    Button(isSignup ? "Have account? Log in" : "New? Sign up") {
                        isSignup.toggle()
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
            showingQRSheet = true
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
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.08)) }
        }
        .buttonStyle(.plain)
    }
}
