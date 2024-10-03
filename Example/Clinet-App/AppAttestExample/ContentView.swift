import SwiftUI

struct ContentView: View {
  @State var error: Error?
  @State var response: String?
  
  func sendData() async throws {
    struct Payload: Codable {
      var name = "Hello World!"
      var age = 42
    }
    
    let payload = Payload()
    
    let payloadData = try JSONEncoder().encode(payload)
    let (data, _) = try await Client.execute(body: payloadData)
    
    self.response = String(decoding: data, as: UTF8.self)
  }
  
  var body: some View {
    List {
      Button("Send Data") {
        Task {
          do {
            try await sendData()
          } catch {
            self.error = error
          }
        }
      }
      
      if let error {
        Text(error.localizedDescription)
      }
      if let response {
        Text(response)
      }
    }
  }
}

#Preview {
  ContentView()
}
