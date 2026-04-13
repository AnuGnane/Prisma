//
//  HowToPlaySheet.swift
//  Prisma
//
//  A reusable tutorial sheet for each game, shown as a paging drawer.
//

import SwiftUI

struct HowToPlayStep: Identifiable {
    let id = UUID()
    let title: String
    let instruction: String
    let systemImage: String
    let color: Color
}

struct HowToPlaySheet: View {
    let gameType: GameType
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    private var steps: [HowToPlayStep] {
        switch gameType {
        case .signals:
            return [
                HowToPlayStep(title: "Deduce the Code", instruction: "Enter 4 digits to find the signal's hidden frequency.", systemImage: "key.viewfinder", color: AppTheme.signals),
                HowToPlayStep(title: "Decode Feedback", instruction: "Green = Right digit & spot. Yellow = Right digit, wrong spot. Gray = Absent.", systemImage: "lightbulb.fill", color: AppTheme.signals),
                HowToPlayStep(title: "Narrow it Down", instruction: "The High/Low indicator tells you if your full number is too big or small.", systemImage: "arrow.up.and.down.circle.fill", color: AppTheme.signals)
            ]
        case .archive:
            return [
                HowToPlayStep(title: "Guess the Date", instruction: "Identify when this event took place in history.", systemImage: "calendar", color: AppTheme.archive),
                HowToPlayStep(title: "Refine by Part", instruction: "Arrows tell you if the day, month, or year should be higher or lower.", systemImage: "arrow.up.and.down.square", color: AppTheme.archive),
                HowToPlayStep(title: "Time is Relative", instruction: "Use your history knowledge to zero in on the exact moment.", systemImage: "hourglass", color: AppTheme.archive)
            ]
        case .cargo:
            return [
                HowToPlayStep(title: "Pick Cargo", instruction: "Tap a piece from the dock to select it for placement.", systemImage: "hand.tap.fill", color: AppTheme.cargo),
                HowToPlayStep(title: "Fill the Hold", instruction: "Place and rotate pieces to cover every cell of the grid.", systemImage: "square.grid.3x3.fill", color: AppTheme.cargo),
                HowToPlayStep(title: "Perfect Fit", instruction: "Cargo must not overlap or go off the edges. Fit them all to win.", systemImage: "checkmark.seal.fill", color: AppTheme.cargo)
            ]
        case .shift:
            return [
                HowToPlayStep(title: "Slide the Grid", instruction: "Drag rows left/right or columns up/down to move letters.", systemImage: "arrow.up.and.down.and.arrow.left.and.right", color: AppTheme.shift),
                HowToPlayStep(title: "Spell the Targets", instruction: "Find and align the required words anywhere in the grid.", systemImage: "character.book.closed.fill", color: AppTheme.shift),
                HowToPlayStep(title: "Optimal Moves", instruction: "Try to find all words in the fewest moves possible for a higher rank.", systemImage: "target", color: AppTheme.shift)
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("How to Play: \(gameType.displayName)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            // Paging Content
            TabView(selection: $selection) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    VStack(spacing: 32) {
                        Image(systemName: step.systemImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundStyle(step.color)
                            .padding(40)
                            .background(
                                Circle()
                                    .fill(step.color.opacity(0.12))
                            )
                        
                        VStack(spacing: 12) {
                            Text(step.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                            
                            Text(step.instruction)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .lineLimit(3)
                        }
                        
                        Spacer()
                    }
                    .tag(index)
                    .padding(.top, 40)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            // Footer Control
            Button {
                if selection < steps.count - 1 {
                    withAnimation { selection += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(selection == steps.count - 1 ? "Got it!" : "Next")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(steps[selection].color)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(500)])
        .presentationCornerRadius(32)
    }
}

#Preview {
    HowToPlaySheet(gameType: .signals)
}
