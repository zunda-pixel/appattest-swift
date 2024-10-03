import SwiftUI

struct ContentView: View {
  @State var error: Error?
  
  
  func sendData() async throws {
    
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
    }
  }
}

#Preview {
  ContentView()
}
