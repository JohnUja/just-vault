//
//  Just_VaultApp.swift
//  Just Vault
//
//  Created by John Uja on 2026-01-23.
//

import SwiftUI
import AuthenticationServices

private let kHasAcceptedTerms = "hasAcceptedTermsAndConditions"

@main
struct Just_VaultApp: App {
    @StateObject private var authService = AuthenticationService()
    @AppStorage(kHasAcceptedTerms) private var hasAcceptedTerms = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SyncService.shared.registerBackgroundSync()
    }

    var body: some Scene {
        WindowGroup {
            if !hasAcceptedTerms {
                WelcomeAndTermsFlowView(hasAcceptedTerms: $hasAcceptedTerms)
            } else if authService.isAuthenticated {
                AuthenticatedRootView()
                    .environmentObject(authService)
            } else {
                SignInView()
                    .environmentObject(authService)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await StoreKitService.shared.updatePurchasedProducts()
                    await StoreKitService.shared.applyTierToCurrentUser()
                }
            case .background:
                SyncService.shared.scheduleBackgroundSync()
            default:
                break
            }
        }
    }
}

/// Recovery flow: Keychain → Recovery questions (1 of 3) → Recovery phrase (last resort). New users see SetRecoveryQuestionsView (mandatory).
struct AuthenticatedRootView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showRecoveryQuestionsEntry = false
    @State private var showRecoveryPhraseEntry = false
    @State private var recoveryCameFromQuestions = false
    @State private var recoveryCameFromPhrase = false
    @State private var showSetRecoveryQuestions = false
    @State private var showAskUserName = false
    @State private var recoveryCheckDone = false
    @State private var showKeyStorageFailed = false  // Keychain couldn't store key (device full/restricted)
    @State private var showCloudUnreachable = false  // Couldn't load recovery data from cloud; don't create new key
    @State private var keyStorageRetryAttempt = 0
    @State private var showSessionExpiredBanner = false
    @State private var isRefreshingSession = false

    var body: some View {
        Group {
            if showCloudUnreachable {
                cloudUnreachableView
            } else if showKeyStorageFailed {
                keyStorageFailedView
            } else if showSetRecoveryQuestions, let userId = authService.currentUser?.id {
                SetRecoveryQuestionsView(userId: userId) {
                    showSetRecoveryQuestions = false
                    let name = authService.currentUser?.name?.trimmingCharacters(in: .whitespaces) ?? ""
                    if name.isEmpty { showAskUserName = true }
                }
                .environmentObject(authService)
            } else if showAskUserName, let userId = authService.currentUser?.id {
                AskUserNameView(userId: userId) {
                    showAskUserName = false
                }
                .environmentObject(authService)
            } else if showRecoveryQuestionsEntry, let userId = authService.currentUser?.id {
                RecoveryQuestionsEntryView(
                    userId: userId,
                    onRecovered: { showRecoveryQuestionsEntry = false },
                    onUseRecoveryPhrase: {
                        recoveryCameFromQuestions = true
                        showRecoveryQuestionsEntry = false
                        showRecoveryPhraseEntry = true
                    },
                    onBackToRecoveryPhrase: recoveryCameFromPhrase ? {
                        showRecoveryQuestionsEntry = false
                        showRecoveryPhraseEntry = true
                    } : nil
                )
                .environmentObject(authService)
            } else if showRecoveryPhraseEntry, let userId = authService.currentUser?.id {
                RecoveryPhraseEntryView(
                    userId: userId,
                    onRecovered: { showRecoveryPhraseEntry = false },
                    onBackToRecoveryQuestions: {
                        recoveryCameFromPhrase = true
                        showRecoveryPhraseEntry = false
                        showRecoveryQuestionsEntry = true
                    }
                )
                .environmentObject(authService)
            } else {
                VaultHomeView()
                    .environmentObject(authService)
            }
        }
        .overlay(alignment: .top) {
            if showSessionExpiredBanner {
                sessionExpiredBanner
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .credentialsExpiredNeedsReSignIn)) { _ in
            showSessionExpiredBanner = true
        }
        .task(id: keyStorageRetryAttempt) {
            // id allows "Try again" after Keychain storage failure or cloud unreachable to re-run this task
            guard !recoveryCheckDone else { return }
            recoveryCheckDone = true
            guard let userId = authService.currentUser?.id else { return }
            // If user already has key, still ensure they have recovery data in cloud; if not, force SetRecoveryQuestions (recovery is mandatory).
            if SecureEnclaveManager.hasMasterKey() {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if SecureEnclaveManager.hasMasterKey() {
                    do {
                        let rq = try await DynamoDBService.shared.loadRecoveryQuestions(userId: userId)
                        let wk = try await DynamoDBService.shared.loadWrappedMasterKey(userId: userId)
                        if rq == nil && wk == nil {
                            await MainActor.run { showSetRecoveryQuestions = true; showCloudUnreachable = false; showKeyStorageFailed = false }
                            return
                        }
                    } catch {
                        // Offline or error — don't block vault access
                    }
                    return
                }
            }
            // No key: new device, reinstall, or Keychain failed. Recovery questions or phrase restore key; new users need key created before SetRecoveryQuestions
            let recoveryQuestions: DynamoDBService.RecoveryQuestionsData?
            let wrappedKey: Data?
            do {
                recoveryQuestions = try await DynamoDBService.shared.loadRecoveryQuestions(userId: userId)
                wrappedKey = try await DynamoDBService.shared.loadWrappedMasterKey(userId: userId)
            } catch {
                // Cloud load failed — do NOT create a new key; user may have a backup. Show retry.
                await MainActor.run {
                    showCloudUnreachable = true
                    showKeyStorageFailed = false
                }
                return
            }
            if let _ = recoveryQuestions {
                await MainActor.run { showRecoveryQuestionsEntry = true; showKeyStorageFailed = false; showCloudUnreachable = false }
                return
            }
            if let _ = wrappedKey {
                await MainActor.run { showRecoveryPhraseEntry = true; showKeyStorageFailed = false; showCloudUnreachable = false }
                return
            }
            // Successfully loaded from cloud and no recovery data: true new user. Create key on this device.
            do {
                try EncryptionService().ensureMasterKeyExists()
                await MainActor.run { showSetRecoveryQuestions = true; showKeyStorageFailed = false; showCloudUnreachable = false }
            } catch {
                await MainActor.run { showKeyStorageFailed = true }
            }
        }
    }

    /// Shown when we couldn't load recovery data from cloud (network/error). We do NOT create a new key so the user can retry and recover if they have a backup.
    private var cloudUnreachableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Couldn't reach cloud")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("We couldn't load your recovery backup. Check your connection and tap Retry. We won't create a new key until we've checked — so if you backed up your key, you can still recover when cloud is available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                recoveryCheckDone = false
                showCloudUnreachable = false
                keyStorageRetryAttempt += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient)
    }

    /// Shown only when creating the key for a new account (first sign-up): this device's Keychain failed to store the key. Not cloud or retrieval — local save failed.
    private var keyStorageFailedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Couldn’t save your vault key on this device")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("This device’s secure storage couldn’t store the key (not a cloud or network issue). Storage may be full or restricted. Free up space and tap Try again, or sign in on another device to set up there. You’re not locked out — use another device if this one keeps failing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try again") {
                recoveryCheckDone = false
                showKeyStorageFailed = false
                keyStorageRetryAttempt += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient)
    }
    
    private var sessionExpiredBanner: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Session expired. Sign in again, then retry (sync, backup, delete account, etc.).")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Button(isRefreshingSession ? "Signing in…" : "Sign in again") {
                    Task {
                        isRefreshingSession = true
                        do {
                            try await authService.signInWithApple()
                            await MainActor.run {
                                showSessionExpiredBanner = false
                            }
                        } catch {
                            await MainActor.run {
                                authService.errorMessage = error.localizedDescription
                            }
                        }
                        await MainActor.run { isRefreshingSession = false }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .disabled(isRefreshingSession)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// Launch Screen - shown on app start
struct LaunchScreenWrapper: View {
    @State private var showLaunch = true
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        Group {
            if showLaunch {
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showLaunch = false
                            }
                        }
                    }
            } else {
                if authService.isAuthenticated {
                    VaultHomeView()
                        .environmentObject(authService)
                } else {
                    SignInView()
                        .environmentObject(authService)
                }
            }
        }
    }
}

private let kIsReturningUser = "com.justvault.isReturningUser"

// Sign In / Sign Up — plan selector only for first-time users; returning users see compact sign-in.
struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    @AppStorage(kIsReturningUser) private var isReturningUser = false
    @State private var selectedBilling: BillingPeriod = .yearly
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var showPostSignUpIssue = false
    @State private var postSignUpIssueMessage = ""
    @State private var isRestoringPurchases = false
    @State private var showRestorePurchasesResult = false
    @State private var restorePurchasesResultMessage = ""

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: isReturningUser ? 28 : 32) {
                    justVaultHeader
                    if isReturningUser {
                        returningUserContent
                    } else {
                        firstTimeContent
                    }
                }
                .padding(.vertical, 40)
            }
        }
        .task {
            if !isReturningUser {
                await StoreKitService.shared.loadProducts()
            }
        }
        .alert("Subscription", isPresented: $showPostSignUpIssue) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(postSignUpIssueMessage)
        }
    }

    // App theme–aligned logo + JUST™ — smaller, not bold, so it doesn’t dominate
    private var justVaultHeader: some View {
        VStack(spacing: 14) {
            if let image = UIImage(named: "justvault") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .shadow(color: AppTheme.accent.opacity(0.25), radius: 10)
            } else {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("JUST")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(AppTheme.headerTint)
                Text("™")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.secondaryText)
                    .baselineOffset(4)
            }
        }
        .padding(.top, 8)
    }

    // Returning user: single Sign in with Apple, moved lower with a bit of centered copy so the page doesn’t feel thin
    private var returningUserContent: some View {
        VStack(spacing: 28) {
            Text("Welcome back")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.secondaryText)
            Text("Your encrypted vault is one sign-in away.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.secondaryText.opacity(0.9))
                .multilineTextAlignment(.center)
            Spacer(minLength: 24)
            appleButton(isSignUp: false)
            if let errorMessage = authService.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 48)
    }

    /// Same plan UI as Settings paywall; after Apple sign-up we start a StoreKit purchase for the selected paid plan (or stay on Free).
    private var firstTimeContent: some View {
        VStack(spacing: 22) {
            Text("Choose your plan, then sign up with Apple.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("Pro or Pro+: after Apple sign-in, you’ll confirm subscription in the App Store—your vault opens only after that (or choose Free to skip).")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppTheme.secondaryText.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)

            SubscriptionPlanPickerSection(
                selectedBilling: $selectedBilling,
                selectedTier: $selectedTier,
                currentEffectiveTier: nil,
                additionalSubtitle: "Change or upgrade anytime in Settings."
            )
            .padding(.horizontal, 12)

            signUpWithAppleSection

            Button {
                Task { await restorePurchasesFromSignUpScreen() }
            } label: {
                Group {
                    if isRestoringPurchases {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .disabled(isRestoringPurchases || authService.isLoading)
            .padding(.horizontal, 40)
            .padding(.top, 4)

            if let errorMessage = authService.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 40)
    }

    private var signUpWithAppleSection: some View {
        Group {
            if authService.isLoading {
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(height: 50)
            } else {
                SignInWithAppleButton(
                    onRequest: { $0.requestedScopes = [.fullName, .email] },
                    onCompletion: { result in
                        Task { await handleFirstTimeAppleSignIn(result) }
                    }
                )
                .frame(height: 50)
                .cornerRadius(12)
                .signInWithAppleButtonStyle(.white)
                Text("Sign up with Apple")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 40)
    }

    private func restorePurchasesFromSignUpScreen() async {
        await MainActor.run { isRestoringPurchases = true }
        do {
            try await StoreKitService.shared.restorePurchases()
            await MainActor.run {
                isRestoringPurchases = false
                restorePurchasesResultMessage =
                    "If you had an active subscription on this Apple ID, it’s restored on this device. Sign in with Apple to open your vault; your plan will apply after you’re signed in."
                showRestorePurchasesResult = true
            }
        } catch {
            await MainActor.run {
                isRestoringPurchases = false
                restorePurchasesResultMessage = error.localizedDescription
                showRestorePurchasesResult = true
            }
        }
    }

    private func handleFirstTimeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            await MainActor.run { authService.errorMessage = error.localizedDescription }
        case .success(let authorization):
            do {
                if selectedTier == .free {
                    // Free: enter the app immediately after Apple sign-in.
                    try await authService.completeSignIn(with: authorization, enterApp: true)
                    await MainActor.run { isReturningUser = true }
                    return
                }

                // Paid: complete Apple + Cognito + local user first, but do NOT switch to the main app
                // until after the App Store purchase sheet succeeds — otherwise recovery/onboarding runs “under” IAP.
                try await authService.completeSignIn(with: authorization, enterApp: false)

                await StoreKitService.shared.loadProducts()
                guard let product = StoreKitService.shared.getProduct(for: selectedTier, billing: selectedBilling) else {
                    await authService.revertPendingPaidSignUpSession()
                    await MainActor.run {
                        postSignUpIssueMessage =
                            "Subscriptions aren’t available right now. Try again later or choose Free—you can subscribe anytime in Settings."
                        showPostSignUpIssue = true
                    }
                    return
                }

                do {
                    let transaction = try await StoreKitService.shared.purchase(product)
                    await MainActor.run {
                        authService.isAuthenticated = true
                        isReturningUser = true
                    }
                    if transaction != nil {
                        await StoreKitService.shared.applyResolvedTierToUser(authService: authService)
                    }
                } catch {
                    if let sk = error as? StoreKitError, sk == .userCancelled {
                        await authService.revertPendingPaidSignUpSession()
                        return
                    }
                    if let sk = error as? StoreKitError, sk == .pending {
                        await authService.revertPendingPaidSignUpSession()
                        await MainActor.run {
                            postSignUpIssueMessage = "Purchase is pending approval. Try again in a moment or choose Free to continue."
                            showPostSignUpIssue = true
                        }
                        return
                    }
                    await authService.revertPendingPaidSignUpSession()
                    await MainActor.run {
                        postSignUpIssueMessage = error.localizedDescription
                        showPostSignUpIssue = true
                    }
                }
            } catch {
                await MainActor.run { authService.errorMessage = error.localizedDescription }
            }
        }
    }

    private func appleButton(isSignUp: Bool) -> some View {
        Group {
            if authService.isLoading {
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(height: 50)
            } else {
                SignInWithAppleButton(
                    onRequest: { $0.requestedScopes = [.fullName, .email] },
                    onCompletion: { result in
                        Task {
                            guard case .success(let authorization) = result else { return }
                            do {
                                try await authService.completeSignIn(with: authorization)
                            } catch {
                                await MainActor.run { authService.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                )
                .frame(height: 50)
                .cornerRadius(12)
                .signInWithAppleButtonStyle(.white)
                Text(isSignUp ? "Sign up with Apple" : "Sign in with Apple")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 40)
    }
}

// Blur View Helper
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Note: cornerRadius extension and RoundedCorner are defined in OnboardingFlowView.swift
