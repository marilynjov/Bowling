import BowlingCore
import Charts
import SwiftUI

/// Session averages (Accent) with the rolling average dashed (InkMuted), over dates.
struct TrendCard: View {
    var trend: TrendContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(Array(trend.points.enumerated()), id: \.offset) { _, point in
                    if let average = point.sessionAverage.value {
                        LineMark(x: .value("Date", point.date), y: .value("Score", average),
                                 series: .value("Line", "Session"))
                            .foregroundStyle(Color.accent)
                        PointMark(x: .value("Date", point.date), y: .value("Score", average))
                            .foregroundStyle(Color.accent)
                    }
                    if let rolling = point.rollingAverage.value {
                        LineMark(x: .value("Date", point.date), y: .value("Score", rolling),
                                 series: .value("Line", "Rolling"))
                            .foregroundStyle(Color.inkMuted)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            Text(trend.sample)
                .font(.figure)
                .foregroundStyle(.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend.accessibilityLabel)
    }
}
