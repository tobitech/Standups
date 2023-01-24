import SwiftUI
import SwiftUINavigation
import XCTestDynamicOverlay

class StandupDetailModel: ObservableObject {
	@Published var destination: Destination? 
	@Published var standup: Standup
	
	var onConfirmDeletion: () -> Void = unimplemented("StandupDetailModel.onConfirmDeletion")
	
	enum Destination {
		case alert(AlertState<AlertAction>)
		case meeting(Meeting)
	}
	
	enum AlertAction {
		 case confirmDeletion
	}
	
	init(
		destination: Destination? = nil,
		standup: Standup
	) {
		self.destination = destination
		self.standup = standup
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
			}
		}
		.navigationDestination(
			unwrapping: self.$model.destination,
			case: /StandupDetailModel.Destination.meeting,
			destination: { $meeting in
				MeetingView(meeting: meeting, standup: self.model.standup)
			}
		)
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
