//
//  MentionsSuggestionsViewModel.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 24.06.2025.
//

import Combine

final class MentionsSuggestionsViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var query: String = ""
    @Published var suggestions: [User] = []
    @Published var partial: String = ""

    var allUsers: [User] = []
    var isGroup: Bool = false

    func updateSuggestions(for query: String) {
        guard isGroup else {
            reset()
            return
        }

        self.query = query

        if query.isEmpty {
            suggestions = allUsers.filter { !$0.isCurrentUser }
        } else {
            suggestions = allUsers.filter {
                !$0.isCurrentUser && $0.name.lowercased().contains(query.lowercased())
            }
        }
        isVisible = !suggestions.isEmpty
    }

    func reset() {
        query = ""
        suggestions = []
        isVisible = false
    }
    
    func setContext(users: [User], isGroup: Bool) {
        guard self.allUsers.isEmpty else { return }
        self.allUsers = users
        self.isGroup = isGroup
    }
}
