import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var twoFactorCode = ""
    @State private var showTwoFactor = false
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?

    enum Field { case email, password, code }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                if showTwoFactor { twoFactorCard } else { loginCard }
                footer
            }
            .padding(24)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image("Logo").resizable().scaledToFit().frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.35), radius: 18)
            Text("DarkGPT").font(.system(size: 30, weight: .heavy, design: .rounded))
            Text("L'IA non censurée, dans ta poche.")
                .font(.subheadline).foregroundStyle(Theme.muted)
        }
        .padding(.top, 36)
    }

    private var loginCard: some View {
        VStack(spacing: 14) {
            oauthButton(title: "Continuer avec Google", system: "globe", provider: "google")
            oauthButton(title: "Continuer avec Discord", system: "bubble.left.and.bubble.right.fill", provider: "discord")

            HStack {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                Text("ou").font(.caption).foregroundStyle(Theme.faint)
                Rectangle().fill(Theme.stroke).frame(height: 1)
            }.padding(.vertical, 4)

            field(icon: "envelope.fill", placeholder: "Adresse email", text: $email, field: .email)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            secureField(icon: "lock.fill", placeholder: "Mot de passe", text: $password, field: .password)

            if let error { errorLabel(error) }

            primaryButton("Se connecter") { await submitLogin() }

            Link("Mot de passe oublié ?", destination: URL(string: "https://darkgpt.chat/login")!)
                .font(.footnote).foregroundStyle(Theme.muted)
        }
        .padding(20)
        .cardStyle()
    }

    private var twoFactorCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Vérification en deux étapes").font(.headline)
            Text("Entre le code à 6 chiffres envoyé à ton email.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            field(icon: "number", placeholder: "000000", text: $twoFactorCode, field: .code)
                .keyboardType(.numberPad)
            if let error { errorLabel(error) }
            primaryButton("Vérifier") { await submitTwoFactor() }
            Button("Annuler") { showTwoFactor = false; error = nil }
                .font(.footnote).foregroundStyle(Theme.muted)
        }
        .padding(20)
        .cardStyle()
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Pas encore de compte ?").font(.footnote).foregroundStyle(Theme.faint)
            Link("Crée-en un sur darkgpt.chat", destination: URL(string: "https://darkgpt.chat/login#inscription")!)
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent2)
        }
        .padding(.top, 8)
    }
}

// MARK: - Components & actions
extension LoginView {
    private func oauthButton(title: String, system: String, provider: String) -> some View {
        Button {
            Task { await signInOAuth(provider) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: system)
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        }
        .foregroundStyle(.white)
        .disabled(busy)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.faint).frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Theme.faint))
                .focused($focus, equals: field)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(focus == field ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1))
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.faint).frame(width: 20)
            SecureField("", text: text, prompt: Text(placeholder).foregroundColor(Theme.faint))
                .focused($focus, equals: field)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(focus == field ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1))
    }

    private func primaryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Haptics.tap(); Task { await action() }
        } label: {
            ZStack {
                if busy { ProgressView().tint(.white) }
                else { Text(title).fontWeight(.bold) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .foregroundStyle(.white)
        .disabled(busy)
    }

    private func errorLabel(_ message: String) -> some View {
        Text(message).font(.footnote).foregroundStyle(Theme.accent2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submitLogin() async {
        focus = nil
        guard !email.isEmpty, !password.isEmpty else { error = "Entre ton email et ton mot de passe."; return }
        busy = true; error = nil
        do {
            let result = try await APIClient.shared.loginEmail(email: email, password: password)
            switch result {
            case .needsTwoFactor:
                withAnimation { showTwoFactor = true }
            case .success:
                await loadProfileAndEnter()
            }
        } catch { self.error = error.localizedDescription; Haptics.error() }
        busy = false
    }

    private func submitTwoFactor() async {
        focus = nil
        busy = true; error = nil
        do {
            try await APIClient.shared.verifyTwoFactor(code: twoFactorCode)
            await loadProfileAndEnter()
        } catch { self.error = error.localizedDescription; Haptics.error() }
        busy = false
    }

    private func signInOAuth(_ provider: String) async {
        busy = true; error = nil
        do {
            try await OAuthSession.shared.signIn(provider: provider)
            await loadProfileAndEnter()
        } catch {
            if (error as NSError).code != 1 { self.error = error.localizedDescription }  // ignore user cancel
        }
        busy = false
    }

    private func loadProfileAndEnter() async {
        do {
            let profile = try await APIClient.shared.me()
            Haptics.success()
            await app.finishLogin(profile)
        } catch { self.error = "Connexion établie mais profil introuvable. Réessaie." }
    }
}
