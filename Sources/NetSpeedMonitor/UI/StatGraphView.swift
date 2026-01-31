import SwiftUI
import Charts

struct StatGraphView: View {
    let data: [Double]
    let color: Color
    let minRange: Double
    let maxRange: Double
    
    // Computed property to create points for the chart
    var chartPoints: [(index: Int, value: Double)] {
        data.enumerated().map { ($0, $1) }
    }
    
    var body: some View {
        Chart {
            ForEach(chartPoints, id: \.index) { point in
                LineMark(
                    x: .value("Time", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic)
        .frame(height: 30)
        .clipped()
    }
}
