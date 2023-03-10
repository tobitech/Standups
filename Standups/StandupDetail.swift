import Clocks
import Dependencies
import SwiftUI
import SwiftUINavigation
import XCTestDynamicOverlay

@MainActor
class StandupDetailModel: ObservableObject {
	@Published var destination: Destination? {
		didSet {
			self.bind()
		}
	}
	@Published var standup: Standup
	
	var onConfirmDeletion: () -> Void = unimplemented("StandupDetailModel.onConfirmDeletion")
	
	enum Destination {
		case alert(AlertState<AlertAction>)
		case edit(EditStandupModel)
		case meeting(Meeting)
		case record(RecordMeetingModel)
	}
	
	enum AlertAction {
		 case confirmDeletion
	}
	
	// private let clock: any Clock<Duration>
	@Dependency(\.continuousClock) var clock
	
	init(
		// clock: any Clock<Duration> = ContinuousClock(),
		destination: Destination? = nil,
		standup: Standup
	) {
		// self.clock = clock
		self.destination = destination
		self.standup = standup
		self.bind()
	}
	
	private func bind() {
		switch self.destination {
		case let .record(recordMeetingModel):
			recordMeetingModel.onMeetingFinished = { [weak self] transcript in
				guard let self else { return }
				
				Task {
					try? await self.clock.sleep(for: .milliseconds(400))
					// withAnimation(.default.delay(<#T##delay: Double##Double#>)) { // doesn't play well with List and Form views.
					withAnimation {
						_ = self.standup.meetings.insert(
							Meeting(
								id: Meeting.ID(UUID()),
								date: Date(),
								transcript: transcript
							),
							at: 0
						)
					}
				}
				self.destination = nil
			}
			
		case .edit, .meeting, .alert, .none:
			break
		}
	}
	
	func deleteMeetings(atOffsets indices: IndexSet) {
		self.standup.meetings.remove(atOffsets: indices)
	}
	
	func meetingTapped(_ meeting: Meeting) {
		self.destination = .meeting(meeting)
	}
	
	func deleteButtonTapped() {
		self.destination = .alert(.delete)
	}
	
	func alertButtonTapped(_ action: AlertAction) {
		switch action {
		case .confirmDeletion:
			self.onConfirmDeletion()
		}
	}
	
	func editButtonTapped() {
		self.destination = .edit(EditStandupModel(standup: self.standup))
//		self.destination = .edit(
//			EditStandupModel(
//				standup: Standup(
//					id: Standup.ID(UUID()),
//					attendees: self.standup.attendees,
//					duration: self.standup.duration,
//					meetings: self.standup.meetings,
//					theme: self.standup.theme,
//					title: self.standup.title
//				)
//			)
//		)
	}
	
	
	func cancelEditButtonTapped() {
		self.destination = nil
	}
	
	func doneEditingButtonTapped() {
		defer { self.destination = nil }
		
		guard case let .edit(model) = self.destination else { return }
		self.standup = model.standup
	}
	
	func startMeetingButtonTapped() {
		self.destination = .record(RecordMeetingModel(standup: self.standup))
	}
}

extension AlertState where Action == StandupDetailModel.AlertAction {
	static let delete = Self(
		title: TextState("Delete?"),
		message: TextState("Are you sure you want to delete this meeting?"),
		buttons: [
			.destructive(TextState("Yes"), action: .send(.confirmDeletion)),
			.cancel(TextState("Nevermind"))
		]
	)
}

struct StandupDetailView: View {
	
	@ObservedObject var model: StandupDetailModel
	
	var body: some View {
		List {
			Section {
				Button {
					self.model.startMeetingButtonTapped()
				} label: {
					Label("Start Meeting", systemImage: "timer")
						.font(.headline)
						.foregroundColor(.accentColor)
				}
				HStack {
					Label("Length", systemImage: "clock")
					Spacer()
					Text(self.model.standup.duration.formatted(
						.units())
					)
				}
				
				HStack {
					Label("Theme", systemImage: "paintpalette")
					Spacer()
					Text(self.model.standup.theme.name)
						.padding(4)
						.foregroundColor(
							self.model.standup.theme.accentColor
						)
						.background(self.model.standup.theme.mainColor)
						.cornerRadius(4)
				}
			} header: {
				Text("Standup Info")
			}
			
			if !self.model.standup.meetings.isEmpty {
				Section {
					ForEach(self.model.standup.meetings) { meeting in
						Button {
							self.model.meetingTapped(meeting)
						} label: {
							HStack {
								Image(systemName: "calendar")
								Text(meeting.date, style: .date)
								Text(meeting.date, style: .time)
							}
						}
					}
					.onDelete { indices in
						self.model.deleteMeetings(atOffsets: indices)
					}
				} header: {
					Text("Past meetings")
				}
			}
			
			Section {
				ForEach(self.model.standup.attendees) { attendee in
					Label(attendee.name, systemImage: "person")
				}
			} header: {
				Text("Attendees")
			}
			
			Section {
				Button("Delete") {
					self.model.deleteButtonTapped()
				}
				.foregroundColor(.red)
				.frame(maxWidth: .infinity)
			}
		}
		.navigationTitle(self.model.standup.title)
		.toolbar {
			Button("Edit") {
				self.model.editButtonTapped()
			}
		}
		.navigationDestination(
			unwrapping: self.$model.destination,
			case: /StandupDetailModel.Destination.meeting,
			destination: { $meeting in
				MeetingView(meeting: meeting, standup: self.model.standup)
			}
		)
		.navigationDestination(
			unwrapping: self.$model.destination,
			case: /StandupDetailModel.Destination.record,
			destination: { $model in
				RecordMeetingView(model: model)
			}
		)
		.sheet(
			unwrapping: self.$model.destination,
			case: /StandupDetailModel.Destination.edit
		) { $model in
			NavigationStack {
				EditStandupView(model: model)
					.navigationTitle("Edit standup")
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Cancel") {
								self.model.cancelEditButtonTapped()
							}
						}
						ToolbarItem(placement: .confirmationAction) {
							Button("Done") {
								self.model.doneEditingButtonTapped()
							}
						}
					}
			}
		}
		.alert(
			unwrapping: self.$model.destination,
			case: /StandupDetailModel.Destination.alert) { action in
				self.model.alertButtonTapped(action)
			}
	}
}

struct StandupDetail_Previews: PreviewProvider {
	static var previews: some View {
		NavigationStack {
			StandupDetailView(model: StandupDetailModel(standup: .mock))
		}
	}
}
