import Foundation 

@MainActor
@Observable
final class PersonaStore {
    private let personaRepository: UserPersonaRepository

    private(set) var personas: [UserPersonaModel] = []
    private(set) var activePersona: UserPersonaModel?
    
    init(
        personaRepository: UserPersonaRepository
    ) {
        self.personaRepository = personaRepository

        getPersonas()
    }

    func getPersonas() {
        do {
            personas = try personaRepository.getAll()

            // TODO: Support multiple active personas? How would this work? 
            // we should also add some stronger protextion here so that for now, only
            // one persona can be active at a time
            activePersona = personas.first(where: { $0.active })
        } catch {
            print("Error fetching personas: \(error)")
        }
    }

    func savePersona(_ persona: UserPersonaModel) {
        do {
            try personaRepository.save(persona)
            getPersonas()
        } catch {
            print("Error saving persona: \(error)")
        }
    }

    func deletePersona(_ persona: UserPersonaModel) {
        do {
            try personaRepository.delete(persona)
            getPersonas()
        } catch {
            print("Error deleting persona: \(error)")
        }
    }
}