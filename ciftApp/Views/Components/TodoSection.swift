//
//  TodoSection.swift
//  ciftApp
//
//  Us & Time - Compact Todo Section for HomeView
//

import SwiftUI

struct TodoSection: View {
    @Bindable var todoManager: TodoManager
    var onShowAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(String(localized: "todo.title"))
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                Spacer()
                
                Button {
                    onShowAll()
                } label: {
                    Text(String(localized: "common.all"))
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.85, green: 0.5, blue: 0.55))
                }
            }
            
            // Todo Cards (max 3)
            if todoManager.incompleteTodos.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(todoManager.incompleteTodos.prefix(3)) { todo in
                        todoCard(todo)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.7))
        )
    }
    
    private var emptyState: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Color(red: 0.6, green: 0.8, blue: 0.6))
            Text(String(localized: "todo.empty.done"))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private func todoCard(_ todo: Todo) -> some View {
        Button {
            Task {
                await todoManager.toggleComplete(todo)
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? Color.green : Color(red: 0.7, green: 0.6, blue: 0.65))
                    .font(.title3)
                
                // Title
                Text(todo.title)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    .strikethrough(todo.isCompleted)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.98, green: 0.96, blue: 0.96))
            )
        }
        .buttonStyle(.plain)
    }
}
