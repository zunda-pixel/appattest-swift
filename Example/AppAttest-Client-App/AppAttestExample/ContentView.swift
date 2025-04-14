import SwiftUI

struct User: Codable, Hashable {
  var name: String
  var age: Int
}

struct ContentView: View {
  @State var error: Error?
  @State var response: String?
  @State var age: Int = 30
  @State var users: [User] = []

  func sendData() async throws {
    let payload = User(name: "Hello World!", age: age)

    let payloadData = try JSONEncoder().encode(payload)
    let (data, response) = try await Client.createUser(body: payloadData)
    if response.status == .ok {
      print("Suceeded to send data!")
      self.response = String(decoding: data, as: UTF8.self)
    } else {
      print(response.status)
      print(String(decoding: data, as: UTF8.self))
    }
  }

  var body: some View {
    List {
      TextField("Age", value: $age, format: .number)
        .keyboardType(.decimalPad)

      Section {
        Button("Create User") {
          Task {
            do {
              try await sendData()
            } catch {
              print("Error: \(error)")
              self.error = error
            }
          }
        }
      }

      if let error {
        Section {
          Text(error.localizedDescription)
        }
      }
      if let response {
        Section {
          Text("Created User \(response)")
        }
      }
      Section {
        Button("Reset") {
          error = nil
          response = nil
        }
      }

      Section {
        Button("Fetch Users") {
          Task {
            self.users = try await Client.getUsers()
          }
        }
      }

      Section("Users") {
        ForEach(users, id: \.self) { user in
          Text("\(user.name), \(user.age)")
        }
      }
    }
  }
}

#Preview {
  ContentView()
}
