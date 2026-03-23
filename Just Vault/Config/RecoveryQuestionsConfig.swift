//
//  RecoveryQuestionsConfig.swift
//  Just Vault
//
//  Predefined recovery questions (user picks 3 + answers). See RECOVERY_QUESTIONS_DESIGN.md.
//

import Foundation

struct RecoveryQuestionsConfig {
    /// Predefined list; user picks 3 and enters their answer for each. IDs are 1-based.
    static let allQuestions: [(id: Int, text: String)] = [
        (1, "What was your first pet's name?"),
        (2, "What was your first love's, girlfriend's, or boyfriend's first name?"),
        (3, "What was your driving instructor's first name?"),
        (4, "What was the name of the first school you attended?"),
        (5, "What city were you born in?"),
        (6, "What is the name of a college you applied to but didn't attend?"),
        (7, "Where was the destination of your most memorable school field trip?"),
        (8, "What was your childhood nickname?"),
        (9, "What is your mother's maiden name?"),
        (10, "What was the name of your first boss?"),
        (11, "What street did you live on when you were 10?"),
        (12, "What was the first concert you attended?")
    ]

    static func questionText(id: Int) -> String? {
        allQuestions.first(where: { $0.id == id })?.text
    }

    /// Id for a question text (exact match). Used when loading saved questions so "Change recovery questions" shows the user's actual choices.
    static func questionId(text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return allQuestions.first(where: { $0.text == trimmed })?.id
    }
}
