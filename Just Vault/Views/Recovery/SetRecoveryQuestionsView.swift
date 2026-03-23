//
//  SetRecoveryQuestionsView.swift
//  Just Vault
//
//  Mandatory onboarding: user picks 3 recovery questions and enters answers.
//  See RECOVERY_QUESTIONS_DESIGN.md.
//

import SwiftUI

struct SetRecoveryQuestionsView: View {
    let userId: String
    let onComplete: () -> Void
    /// When non-nil (e.g. "Change recovery questions" from Settings), pre-load these so the form shows the user's actual saved questions.
    var existingQuestionTexts: [String]? = nil
    @EnvironmentObject private var authService: AuthenticationService

    @State private var selectedIds: [Int] = [1, 2, 3]  // 1-based, distinct
    @State private var answers: [String] = ["", "", ""]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasLoadedExisting = false

    private let denylist = Set(["a", "123", "password", "test", "answer"])

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.accent)

                    Text("Set recovery questions")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.headerTint)

                    Text("Pick 3 questions and enter answers. You'll need one of these to recover your vault on a new device. Answers are case-insensitive.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(.bottom, 8)

                    ForEach(0..<3, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Question \(index + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)
                            Picker("", selection: $selectedIds[index]) {
                                ForEach(availableQuestionIds(for: index), id: \.self) { id in
                                    Text(RecoveryQuestionsConfig.questionText(id: id) ?? "?").tag(id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.accent)
                            .foregroundStyle(AppTheme.headerTint)

                            TextField("Your answer", text: $answers[index])
                                .textContentType(.none)
                                .autocorrectionDisabled()
                                .foregroundStyle(AppTheme.headerTint)
                                .tint(AppTheme.accent)
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.outline, lineWidth: 1)
                                )
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                            .padding(.top, 4)
                    }

                    Button(action: saveAndContinue) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canContinue ? AppTheme.accentGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                    }
                    .disabled(!canContinue || isSaving)
                    .padding(.top, 16)
                }
                .padding(24)
            }
        }
        .task {
            await loadExistingQuestionsIfNeeded()
        }
    }

    /// When opening for "Change recovery questions", load the user's saved questions so the pickers show the same questions they originally picked.
    private func loadExistingQuestionsIfNeeded() async {
        guard !hasLoadedExisting else { return }
        let textsToUse: [String]
        if let existing = existingQuestionTexts, existing.count == 3 {
            textsToUse = existing
        } else if let data = try? await DynamoDBService.shared.loadRecoveryQuestions(userId: userId), data.questions.count == 3 {
            textsToUse = data.questions
        } else {
            await MainActor.run { hasLoadedExisting = true }
            return
        }
        let ids = textsToUse.compactMap { RecoveryQuestionsConfig.questionId(text: $0) }
        guard ids.count == 3 else {
            await MainActor.run { hasLoadedExisting = true }
            return
        }
        await MainActor.run {
            selectedIds = ids
            hasLoadedExisting = true
        }
    }

    private var canContinue: Bool {
        guard answers.allSatisfy({ $0.count >= 2 }),
              answers.allSatisfy({ !denylist.contains(RecoveryService.normalizeAnswer($0)) }) else {
            return false
        }
        return Set(selectedIds).count == 3
    }

    private func availableQuestionIds(for index: Int) -> [Int] {
        let otherIds = Set(selectedIds.enumerated().filter { $0.offset != index }.map(\.element))
        return RecoveryQuestionsConfig.allQuestions.map(\.id).filter { id in
            !otherIds.contains(id) || id == selectedIds[index]
        }
    }

    private func saveAndContinue() {
        guard canContinue, let userId = UserDefaults.standard.string(forKey: "currentUserId") else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await DynamoDBService.shared.initializeClient()
                // After account deletion the DynamoDB USER# profile was removed. Ensure it exists before saving recovery questions.
                if try await DynamoDBService.shared.loadUserProfile(userId: userId) == nil,
                   let user = authService.currentUser {
                    try await DynamoDBService.shared.saveUserProfile(user)
                }
                let qTexts = selectedIds.map { RecoveryQuestionsConfig.questionText(id: $0) ?? "" }
                let blobs = try RecoveryService.shared.wrapMasterKeyWithRecoveryAnswers(userId: userId, answers: answers)
                try await DynamoDBService.shared.saveRecoveryQuestions(userId: userId, questions: qTexts, wrappedBlobs: blobs)
                await MainActor.run {
                    isSaving = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not save. Try again."
                }
            }
        }
    }
}
