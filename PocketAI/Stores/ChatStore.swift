//
//  ChatStore.swift
//  PocketAI
//
//  Created by devon jerothe on 4/13/26.
//

import Foundation

@MainActor
@Observable
final class ChatStore {
    private let chatRepository: ChatRepository
    private let messageRepository: MessageRepository
    
    // Used to block requests before an operation is complete when observing the DB
    private var observerQueue: [CheckedContinuation<Void, Never>] = []
    // Message status/text is transient UI state. The DB observer rebuilds models from
    // rows that do not include those fields, so we overlay the latest in-memory value
    // back onto observed chats until the message returns to a persisted `.done` state.
    private var transientMessages: [UUID: MessageModel] = [:]
    private var transientChatStatuses: [UUID: ChatStatus] = [:]
    
    private(set) var chats: [ChatModel] = []
    var lastChat: ChatModel? { chats.first }
    
    init(
        chatRepository: ChatRepository,
        messageRepository: MessageRepository
    ) {
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
    }
    
    func startObserving() async {
        do {
            for try await updatedChats in try chatRepository.observeAll() {
                self.mergeChats(updatedChats)
                
                let queued = observerQueue
                observerQueue.removeAll()
                queued.forEach { $0.resume() }
            }
        } catch {
            print("Error observing chat records: \(error)")
        }
    }
    
    /// If we are observing the chat records we need to ensure our observer refreshes our `chats` array
    /// before we continue. Otherwise we may reference old array data.
    ///
    /// This simply adds a check continuation to our array. Once the observer finalizes it resumes the continuation allowing
    /// the function to continue
    private func waitForObserver() async {
        await withCheckedContinuation { continuation in
            observerQueue.append(continuation)
        }
    }
    
    /// Chat status is in memory. We need to make sure when the observer queries the db
    /// that we keep status values accurate.
    private func mergeChats(_ updatedChats: [ChatModel]) {
        self.chats = updatedChats.map { chat in
            var mergedChat = chat
            if let status = transientChatStatuses[chat.id] {
                mergedChat.status = status
            }
            mergedChat.messages = chat.messages.map { message in
                transientMessages[message.id] ?? message
            }
            return mergedChat
        }
    }
    
    func addChat(_ chat: ChatModel) async throws {
        var chat = chat
        chat.isPrivate = chat.characterCards.contains(where: \.isPrivate)
        
        let initialMessage = MessageModel(
            chatId: chat.id.uuidString,
            actor: .bot,
            text: chat.characterCards.first?.firstMessage ?? ""
        )
        
        try chatRepository.save(chat)
        try messageRepository.save(initialMessage)
        await waitForObserver()
    }
    
    func deleteChat(_ chat: ChatModel) async throws {
        try chatRepository.delete(chat)
        await waitForObserver()
    }
    
    func chat(withID chatId: UUID) -> ChatModel? {
        chats.first(where: { $0.id == chatId })
    }

    func saveChat(_ chat: ChatModel) async throws {
        try chatRepository.save(chat)
        await waitForObserver()
    }

    func setChatStatus(for chatId: UUID, to status: ChatStatus) throws {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else {
            throw AppDBError.recordNotFound(chatId.uuidString)
        }
        
        chats[index].status = status

        if status == .idle {
            transientChatStatuses.removeValue(forKey: chatId)
        } else {
            transientChatStatuses[chatId] = status
        }
    }
    
    func updateChatNotes() {}
    
    func updatePrivacy(for chatId: UUID, isPrivate: Bool) {}
    
    // MARK: - Message Calls
    func addMessage(_ message: MessageModel, to chatId: UUID) async throws {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else {
            throw AppDBError.recordNotFound(chatId.uuidString)
        }
        
        // backup incase DB throws
        let messages = chats[chatIndex].messages
        let timeStamp = chats[chatIndex].updatedAt
        
        do {
            chats[chatIndex].messages.append(message)
            chats[chatIndex].updatedAt = Date()
            if message.status != .done {
                transientMessages[message.id] = message
            }
            try messageRepository.save(message)
            await waitForObserver()
        } catch {
            chats[chatIndex].messages = messages
            chats[chatIndex].updatedAt = timeStamp
            transientMessages.removeValue(forKey: message.id)
            throw error
        }
    }
    
    // save should be used when updating text. If changing loading status we may not want to persist in db.
    func updateMessage(_ message: MessageModel, in chatId: UUID, save: Bool = true) async throws {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else {
            throw AppDBError.recordNotFound("Chat: \(chatId.uuidString)")
        }
        
        guard let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == message.id }) else {
            throw AppDBError.recordNotFound("Message: \(message.id.uuidString)")
        }
        
        chats[chatIndex].messages[messageIndex] = message
        chats[chatIndex].updatedAt = Date()

        if save == false || message.status != .done {
            transientMessages[message.id] = message
        } else {
            transientMessages.removeValue(forKey: message.id)
        }
        
        if save {
            try messageRepository.save(message)
            await waitForObserver()
        }
        
    }
    
    func deleteMessage(_ message: MessageModel, from chatId: UUID) async throws {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else {
            throw AppDBError.recordNotFound("Chat: \(chatId.uuidString)")
        }
        
        transientMessages.removeValue(forKey: message.id)
        try messageRepository.delete(message)
        try chatRepository.save(chats[chatIndex])
        await waitForObserver()
    }
}
