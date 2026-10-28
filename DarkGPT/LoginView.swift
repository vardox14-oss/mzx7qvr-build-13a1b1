import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var twoFactorCode = ""
    @State private var showTwoFactor = false
    @State private var showPassword = false
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?

    enum Field { case email, password, code }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()
            if Season.isHalloween {
                SpiderWeb().frame(width: 190, height: 190)
                    .frame(maxWidth: .infinity, alignment: .trailing).ignoresSafeArea()
            }
            ScrollView {
                VStack(spacing: 20) {
                    brandBar
                    OrbitHero().padding(.top, 2)
                    hero
                    if showTwoFactor { twoFactorCard } else { loginCard }
                    footerLinks
                    if Season.isHalloween { pumpkinRow }
                }
                .padding(.horizontal, 22).padding(.bottom, 30)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var brandBar: some View {
        HStack(spacing: 8) {
            Image("Logo").resizable().scaledToFit().frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("Dark").font(.title3.weight(.heavy)) + Text("GPT").font(.title3.weight(.heavy)).foregroundColor(Theme.accent)
            Spacer()
            if Season.isHalloween { Text("🎃").font(.title3) }
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 8) {
            (Text("Toutes les meilleures IA.\n").foregroundColor(.white)
             + Text("Sans refus.").foregroundColor(Theme.accent))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Claude, Gemini, Grok, DeepSeek, Mistral… 42 modèles dans une seule app, sans leçons de morale.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .padding(.top, 4)
    }

    private var footerLinks: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("Pas encore de compte ?").font(.footnote).foregroundStyle(Theme.faint)
                Link("Crée-le gratuitement", destination: URL(string: "https://darkgpt.chat/login#inscription")!)
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            HStack(spacing: 16) {
                Link("Modèles", destination: URL(string: "https://darkgpt.chat/modeles")!)
                Link("Tarifs", destination: URL(string: "https://darkgpt.chat/tarifs")!)
                Link("Support", destination: URL(string: "https://darkgpt.chat/support")!)
            }
            .font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(.top, 4)
    }

    private var pumpkinRow: some View {
        HStack(spacing: 6) {
            Text("🕸️"); Text("🎃"); Text("👻"); Text("🎃"); Text("🕷️")
        }
        .font(.callout).opacity(0.8).padding(.top, 2)
    }
}

// MARK: - Cards
extension LoginView {
    private var loginCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Content de te revoir").font(.title3.weight(.bold)).foregroundStyle(.white)
                Text("Connecte-toi pour retrouver tes conversations et tes gems.")
                    .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }

            segmentedTabs

            HStack(spacing: 10) {
                googleButton
                discordButton
            }

            dividerOr

            field(icon: "envelope.fill", placeholder: "Adresse email", text: $email, field: .email)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            passwordField

            HStack {
                Spacer()
                Link("Mot de passe oublié ?", destination: URL(string: "https://darkgpt.chat/login")!)
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            if let error { errorLabel(error) }
            primaryButton("Se connecter  →") { await submitLogin() }

            Text("En te connectant, tu acceptes nos conditions d'utilisation. Service réservé aux personnes majeures.")
                .font(.caption2).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
        }
        .padding(20)
        .cardStyle(radius: 20)
    }

    private var segmentedTabs: some View {
        HStack(spacing: 6) {
            Text("Connexion")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Link(destination: URL(string: "https://darkgpt.chat/login#inscription")!) {
                Text("Inscription")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
        }
        .padding(4)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
    }

    private var googleButton: some View {
        Button { Task { await signInOAuth("google") } } label: {
            HStack(spacing: 8) {
                Text("G").font(.headline.weight(.black)).foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Google").fontWeight(.semibold).foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .disabled(busy)
    }

    private var discordButton: some View {
        Button { Task { await signInOAuth("discord") } } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Discord").fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(Color(red: 0.35, green: 0.40, blue: 0.95), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .disabled(busy)
    }

    private var dividerOr: some View {
        HStack {
            Rectangle().fill(Theme.stroke).frame(height: 1)
            Text("ou avec ton email").font(.caption2).foregroundStyle(Theme.faint).fixedSize()
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    private var passwordField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.faint).frame(width: 20)
            Group {
                if showPassword {
                    TextField("", text: $password, prompt: Text("Mot de passe").foregroundColor(Theme.faint))
                } else {
                    SecureField("", text: $password, prompt: Text("Mot de passe").foregroundColor(Theme.faint))
                }
            }
            .focused($focus, equals: .password).foregroundStyle(.white)
            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focus == .password ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1))
    }

    private var twoFactorCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Vérification en deux étapes").font(.headline).foregroundStyle(.white)
            Text("Entre le code à 6 chiffres envoyé à ton email.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            field(icon: "number", placeholder: "000000", text: $twoFactorCode, field: .code).keyboardType(.numberPad)
            if let error { errorLabel(error) }
            primaryButton("Vérifier") { await submitTwoFactor() }
            Button("Annuler") { showTwoFactor = false; error = nil }.font(.footnote).foregroundStyle(Theme.muted)
        }
        .padding(20).cardStyle(radius: 20)
    }
}

// MARK: - Shared components & actions
extension LoginView {
    private func field(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.faint).frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Theme.faint))
                .focused($focus, equals: field).foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focus == field ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1))
    }

    private func primaryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Haptics.tap(); Task { await action() }
        } label: {
            ZStack {
                if busy { ProgressView().tint(.white) } else { Text(title).fontWeight(.bold) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .foregroundStyle(.white).disabled(busy)
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
            switch try await APIClient.shared.loginEmail(email: email, password: password) {
            case .needsTwoFactor: withAnimation { showTwoFactor = true }
            case .success: await loadProfileAndEnter()
            }
        } catch { self.error = error.localizedDescription; Haptics.error() }
        busy = false
    }

    private func submitTwoFactor() async {
        focus = nil; busy = true; error = nil
        do {
            try await APIClient.shared.verifyTwoFactor(code: twoFactorCode)
            await loadProfileAndEnter()
        } catch { self.error = error.localizedDescription; Haptics.error() }
        busy = false
    }

    private func signInOAuth(_ provider: String) async {
        Haptics.tap(); busy = true; error = nil
        do {
            try await OAuthSession.shared.signIn(provider: provider)
            await loadProfileAndEnter()
        } catch {
            if (error as NSError).code != 1 { self.error = error.localizedDescription }
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
