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
                            description: "Draw paths to connect matching colored terminals. The arriving signal must match the target's expected state (Active or Inactive)."
                        )
                        ruleItem(
                            icon: "location.fill",
                            title: "Visit Waypoints",
                            description: "Some levels have mandatory waypoints that your path must pass through to win."
                        )
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

                    // Star Goals
                    Text("Star Goals")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        starGoalItem(
                            stars: 1,
                            title: "Circuit Complete",
                            description: "All terminals powered with correct signal + all waypoints visited."
                        )
                        starGoalItem(
                            stars: 2,
                            title: "Good Flow",
                            description: "Complete the circuit and cover at least 80% of the grid."
                        )
                        starGoalItem(
                            stars: 3,
                            title: "Full Circuit",
                            description: "Complete the circuit using 100% of the board's cells."
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
                            title: "Spark",
                            description: "Energizes a signal. An inactive path becomes active after passing through. Has no effect on a path that is already active.",
                            symbol: "bolt.fill",
                            color: .yellow
                        )
                        logicElementItem(
                            title: "Inverter",
                            description: "Flips a signal's state. Active becomes inactive and inactive becomes active. The path color is unchanged. Some Inverters only trigger when entered from a specific direction.",
                            symbol: "arrow.triangle.2.circlepath",
                            color: .orange
                        )
                        logicElementItem(
                            title: "Bridge",
                            description: "Allows two paths of different colors to cross each other without mixing their signals or colors.",
                            symbol: "arrow.triangle.branch",
                            color: .cyan
                        )
                        logicElementItem(
                            title: "Synthesizer",
                            description: "Requires two input paths. Combines their colors into a mixed output (Blue+Red → Purple, Red+Yellow → Orange, Blue+Yellow → Green). Signal output uses OR or XOR logic.",
                            symbol: "arrow.triangle.merge",
                            color: .purple
                        )
                        logicElementItem(
                            title: "Waypoint",
                            description: "A mandatory checkpoint that your path must pass through to complete the level.",
                            symbol: "circle.circle.fill",
                            color: .green
                        )
                    }

                    // Color mixing reference
                    Text("Color Mixing")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        colorMixRow(lhs: .blue, rhs: .red, result: .purple)
                        colorMixRow(lhs: .red, rhs: .yellow, result: .orange)
                        colorMixRow(lhs: .blue, rhs: .yellow, result: .green)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How to Play Circuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
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

    private func starGoalItem(stars: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(1...3, id: \.self) { i in
                    Image(systemName: i <= stars ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(i <= stars ? .yellow : .primary.opacity(0.2))
                }
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func colorMixRow(lhs: NeonColor, rhs: NeonColor, result: NeonColor) -> some View {
        HStack(spacing: 8) {
            Circle().fill(lhs.swiftUIColor).frame(width: 24, height: 24)
            Text("+")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Circle().fill(rhs.swiftUIColor).frame(width: 24, height: 24)
            Text("=")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Circle().fill(result.swiftUIColor).frame(width: 24, height: 24)
            Text(result.rawValue.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

#Preview {
    CircuitTutorialView()
}
