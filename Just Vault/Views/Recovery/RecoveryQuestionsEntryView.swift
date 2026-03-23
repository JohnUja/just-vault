//
//  RecoveryQuestionsEntryView.swift
//  Just Vault
//
//  Shown when key is not in Keychain but user has recovery questions in cloud.
//  Show one random question; on correct answer unwrap and store key.
//

import SwiftUI

struct RecoveryQuestionsEntryView: View {
    @EnvironmentObject var authService: AuthenticationService
    let userId: String
    let onRecovered: () -> Void
    let onUseRecoveryPhrase: () -> Void
    /// When non-nil, show "Back to recovery phrase" so user can switch to entering the phrase instead.
    var onBackToRecoveryPhrase: (() -> Void)? = nil

    @State private var questions: [String] = []
    @State private var wrappedBlobs: [Data] = []
    @State private var displayedIndex: Int = 0  // which of 3 we're showing (random at load)
    @State private var answer = ""
    @State private var isUnlocking = false
    @State private var errorMessage: String?
    /// 3 attempts per question; each question has its own count and cooldown.
    @State private var retryCountPerQuestion: [Int] = [0, 0, 0]
    @State private var lockoutUntilPerQuestion: [Double] = [0, 0, 0]  // timeIntervalSince1970; 0 = no lockout
    @State private var lockoutLevelPerQuestion: [Int] = [0, 0, 0]       // 1 = 1min, 2 = 5min, 3+ = 30min
    @State private var cooldownTick: Date = Date()  // refresh so countdown updates every second
    @State private var showDeleteMyAccountSheet = false
    @State private var deleteMyAccountText = ""
    @State private var showFinalDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var hasNoRecoveryQuestions = false
    @State private var loadQuestionsFailed = false
    private let maxRetriesPerQuestion = 3
    private let cooldownSeconds: [Int] = [0, 60, 5*60, 30*60]  // index 0 unused; 1→1min, 2→5min, 3→30min

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if onBackToRecoveryPhrase != nil {
                        HStack {
                            Button(action: { onBackToRecoveryPhrase?() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                    Text("Back to recovery phrase")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(AppTheme.accent)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.accent)

                    Text("Unlock your vault")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.headerTint)

                    if hasNoRecoveryQuestions || loadQuestionsFailed {
                        Text(loadQuestionsFailed ? "Could not load recovery questions." : "No recovery questions set for this account.")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                        Button(action: onUseRecoveryPhrase) {
                            Text("Use recovery phrase instead")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                        }
                        .padding(.top, 8)
                    } else if !questions.isEmpty && displayedIndex < questions.count {
                        Text(questions[displayedIndex])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                        if questions.count > 1 {
                            Button(action: tryDifferentQuestion) {
                                Text("Try a different question")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.accent)
                            }
                            .padding(.top, 4)
                        }
                    }

                    if !hasNoRecoveryQuestions && !loadQuestionsFailed {
                    TextField("Your answer", text: $answer)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .foregroundStyle(AppTheme.headerTint)
                        .tint(AppTheme.accent)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.outline, lineWidth: 1)
                        )
                        .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }

                    if isCurrentQuestionLocked, remainingCooldownSeconds > 0 {
                        Text(cooldownMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: unlockWithAnswer) {
                        HStack {
                            if isUnlocking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Unlock vault")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit ? AppTheme.accentGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                    }
                    .disabled(!canSubmit)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    }

                    if !hasNoRecoveryQuestions && !loadQuestionsFailed {
                    Button(action: onUseRecoveryPhrase) {
                        Text("Use recovery phrase instead")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.top, 8)
                    }

                    Spacer(minLength: 20)
                    Button(action: { showDeleteMyAccountSheet = true }) {
                        Text("I can't recover — delete my account")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showDeleteMyAccountSheet) {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button("Cancel") { showDeleteMyAccountSheet = false }
                        .foregroundColor(AppTheme.accent)
                }

                Text("Type the phrase to confirm")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.headerTint)

                Text("DELETE MY ACCOUNT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("DELETE MY ACCOUNT", text: $deleteMyAccountText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(AppTheme.headerTint)
                    .tint(AppTheme.accent)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.outline, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                Button {
                    showFinalDeleteAlert = true
                } label: {
                    Text("Delete account and all data")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(deleteMyAccountText == "DELETE MY ACCOUNT" ? Color.red : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(deleteMyAccountText != "DELETE MY ACCOUNT")
                .padding(.horizontal, 20)
                .padding(.top, 6)

                Text("This permanently deletes your account and all data from the app and cloud.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 10)
            .presentationDetents([.medium])
        }
        .alert("Delete account?", isPresented: $showFinalDeleteAlert) {
            Button("Delete account and all data", role: .destructive) {
                showDeleteMyAccountSheet = false
                deleteAccountAndSignOut()
            }
            Button("I change my mind", role: .cancel) {
                showFinalDeleteAlert = false
            }
        }
        .overlay {
            if isDeletingAccount {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Deleting…")
                    .tint(.white)
            }
        }
        .alert("Could not delete account", isPresented: .constant(deleteAccountError != nil)) {
            Button("OK") { deleteAccountError = nil }
        } message: {
            if let msg = deleteAccountError { Text(msg) }
        }
        .task {
            await loadQuestions()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isCurrentQuestionLocked { cooldownTick = Date() }
        }
    }

    private func deleteAccountAndSignOut() {
        isDeletingAccount = true
        deleteAccountError = nil
        Task {
            do {
                try await authService.deleteAccount(userId: userId)
                await MainActor.run { isDeletingAccount = false }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountError = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
                }
            }
        }
    }

    private var canSubmit: Bool {
        !answer.trimmingCharacters(in: .whitespaces).isEmpty && !isUnlocking && !isCurrentQuestionLocked
    }

    private var isCurrentQuestionLocked: Bool {
        guard displayedIndex < lockoutUntilPerQuestion.count else { return false }
        return Date().timeIntervalSince1970 < lockoutUntilPerQuestion[displayedIndex]
    }

    private var remainingCooldownSeconds: Int {
        guard displayedIndex < lockoutUntilPerQuestion.count else { return 0 }
        let until = lockoutUntilPerQuestion[displayedIndex]
        let remaining = until - Date().timeIntervalSince1970
        return max(0, Int(remaining.rounded()))
    }

    private var cooldownMessage: String {
        let mins = remainingCooldownSeconds / 60
        let secs = remainingCooldownSeconds % 60
        if mins > 0 {
            return "Too many wrong answers for this question. Try again in \(mins) minute\(mins == 1 ? "" : "s")."
        }
        return "Too many wrong answers for this question. Try again in \(secs) second\(secs == 1 ? "" : "s")."
    }

    private func tryDifferentQuestion() {
        guard questions.count > 1 else { return }
        displayedIndex = (displayedIndex + 1) % questions.count
        answer = ""
        errorMessage = nil
    }

    private func loadQuestions() async {
        do {
            guard let data = try await DynamoDBService.shared.loadRecoveryQuestions(userId: userId) else {
                await MainActor.run { hasNoRecoveryQuestions = true }
                return
            }
            await MainActor.run {
                questions = data.questions
                wrappedBlobs = data.wrappedBlobs
                displayedIndex = Int.random(in: 0..<min(3, data.questions.count))
            }
        } catch {
            await MainActor.run { loadQuestionsFailed = true }
        }
    }

    private func unlockWithAnswer() {
        guard displayedIndex < wrappedBlobs.count,
              displayedIndex < retryCountPerQuestion.count,
              displayedIndex < lockoutUntilPerQuestion.count,
              !answer.trimmingCharacters(in: .whitespaces).isEmpty,
              !isCurrentQuestionLocked else { return }
        errorMessage = nil
        isUnlocking = true
        Task {
            do {
                let masterKey = try RecoveryService.shared.unwrapMasterKeyWithRecoveryAnswer(
                    wrappedBlob: wrappedBlobs[displayedIndex],
                    userId: userId,
                    questionIndex: displayedIndex,
                    answer: answer
                )
                try RecoveryService.shared.storeRecoveredMasterKey(masterKey)
                await MainActor.run {
                    isUnlocking = false
                    onRecovered()
                }
            } catch {
                await MainActor.run {
                    isUnlocking = false
                    let idx = displayedIndex
                    retryCountPerQuestion[idx] += 1
                    errorMessage = "Incorrect answer. Try again."
                    if retryCountPerQuestion[idx] >= maxRetriesPerQuestion {
                        let level = min(lockoutLevelPerQuestion[idx] + 1, 3)
                        lockoutLevelPerQuestion[idx] = level
                        let duration = level < cooldownSeconds.count ? cooldownSeconds[level] : cooldownSeconds[3]
                        lockoutUntilPerQuestion[idx] = Date().timeIntervalSince1970 + Double(duration)
                        retryCountPerQuestion[idx] = 0
                        errorMessage = "Too many wrong answers for this question. Try again in \(duration == 60 ? "1 minute" : duration == 300 ? "5 minutes" : "30 minutes")."
                    }
                }
            }
        }
    }
}
