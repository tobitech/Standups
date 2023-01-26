import Combine
import Dependencies
import IdentifiedCollections
import SwiftUI
import SwiftUINavigation

struct DataManager: Sendable {
	var load: @Sendable (URL) throws -> Data
	var save: @Sendable (Data, URL) throws -> Void
}

extension DataManager: DependencyKey {
	static let liveValue = DataManager(
		load: { url in
			try Data(contentsOf: url)
		},
		save: { data, url in
			try data.write(to: url)
		}
	)
}

extension DataManager {
	static var mock: DataManager {
		let data = LockIsolated(Data()) // LockIsolated helps turn non-sendable data to sendable data.
		return DataManager(
			load: { _ in data.value },
			// save: { newData, _ in data = newData }
			save: { newData, _ in data.setValue(newData) }
		)
	}
}

extension DependencyValues {
	var dataManager: DataManager {
		get { self[DataManager.self] }
		set { self[DataManager.self] = newValue }
	}
}

@MainActor
final class StandupsListModel: ObservableObject {
	@Published var destination: Destination? {
		didSet { self.bind() }
	}
	@Published var standups: IdentifiedArrayOf<Standup>
	
	private var destinationCancellable: AnyCancellable?
	// we are using a set because this is going to live on for the entirety of the life time of the application.
	private var cancellables: Set<AnyCancellable> = []
	
	enum Destination {
		case add(EditStandupModel)
		case detail(StandupDetailModel)
	}
	
	@Dependency(\.dataManager) var dataManager
	@Dependency(\.mainQueue) var mainQueue
	
	init(
		destination: Destination? = nil
	) {
		self.destination = destination
		self.standups = []
		
		do {
			self.standups = try JSONDecoder().decode(
				IdentifiedArray.self,
				from: self.dataManager.load(.standups)
			)
		} catch { }
		
		self.$standups
			.dropFirst()
		// we're debouncing so that if it emits multiple times, we can wait for a while before saving the last emitted value.
			.debounce(for: .seconds(1), scheduler: self.mainQueue)
			.sink { [weak self] standups in
				guard let self else { return }
				do {
					try self.dataManager.save(JSONEncoder().encode(standups), .standups)
				} catch {}
			}
			.store(in: &self.cancellables)
		
		self.bind()
	}
	
	private func bind() {
		switch self.destination {
		case let .detail(standupDetailModel):
			standupDetailModel.onConfirmDeletion = { [weak self, id = standupDetailModel.standup.id] in
				guard let self else { return }
				
				withAnimation {
					// self.standups.removeAll { $0.id == id }
					self.standups.remove(id: id)
					self.destination = nil
				}
			}
			
			self.destinationCancellable =  standupDetailModel.$standup
				.sink { [weak self] standup in
					guard let self else { return }
					// guard let index = self.standups.firstIndex(where: { $0.id == standup.id }) else { return }
					
					self.standups[id: standup.id] = standup
				}
			
		case .add, .none:
			break
		}
	}
	
	func addStandupButtonTapped() {
		self.destination = .add(.init(standup: .init(id: Standup.ID(UUID()))))
	}
	
	func dismissAddStandupButtonTapped() {
		self.destination = nil
	}
	
	func confirmAddStandupButtonTapped() {
		defer { self.destination = nil } // we upfront say that no matter what happens we want the sheet to go away.
		
		guard case let .add(editStandupModel) = self.destination else { return }
		var standup = editStandupModel.standup
		
		standup.attendees.removeAll { attendee in
			attendee.name.allSatisfy(\.isWhitespace)
		}
		
		if standup.attendees.isEmpty {
			standup.attendees.append(Attendee(id: Attendee.ID(UUID()), name: ""))
		}
		
		self.standups.append(standup)
	}
	
	func standupTapped(standup: Standup) {
		self.destination = .detail(StandupDetailModel(standup: standup))
	}
}

extension URL {
	static let standups = Self.documentsDirectory.appending(component: "standups.json")
}

struct StandupsList: View {
	
	@ObservedObject var model: StandupsListModel
	
	var body: some View {
		NavigationStack {
			List {
				ForEach(self.model.standups) { standup in
					Button(action: {
						self.model.standupTapped(standup: standup)
					}, label: {
						CardView(standup: standup)
					})
					.listRowBackground(standup.theme.mainColor)
				}
			}
			.toolbar {
				Button(action: {
					self.model.addStandupButtonTapped()
				}, label: {
					Image(systemName: "plus")
				})
			}
			.navigationTitle("Daily Standups")
			.sheet(
				unwrapping: self.$model.destination,
				case: /StandupsListModel.Destination.add
			) { $model in
				NavigationStack {
					EditStandupView(model: model)
						.navigationTitle("New standup")
						.toolbar {
							ToolbarItem(placement: .cancellationAction) {
								Button("Dismiss") {
									self.model.dismissAddStandupButtonTapped()
								}
							}
							ToolbarItem(placement: .confirmationAction) {
								Button("Add") {
									self.model.confirmAddStandupButtonTapped()
								}
							}
						}
				}
			}
			.navigationDestination(
				unwrapping: self.$model.destination,
				case: /StandupsListModel.Destination.detail,
				destination: { $model in
					StandupDetailView(model: model)
				})
		}
	}
}

struct CardView: View {
	let standup: Standup

	var body: some View {
		VStack(alignment: .leading) {
			Text(self.standup.title)
				.font(.headline)
			Spacer()
			HStack {
				Label(
					"\(self.standup.attendees.count)",
					systemImage: "person.3"
				)
				Spacer()
				Label(
					self.standup.duration.formatted(.units()),
					systemImage: "clock"
				)
				.labelStyle(.trailingIcon)
			}
			.font(.caption)
		}
		.padding()
		.foregroundColor(self.standup.theme.accentColor)
	}
}

struct TrailingIconLabelStyle: LabelStyle {
	func makeBody(
		configuration: Configuration
	) -> some View {
		HStack {
			configuration.title
			configuration.icon
		}
	}
}

extension LabelStyle where Self == TrailingIconLabelStyle {
	static var trailingIcon: Self { Self() }
}

struct StandupsList_Previews: PreviewProvider {
	static var previews: some View {
		StandupsList(model: StandupsListModel())
	}
}
