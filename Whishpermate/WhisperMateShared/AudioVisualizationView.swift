import SwiftUI

public struct AudioVisualizationView: View {
    public let audioLevel: Float
    public let frequencyBands: [Float]?
    public var color: Color = .blue

    public init(audioLevel: Float, color: Color = .blue, frequencyBands: [Float]? = nil) {
        self.audioLevel = audioLevel
        self.color = color
        self.frequencyBands = frequencyBands
    }

    private let totalBars = 14
    private let minActiveBars = 4  // Minimum bars that activate in center
    private let barWidth: CGFloat = 4  // Twice as thick
    private let barSpacing: CGFloat = 2
    private let maxBarHeight: CGFloat = 20  // Fit within overlay height
    private let dotSize: CGFloat = 3  // Perfect circle when inactive

    private var activeBarCount: Int {
        let audioFactor = CGFloat(audioLevel)
        let range = CGFloat(totalBars - minActiveBars)
        let count = minActiveBars + Int(range * audioFactor)
        return max(minActiveBars, min(totalBars, count))
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Use frequency bands if available
        if let bands = frequencyBands, bands.count == totalBars {
            let magnitude = CGFloat(bands[index])
            let heightRange = maxBarHeight - dotSize
            let randomFactor = CGFloat.random(in: 0.8...1.2)  // Add organic variation
            let height = dotSize + (heightRange * magnitude * randomFactor)
            return max(dotSize, min(maxBarHeight, height))
        }

        // Fallback to volume-based visualization
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

        // Linear audio factor for better sensitivity
        let audioFactor = CGFloat(audioLevel)

        // Quadratic falloff from center for dramatic curve
        let waveformFactor = 1.0 - (distanceFromCenter * distanceFromCenter)

        // Add organic variation
        let randomFactor = CGFloat.random(in: 0.8...1.2)

        // Calculate height
        let heightRange = maxBarHeight - dotSize
        let baseHeight = dotSize + (heightRange * audioFactor * waveformFactor * randomFactor)

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
        .animation(.easeOut(duration: 0.12), value: frequencyBands ?? [audioLevel])
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
