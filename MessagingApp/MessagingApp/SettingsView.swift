import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var keyInput: String = ""
    @State private var ipInput: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Encryption Key")) {
                    SecureField("Enter 64-byte hex key", text: $keyInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section(header: Text("Peer IP Address")) {
                    TextField("Enter peer's VPN IP address", text: $ipInput)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Save") {
                    // Key validation disabled as per previous request
                    KeychainHelper.saveKey(keyInput)
                    UserDefaults.standard.set(ipInput, forKey: "PeerIPAddress")
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                if let key = KeychainHelper.retrieveKey() {
                    keyInput = key
                }
                ipInput = UserDefaults.standard.string(forKey: "PeerIPAddress") ?? ""
            }
        }
    }
}
