import Foundation
import Network

class NetworkService: NSObject {
    static let shared = NetworkService()
    
    let port: NWEndpoint.Port = 12345 // Known port for listening and connecting
    var listener: NWListener?
    var connection: NWConnection?
    var connectionsByID: [Int: NWConnection] = [:]
    
    var onReceiveData: ((Data) -> Void)?
    
    func startListening() {
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("Listener ready on port \(self.port)")
            case .failed(let error):
                print("Listener failed with error: \(error)")
                self.listener?.cancel()
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] newConnection in
            self?.setupConnection(newConnection)
        }
        
        listener?.start(queue: .main)
    }
    
    func connectToHost(host: String) {
        let hostEndpoint = NWEndpoint.Host(host)
        
        connection = NWConnection(host: hostEndpoint, port: port, using: .tcp)
        connection?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("Connected to host \(host)")
                self.receive(on: self.connection!)
            case .failed(let error):
                print("Connection failed with error: \(error)")
                self.connection?.cancel()
            default:
                break
            }
        }
        connection?.start(queue: .main)
    }
    
    func setupConnection(_ connection: NWConnection) {
        let connectionID = ObjectIdentifier(connection).hashValue
        connectionsByID[connectionID] = connection
        
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("Connection \(connectionID) ready")
                self?.receive(on: connection)
            case .failed(let error):
                print("Connection \(connectionID) failed with error: \(error)")
                connection.cancel()
                self?.connectionsByID.removeValue(forKey: connectionID)
            case .cancelled:
                print("Connection \(connectionID) cancelled")
                self?.connectionsByID.removeValue(forKey: connectionID)
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    func send(data: Data) {
        // Send data to all connected peers
        var sendToConnections = Array(connectionsByID.values)
        if let conn = connection {
            sendToConnections.append(conn)
        }
        for conn in sendToConnections {
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("Send error: \(error)")
                } else {
                    print("Data sent")
                }
            })
        }
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.onReceiveData?(data)
            }
            if isComplete || error != nil {
                connection.cancel()
                self?.connectionsByID.removeValue(forKey: ObjectIdentifier(connection).hashValue)
            } else {
                self?.receive(on: connection)
            }
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        for conn in connectionsByID.values {
            conn.cancel()
        }
        connectionsByID.removeAll()
    }
}
