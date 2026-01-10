//
//  TodoManager.swift
//  ciftApp
//
//  Us & Time - Shared Todo Manager
//

import Foundation
import Observation
import Supabase

@Observable
final class TodoManager {
    var todos: [Todo] = []
    var isLoading = false
    var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    
    // MARK: - Fetch Todos
    @MainActor
    func fetchTodos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // Get couple_id from profile
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId else {
                print("🔴 [Todo] No couple_id found")
                return
            }
            
            // Fetch todos for this couple
            let fetchedTodos: [Todo] = try await supabase
                .from("todos")
                .select()
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.todos = fetchedTodos
            print("🟢 [Todo] Fetched \(fetchedTodos.count) todos")
            
        } catch {
            print("🔴 [Todo] Fetch error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Add Todo
    @MainActor
    func addTodo(title: String) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // Get couple_id
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId else {
                print("🔴 [Todo] No couple_id for add")
                return
            }
            
            // Insert new todo
            let newTodo: [String: AnyJSON] = [
                "couple_id": .string(coupleId.uuidString),
                "title": .string(title.trimmingCharacters(in: .whitespaces)),
                "is_completed": .bool(false),
                "created_by": .string(userId.uuidString)
            ]
            
            try await supabase
                .from("todos")
                .insert(newTodo)
                .execute()
            
            print("🟢 [Todo] Added: \(title)")
            await fetchTodos()
            
        } catch {
            print("🔴 [Todo] Add error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Toggle Complete
    @MainActor
    func toggleComplete(_ todo: Todo) async {
        do {
            let userId = try await supabase.auth.session.user.id
            let newState = !todo.isCompleted
            
            var updateData: [String: AnyJSON] = [
                "is_completed": .bool(newState)
            ]
            
            if newState {
                updateData["completed_by"] = .string(userId.uuidString)
                updateData["completed_at"] = .string(ISO8601DateFormatter().string(from: Date()))
            } else {
                updateData["completed_by"] = .null
                updateData["completed_at"] = .null
            }
            
            try await supabase
                .from("todos")
                .update(updateData)
                .eq("id", value: todo.id)
                .execute()
            
            print("🟢 [Todo] Toggled: \(todo.title) -> \(newState)")
            await fetchTodos()
            
        } catch {
            print("🔴 [Todo] Toggle error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Delete Todo
    @MainActor
    func deleteTodo(_ todo: Todo) async {
        do {
            try await supabase
                .from("todos")
                .delete()
                .eq("id", value: todo.id)
                .execute()
            
            print("🟢 [Todo] Deleted: \(todo.title)")
            await fetchTodos()
            
        } catch {
            print("🔴 [Todo] Delete error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Real-time Subscription
    @MainActor
    func startListening() async {
        do {
            let userId = try await supabase.auth.session.user.id
            
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId else { return }
            
            realtimeChannel = supabase.realtimeV2.channel("todos-\(coupleId.uuidString)")
            
            let changes = realtimeChannel?.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "todos",
                filter: "couple_id=eq.\(coupleId.uuidString)"
            )
            
            await realtimeChannel?.subscribe()
            
            Task {
                guard let changes = changes else { return }
                for await _ in changes {
                    await fetchTodos()
                }
            }
            
            print("🟢 [Todo] Real-time listening started")
            
        } catch {
            print("🔴 [Todo] Realtime error: \(error)")
        }
    }
    
    func stopListening() {
        Task {
            await realtimeChannel?.unsubscribe()
            realtimeChannel = nil
            print("🔵 [Todo] Stopped listening")
        }
    }
    
    // MARK: - Computed Properties
    var incompleteTodos: [Todo] {
        todos.filter { !$0.isCompleted }
    }
    
    var completedTodos: [Todo] {
        todos.filter { $0.isCompleted }
    }
}
