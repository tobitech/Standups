import SwiftUI
import SwiftUINavigation

class EditStandupModel: ObservableObject {
	
	@Published var standup: Standup
	
	init(standup: Standup) {
		self.standup = standup
		
		if self.standup.attendees.isEmpty {
			self.standup.attendees.append(
				Attendee(id: Attendee.ID(UUID()), name: "")
			)
		}
		// self.focused = .title
	}
	
	
	func deleteAttendees(atOffsets indices: IndexSet) {
		self.standup.attendees.remove(
			atOffsets: indices
		)
		if self.standup.attendees.isEmpty {
			self.standup.attendees.append(
				Attendee(id: Attendee.ID(UUID()), name: "")
			)
		}
		// self.focused = .attendee(self.standup.attendees[indices.first!].id)
	}
	
	func addAttendeeButtonTapped() {
		let attendee = Attendee(id: Attendee.ID(UUID()), name: "")
		self.standup.attendees.append(
			attendee
		)
		// self.focused = .attendee(attendee.id)
	}
}

struct EditStandupView: View {
	
	enum Field: Hashable {
		case attendee(Attendee.ID)
		case title
	}
	
	@FocusState var focused: Field?
	@ObservedObject var model: EditStandupModel
	
	var body: some View {
		Form {
			Section {
				TextField("Title", text: self.$model.standup.title)
					.focused(self.$focused, equals: .title)
				HStack {
					Slider(
						value: self.$model.standup.duration.seconds,
						in: 5...30, step: 1
					) {
						Text("Length")
					}
					Spacer()
					Text(self.model.standup.duration.formatted(.units()))
				}
				ThemePicker(selection: self.$model.standup.theme)
			} header: {
				Text("Standup Info")
			}
			Section {
				ForEach(self.$model.standup.attendees) { $attendee in
					TextField("Name", text: $attendee.name)
						.focused(self.$focused, equals: .attendee(attendee.id))
				}
				.onDelete { indices in
					self.model.deleteAttendees(atOffsets: indices)
					self.focused = .attendee(self.model.standup.attendees[indices.first!].id)
				}
				
				Button("New attendee") {
					self.model.addAttendeeButtonTapped()
					self.focused = .attendee(self.model.standup.attendees.last!.id)
				}
			} header: {
				Text("Attendees")
			}
		}
		.onAppear {
			self.focused = .title
		}
	}
}

struct ThemePicker: View {
	@Binding var selection: Theme
	
	var body: some View {
		Picker("Theme", selection: $selection) {
			ForEach(Theme.allCases) { theme in
				ZStack {
					RoundedRectangle(cornerRadius: 4)
						.fill(theme.mainColor)
					Label(theme.name, systemImage: "paintpalette")
						.padding(4)
				}
				.foregroundColor(theme.accentColor)
				.fixedSize(horizontal: false, vertical: true)
				.tag(theme)
			}
		}
	}
}

extension Duration {
	fileprivate var seconds: Double {
		get { Double(self.components.seconds / 60) }
		set { self = .seconds(newValue * 60) }
	}
}

struct EditStandup_Previews: PreviewProvider {
	static var previews: some View {
		WithState(initialValue: Standup.mock) { $standup in
			EditStandupView(model: EditStandupModel(standup: standup))
		}
	}
}
