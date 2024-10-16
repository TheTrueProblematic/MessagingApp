import SwiftUI
import CryptoKit

struct ContentView: View {
    @State private var messageText: String = ""
    @State private var messages: [Message] = []
    @State private var showSettings: Bool = false
    @State private var encryptionKey: String = ""
    @State private var peerIPAddress: String = ""
    @State private var showImagePicker: Bool = false
    @State private var selectedImage: UIImage?
    @State private var imageDataToSend: Data?

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
                        showImagePicker = true
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
            .navigationBarTitle("SecureChat", displayMode: .inline)
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, onImagePicked: { image in
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        sendImage(imageData)
                    }
                })
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
                    receiveData(data)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Ensures consistent navigation view style on iPad
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
            let messageWrapper = MessageWrapper(type: .text, content: encryptedData)
            if let dataToSend = try? JSONEncoder().encode(messageWrapper) {
                NetworkService.shared.send(data: dataToSend)
                let newMessage = Message(content: messageText, isSentByCurrentUser: true, type: .text, imageData: nil)
                messages.append(newMessage)
                messageText = ""
            }
        }
    }
    
    func sendImage(_ imageData: Data) {
        guard let key = symmetricKey(from: encryptionKey) else { return }
        if let encryptedData = encryptData(imageData, key: key) {
            let messageWrapper = MessageWrapper(type: .image, content: encryptedData)
            if let dataToSend = try? JSONEncoder().encode(messageWrapper) {
                NetworkService.shared.send(data: dataToSend)
                let newMessage = Message(content: "", isSentByCurrentUser: true, type: .image, imageData: imageData)
                messages.append(newMessage)
            }
        }
    }
    
    func receiveData(_ data: Data) {
        guard let key = symmetricKey(from: encryptionKey) else { return }
        if let messageWrapper: MessageWrapper = try? JSONDecoder().decode(MessageWrapper.self, from: data) {
            switch messageWrapper.type {
            case .text:
                if let decryptedMessage = decryptMessage(messageWrapper.content, key: key) {
                    let newMessage = Message(content: decryptedMessage, isSentByCurrentUser: false, type: .text, imageData: nil)
                    messages.append(newMessage)
                }
            case .image:
                if let decryptedData = decryptData(messageWrapper.content, key: key) {
                    let newMessage = Message(content: "", isSentByCurrentUser: false, type: .image, imageData: decryptedData)
                    messages.append(newMessage)
                }
            }
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
        return encryptData(messageData, key: key)
    }
    
    func decryptMessage(_ data: Data, key: SymmetricKey) -> String? {
        if let decryptedData = decryptData(data, key: key) {
            return String(data: decryptedData, encoding: .utf8)
        }
        return nil
    }
    
    func encryptData(_ data: Data, key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }
    
    func decryptData(_ data: Data, key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}

// Add the missing MessageWrapper struct
struct MessageWrapper: Codable {
    let type: MessageType
    let content: Data
}

// Update Message and MessageRow structs
struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isSentByCurrentUser: Bool
    let type: MessageType
    let imageData: Data?
}

enum MessageType: String, Codable {
    case text
    case image
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isSentByCurrentUser {
                Spacer()
                contentView
                    .padding()
                    .background(Color(hex: "#FF00FF")) // Magenta color using hex value
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                contentView
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    var contentView: some View {
        if message.type == .text {
            Text(message.content)
        } else if message.type == .image, let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 200)
        } else {
            Text("Unsupported message type")
        }
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
            // Corrected the alpha value to 255 for opaque colors
        case 8: // ARGB (32-bit)
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 0, 255) // Default to opaque magenta
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
