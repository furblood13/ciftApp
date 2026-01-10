//
//  AddTodoSheet.swift
//  ciftApp
//
//  Us & Time - Add New Todo Sheet
//

import SwiftUI

struct AddTodoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var todoManager: TodoManager
    @State private var title = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "todo.whatTodo"))
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    
                    TextField(String(localized: "todo.placeholder"), text: $title)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.98, green: 0.96, blue: 0.96))
                        )
                        .focused($isFocused)
                }
                
                Spacer()
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.97, blue: 0.97),
                        Color(red: 0.98, green: 0.94, blue: 0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(String(localized: "todo.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.add")) {
                        Task {
                            await todoManager.addTodo(title: title)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
