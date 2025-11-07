import SwiftUI

public struct AudioVisualizationView: View {
    public let audioLevel: Float
    public var color: Color = .blue

    public init(audioLevel: Float, color: Color = .blue) {
        self.audioLevel = audioLevel
        self.color = color
    }

    private let totalBars = 40
    private let minActiveBars = 10  // Minimum bars that activate in center
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 2
    private let maxBarHeight: CGFloat = 32  // Increased for taller center bars
    private let dotSize: CGFloat = 3  // Perfect circle when inactive

    private var activeBarCount: Int {
        let audioFactor = CGFloat(audioLevel)
        let range = CGFloat(totalBars - minActiveBars)
        let count = minActiveBars + Int(range * audioFactor)
        return max(minActiveBars, min(totalBars, count))
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Calculate position from center (0.0 = center, 1.0 = edge)
        let center = Double(totalBars - 1) / 2.0
        let distanceFromCenter = abs(Double(index) - center) / center

        // Check if this bar should be active
        let barsFromEdge = (totalBars - activeBarCount) / 2
        let distanceFromStart = index
        let distanceFromEnd = totalBars - 1 - index
        let minDistance = min(distanceFromStart, distanceFromEnd)

        let isActive = minDistance >= barsFromEdge

        // If not active, return dot size (will be rendered as circle)
        if !isActive {
            return dotSize
        }

        // Quadratic audio factor for more dramatic response
        let audioFactor = CGFloat(audioLevel) * CGFloat(audioLevel)

        // Quadratic falloff from center for dramatic curve
        let waveformFactor = 1.0 - (distanceFromCenter * distanceFromCenter)

        // Calculate height
        let heightRange = maxBarHeight - dotSize
        let baseHeight = dotSize + (heightRange * audioFactor * waveformFactor)

        return max(dotSize, min(maxBarHeight, baseHeight))
    }

    public var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<totalBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .animation(.easeOut(duration: 0.15), value: activeBarCount)
        .animation(.easeOut(duration: 0.08), value: audioLevel)
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioVisualizationView(audioLevel: 0.3)
            .frame(height: 40)
            .padding()

        AudioVisualizationView(audioLevel: 0.7)
            .frame(height: 40)
            .padding()

        AudioVisualizationView(audioLevel: 1.0)
            .frame(height: 40)
            .padding()
    }
}
