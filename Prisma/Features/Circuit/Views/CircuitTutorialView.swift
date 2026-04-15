//
//  CircuitTutorialView.swift
//  Prisma
//
//  Interactive/visual tutorial for the Circuit game explaining the rules and gates.
//

import SwiftUI

struct CircuitTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    tutorialHeader
                    
                    VStack(spacing: 16) {
                        ruleItem(
                            icon: "point.bottomleft.forward.to.arrow.triangle.uturn.scurvepath.fill",
                            title: "Connect the Terminals",
                            description: "Draw paths to connect matching colored terminals. Ensure the signal matches the target terminal's state (Active or Inactive)."
                        )
                        ruleItem(
                            icon: "square.grid.2x2",
                            title: "100% Coverage (3 Stars)",
                            description: "The ultimate goal is to connect all terminals AND cover every single tile on the grid for a 3-star perfect clear."
                        )
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                    
                    Text("Logic Elements")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    VStack(spacing: 16) {
                        logicElementItem(
                            title: "NOT Gate",
                            description: "Inverts an incoming signal. Active becomes Inactive, and vice versa.",
                            symbol: "exclamationmark.circle.fill",
                            color: .red
                        )
                        logicElementItem(
                            title: "ColorShift Gate",
                            description: "Changes the color of the signal passing through to match the gate's output color.",
                            symbol: "drop.fill",
                            color: .blue
                        )
                        logicElementItem(
                            title: "Bridge",
                            description: "Allows two paths of different colors to cross each other without mixing their signals.",
                            symbol: "point.topleft.down.curvedto.point.bottomright.up",
                            color: .gray
                        )
                        logicElementItem(
                            title: "Synthesizer",
                            description: "Combines two separate paths using boolean logic (OR / XOR) to emit a single new signal.",
                            symbol: "arrow.merge",
                            color: .purple
                        )
                        logicElementItem(
                            title: "Waypoint",
                            description: "A mandatory checkpoint that your path must pass through to win the level.",
                            symbol: "circle.circle.fill",
                            color: .orange
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How to Play Circuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var tutorialHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.circuit)
                .padding(.bottom, 8)
            
            Text("Welcome to Circuit!")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("Guide energy streams through logical obstacles to power up the terminals.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }
    
    private func ruleItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.circuit)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
    
    private func logicElementItem(title: String, description: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

#Preview {
    CircuitTutorialView()
}
