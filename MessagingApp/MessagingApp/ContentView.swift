import SwiftUI
import CryptoKit

struct ContentView: View {
    @State private var messageText: String = ""
    @State private var messages: [Message] = []
    @State private var showSettings: Bool = false
    @State private var encryptionKey: String = ""
    @State private var peerIPAddress: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    ForEach(messages) { message in
                        MessageRow(message: message)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                HStack {
                    Button(action: {
                        // Implement image picker if needed
                    }) {
                        Image(systemName: "plus")
                            .padding()
                    }
                    TextField("Enter message", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .padding()
                    }
                }
                .padding()
            }
            .navigationBarTitle("SecureChat")
            .navigationBarItems(trailing:
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                }
            )
            .sheet(isPresented: $showSettings, onDismiss: {
                if let key = KeychainHelper.retrieveKey() {
                    encryptionKey = key
                }
                peerIPAddress = UserDefaults.standard.string(forKey: "PeerIPAddress") ?? ""
                startNetworkServices()
            }) {
                SettingsView()
            }
            .onAppear {
                if let key = KeychainHelper.retrieveKey() {
                    encryptionKey = key
                } else {
                    showSettings = true
                }
                peerIPAddress = UserDefaults.standard.string(forKey: "PeerIPAddress") ?? ""
                startNetworkServices()
                NetworkService.shared.onReceiveData = { data in
                    receiveMessage(data)
                }
            }
        }
    }
    
    func startNetworkServices() {
        NetworkService.shared.startListening()
        if !peerIPAddress.isEmpty {
            NetworkService.shared.connectToHost(host: peerIPAddress)
        }
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        guard let key = symmetricKey(from: encryptionKey) else { return }
        if let encryptedData = encryptMessage(messageText, key: key) {
            NetworkService.shared.send(data: encryptedData)
            let newMessage = Message(content: messageText, isSentByCurrentUser: true)
            messages.append(newMessage)
            messageText = ""
        }
    }
    
    func receiveMessage(_ data: Data) {
        guard let key = symmetricKey(from: encryptionKey) else { return }
        if let decryptedMessage = decryptMessage(data, key: key) {
            let newMessage = Message(content: decryptedMessage, isSentByCurrentUser: false)
            messages.append(newMessage)
        }
    }
    
    // Existing symmetricKey, encryptMessage, decryptMessage functions remain the same

    func symmetricKey(from hexString: String) -> SymmetricKey? {
        var data = Data()
        var tempHex = hexString
        while tempHex.count > 0 {
            let c = String(tempHex.prefix(2))
            tempHex = String(tempHex.dropFirst(2))
            if let byte = UInt8(c, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        return SymmetricKey(data: data)
    }

    func encryptMessage(_ message: String, key: SymmetricKey) -> Data? {
        let messageData = Data(message.utf8)
        do {
            let sealedBox = try AES.GCM.seal(messageData, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }

    func decryptMessage(_ data: Data, key: SymmetricKey) -> String? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}

// Message and MessageRow structs remain the same
struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isSentByCurrentUser: Bool
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isSentByCurrentUser {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                Text(message.content)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}
