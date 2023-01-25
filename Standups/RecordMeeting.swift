import SwiftUI

class RecordMeetingModel: ObservableObject {
	@Published var secondsElapsed = 0
	@Published var speakerIndex = 0
	
	var durationRemaining: Duration {
		self.standup.duration - .seconds(self.secondsElapsed)
	}
	
	let standup: Standup
	
	init(
		standup: Standup
	) {
		self.standup = standup
	}
	
	func nextButtonTapped() {
		
	}
	
	func endMeetingButtonTapped() {
		
	}
}

struct RecordMeetingView: View {
	@ObservedObject var model: RecordMeetingModel

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 16)
				.fill(self.model.standup.theme.mainColor)

			VStack {
				MeetingHeaderView(
					secondsElapsed: self.model.secondsElapsed,
					durationRemaining: self.model.durationRemaining,
					theme: self.model.standup.theme
				)
				MeetingTimerView(
					standup: self.model.standup,
					speakerIndex: self.model.speakerIndex
				)
				MeetingFooterView(
					standup: self.model.standup,
					nextButtonTapped: { self.model.nextButtonTapped() },
					speakerIndex: self.model.speakerIndex
				)
			}
		}
		.padding()
		.foregroundColor(self.model.standup.theme.accentColor)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .cancellationAction) {
				Button("End meeting") {
					self.model.endMeetingButtonTapped()
				}
			}
		}
		.navigationBarBackButtonHidden(true)
	}
}

struct MeetingHeaderView: View {
	let secondsElapsed: Int
	let durationRemaining: Duration
	let theme: Theme

	var body: some View {
		VStack {
			ProgressView(value: self.progress)
				.progressViewStyle(
					MeetingProgressViewStyle(theme: self.theme)
				)
			HStack {
				VStack(alignment: .leading) {
					Text("Seconds Elapsed")
						.font(.caption)
					Label(
						"\(self.secondsElapsed)",
						systemImage: "hourglass.bottomhalf.fill"
					)
				}
				Spacer()
				VStack(alignment: .trailing) {
					Text("Seconds Remaining")
						.font(.caption)
					Label(
						self.durationRemaining.formatted(.units()),
						systemImage: "hourglass.tophalf.fill"
					)
					.font(.body.monospacedDigit())
					.labelStyle(.trailingIcon)
				}
			}
		}
		.padding([.top, .horizontal])
	}

	private var totalDuration: Duration {
		.seconds(self.secondsElapsed)
			+ self.durationRemaining
	}

	private var progress: Double {
		guard totalDuration > .seconds(0) else { return 0 }
		return Double(self.secondsElapsed)
			/ Double(self.totalDuration.components.seconds)
	}
}

struct MeetingProgressViewStyle: ProgressViewStyle {
	var theme: Theme

	func makeBody(
		configuration: Configuration
	) -> some View {
		ZStack {
			RoundedRectangle(cornerRadius: 10.0)
				.fill(theme.accentColor)
				.frame(height: 20.0)

			ProgressView(configuration)
				.tint(theme.mainColor)
				.frame(height: 12.0)
				.padding(.horizontal)
		}
	}
}

struct MeetingTimerView: View {
	let standup: Standup
	let speakerIndex: Int

	var body: some View {
		Circle()
			.strokeBorder(lineWidth: 24)
			.overlay {
				VStack {
					Text(self.currentSpeakerName)
						.font(.title)
					Text("is speaking")
					Image(systemName: "mic.fill")
						.font(.largeTitle)
						.padding(.top)
				}
				.foregroundStyle(self.standup.theme.accentColor)
			}
			.overlay {
				ForEach(
					Array(self.standup.attendees.enumerated()),
					id: \.element.id
				) { index, attendee in
					if index < self.speakerIndex + 1 {
						SpeakerArc(
							totalSpeakers: self.standup.attendees.count,
							speakerIndex: index
						)
						.rotation(Angle(degrees: -90))
						.stroke(
							self.standup.theme.mainColor,
							lineWidth: 12
						)
					}
				}
			}
			.padding(.horizontal)
	}

	private var currentSpeakerName: String {
		guard
			self.speakerIndex < self.standup.attendees.count
		else { return "Someone" }
		return self.standup
			.attendees[self.speakerIndex].name
	}
}

struct SpeakerArc: Shape {
	let totalSpeakers: Int
	let speakerIndex: Int

	private var degreesPerSpeaker: Double {
		360.0 / Double(totalSpeakers)
	}
	private var startAngle: Angle {
		Angle(
			degrees: degreesPerSpeaker
				* Double(speakerIndex)
				+ 1.0
		)
	}
	private var endAngle: Angle {
		Angle(
			degrees: startAngle.degrees
				+ degreesPerSpeaker
				- 1.0
		)
	}

	func path(in rect: CGRect) -> Path {
		let diameter = min(
			rect.size.width, rect.size.height
		) - 24.0
		let radius = diameter / 2.0
		let center = CGPoint(x: rect.midX, y: rect.midY)
		return Path { path in
			path.addArc(
				center: center,
				radius: radius,
				startAngle: startAngle,
				endAngle: endAngle,
				clockwise: false
			)
		}
	}
}

struct MeetingFooterView: View {
	let standup: Standup
	var nextButtonTapped: () -> Void
	let speakerIndex: Int

	var body: some View {
		VStack {
			HStack {
				Text(self.speakerText)
				Spacer()
				Button(action: self.nextButtonTapped) {
					Image(systemName: "forward.fill")
				}
			}
		}
		.padding([.bottom, .horizontal])
	}

	private var speakerText: String {
		guard
			self.speakerIndex
				< self.standup.attendees.count - 1
		else {
			return "No more speakers."
		}
		return """
			Speaker \(self.speakerIndex + 1) \
			of \(self.standup.attendees.count)
			"""
	}
}

struct RecordMeeting_Previews: PreviewProvider {
	static var previews: some View {
		NavigationStack {
			RecordMeetingView(
				model: RecordMeetingModel(standup: .mock)
			)
		}
	}
}
