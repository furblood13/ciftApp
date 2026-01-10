//
//  TodoListView.swift
//  ciftApp
//
//  Us & Time - Full Todo List View
//

import SwiftUI

struct TodoListView: View {
    @Bindable var todoManager: TodoManager
    @State private var showAddSheet = false
    @State private var showCompleted = true
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.97),
                    Color(red: 0.98, green: 0.94, blue: 0.94),
                    Color(red: 0.98, green: 0.87, blue: 0.87)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if todoManager.todos.isEmpty && !todoManager.isLoading {
                    emptyState
                } else {
                    List {
                        // Incomplete Section
                        if !todoManager.incompleteTodos.isEmpty {
                            Section {
                                ForEach(todoManager.incompleteTodos) { todo in
                                    todoRow(todo)
                                }
                                .onDelete { indexSet in
                                    deleteTodos(at: indexSet, from: todoManager.incompleteTodos)
                                }
                            } header: {
                                Text(String(localized: "todo.incomplete", defaultValue: "To-Do (\(todoManager.incompleteTodos.count))"))
                                    .font(.subheadline)
                                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                            }
                        }
                        
                        // Completed Section
                        if !todoManager.completedTodos.isEmpty {
                            Section {
                                if showCompleted {
                                    ForEach(todoManager.completedTodos) { todo in
                                        todoRow(todo)
                                    }
                                    .onDelete { indexSet in
                                        deleteTodos(at: indexSet, from: todoManager.completedTodos)
                                    }
                                }
                            } header: {
                                Button {
                                    withAnimation {
                                        showCompleted.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text(String(localized: "todo.completed", defaultValue: "Completed (\(todoManager.completedTodos.count))"))
                                            .font(.subheadline)
                                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                                        Spacer()
                                        Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.55))
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            
            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.85, green: 0.5, blue: 0.55))
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle(String(localized: "todo.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            AddTodoSheet(todoManager: todoManager)
        }
        .task {
            await todoManager.fetchTodos()
            await todoManager.startListening()
        }
        .onDisappear {
            todoManager.stopListening()
        }
        .refreshable {
            await todoManager.fetchTodos()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.85, green: 0.5, blue: 0.55).opacity(0.5))
            
            Text(String(localized: "todo.empty.title"))
                .font(.headline)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            
            Text(String(localized: "todo.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func todoRow(_ todo: Todo) -> some View {
        Button {
            Task {
                await todoManager.toggleComplete(todo)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? Color.green : Color(red: 0.7, green: 0.6, blue: 0.65))
                    .font(.title3)
                
                Text(todo.title)
                    .foregroundStyle(todo.isCompleted ? Color(red: 0.6, green: 0.5, blue: 0.55) : Color(red: 0.3, green: 0.2, blue: 0.25))
                    .strikethrough(todo.isCompleted)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.7))
    }
    
    private func deleteTodos(at offsets: IndexSet, from list: [Todo]) {
        for index in offsets {
            let todo = list[index]
            Task {
                await todoManager.deleteTodo(todo)
            }
        }
    }
}
