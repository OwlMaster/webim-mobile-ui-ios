//
//  ChatViewController+Listener.swift
//  WebimClientLibrary_Example
//
//  Created by Anna Frolova on 21.01.2022.
//  Copyright © 2022 Webim. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import WebimMobileSDK

extension ChatViewController: MessageListener {
    
    // MARK: - Methods
    
    func added(message newMessage: Message,
               after previousMessage: Message?) {
        DispatchQueue.main.async {
            var inserted = false
            
            if let previousMessage = previousMessage {
                for (index, message) in self.chatMessages.enumerated() {
                    if previousMessage.isEqual(to: message) {
                        self.chatMessages.insert(newMessage, at: index)
                        inserted = true
                        break
                    }
                }
            }

            if !inserted {
                self.chatMessages.append(newMessage)
            }

            self.reloadTableWithNewData()

            self.scrollQueueManager.perform(kind: .scrollTableView(animated: true)) {
                let scrollRequired = (!newMessage.isOperatorType() && !newMessage.isSystemType()) || self.isLastCellVisible()

                guard !scrollRequired else {
                    self.scrollToBottomInMainQueue(animated: true)
                    return
                }
                let chatConfig = self.chatConfig as? WMChatViewControllerConfig
                guard chatConfig?.showScrollButtonCounter != false else { return }
                self.messageCounter.set(lastMessageIndex: self.chatMessages.count - 1)
            }
        }
    }
    
    func removed(message: Message) {
        DispatchQueue.main.async {
            var toUpdate = false
            if message.getCurrentChatID() == self.selectedMessage?.getCurrentChatID() {
                self.toolbarView.removeQuoteEditBar()
            }
            
            for (messageIndex, iteratedMessage) in self.chatMessages.enumerated() {
                if iteratedMessage.getID() == message.getID() {
                    self.chatMessages.remove(at: messageIndex)
                    let indexPath = IndexPath(row: messageIndex, section: 0)
                    toUpdate = true
                    
                    break
                }
            }
            
            if toUpdate {
                self.reloadTableWithNewData()
                self.messageCounter.set(lastMessageIndex: self.chatMessages.count - 1)
            }
        }
    }
    
    func removedAllMessages() {
        DispatchQueue.main.async {
            self.chatMessages.removeAll()
            self.reloadTableWithNewData()
        }
    }
    
    func changed(message oldVersion: Message,
                 to newVersion: Message) {
        let isScrollRequired = oldVersion.getText() != newVersion.getText() && !newVersion.isFile()
        scrollQueueManager.perform(kind: .scrollTableView(animated: true)) { [weak self] in
            guard let self = self else { return }
            guard let index = self.chatMessages
                .firstIndex(where: {$0.getID() == oldVersion.getID()}) else { return }
            
            self.chatMessages[index] = newVersion
            
            let canPerformBatchUpdates = self.chatTableView.numberOfRows(inSection: 0) == self.messages().count
            
            if canPerformBatchUpdates {
                self.chatTableView.performBatchUpdates {
                    self.chatTableView.reloadRows(
                        at: [IndexPath(row: index, section: 0)],
                        with: .none
                    )
                } completion: { _ in
                    guard isScrollRequired else { return }
                    self.chatTableView.scrollToRowSafe(
                        at: IndexPath(row: index, section: 0),
                        at: .bottom,
                        animated: true
                    )
                }
            } else {
                self.chatTableView.reloadData()
                guard isScrollRequired else { return }
                self.chatTableView.scrollToRowSafe(
                    at: IndexPath(row: index, section: 0),
                    at: .bottom,
                    animated: true
                )
            }
        }
    }
}

// MARK: - WEBIM: HelloMessageListener
extension ChatViewController: HelloMessageListener {
    func helloMessage(message: String) {
        print("Received Hello message: \"\(message)\"")
    }
}

extension ChatViewController: OperatorTypingListener {
    func onOperatorTypingStateChanged(isTyping: Bool) {
        guard WebimServiceController.currentSession.getCurrentOperator() != nil else { return }
        updateOperatorTypingStatus(typing: isTyping)
    }
}

// MARK: - WEBIM: CurrentOperatorChangeListener
extension ChatViewController: CurrentOperatorChangeListener {
    func changed(operator previousOperator: Operator?, to newOperator: Operator?) {
        updateOperatorInfo(operator: newOperator, state: WebimServiceController.currentSession.sessionState())
    }
}

// MARK: - WEBIM: ChatStateLisneter
extension ChatViewController: ChatStateListener {
    func changed(state previousState: ChatState, to newState: ChatState) {
        if (newState == .closedByVisitor || newState == .closedByOperator ) && (WebimServiceController.currentSession.sessionState() == .chatting || WebimServiceController.currentSession.sessionState() == .queue) {
            
            if let currentId = currentOperatorId(), alreadyRatedOperators[currentId] != true && webimServerSideSettingsManager.isRateOperatorEnabled() {
                showRateOperatorDialog(operatorId: currentOperatorId())
            }
        }
        
        updateOperatorInfo(operator: WebimServiceController.currentSession.getCurrentOperator(), state: newState)
    }
}
