//
//  UpgradeModalView.swift
//  WhisperMate
//
//  Created by WhisperMate on 2025-01-24.
//

import SwiftUI
import WhisperMateShared

struct UpgradeModalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding()
            }

            // Pricing comparison
            PricingComparisonView()
                .padding(.bottom, 20)
        }
        .frame(width: 700, height: 650)
    }
}

#Preview {
    UpgradeModalView()
}
