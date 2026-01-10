//
//  TimelineComponents.swift
//  ciftApp
//
//  Shared UI Components for Timeline
//

import SwiftUI

// MARK: - Event Tag
struct EventTag: View {
    let text: String
    var icon: String? = nil
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundStyle(color)
    }
}

// MARK: - Severity Badge
struct SeverityBadge: View {
    let severity: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10) { index in
                Circle()
                    .fill(index < severity ? severityColor : .gray.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(severityColor.opacity(0.1))
        )
    }
    
    private var severityColor: Color {
        if severity <= 3 { return .green }
        if severity <= 6 { return .orange }
        return .red
    }
}
