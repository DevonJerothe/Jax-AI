// import SwiftUI

// struct ConnectionsSettingsViewNew: View {

//     @State private var serviceContainer: ServiceContainer = .shared

//     // MARK: - Connection Setting Bindings 
//     var hostBinding: Binding<String> {
//         Binding<String>(
//             get: { serviceContainer.connectionSettings.host ?? "" },
//             set: { serviceContainer.connectionSettings.host = $0.isEmpty ? nil : $0 }
//         )
//     }
    
//     var apiKeyBinding: Binding<String> {
//         Binding<String>(
//             get: { serviceContainer.connectionSettings.apiKey ?? "" },
//             set: { serviceContainer.connectionSettings.apiKey = $0.isEmpty ? nil : $0 }
//         )
//     }

//     var selectedModelBinding: Binding<String> {
//         Binding<String>(
//             get: { serviceContainer.connectionSettings.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free" },
//             set: { serviceContainer.connectionSettings.selectedModel = $0 }
//         )
//     }

//     var contextLengthBinding: Binding<Double> {
//         Binding<Double>(
//             get: { Double(serviceContainer.connectionSettings.contextLength ?? 4096) },
//             set: { serviceContainer.connectionSettings.contextLength = Int($0) }
//         )
//     }
    
//     var responseLengthBinding: Binding<Double> {
//         Binding<Double>(
//             get: { Double(serviceContainer.connectionSettings.responseLength ?? 300) },
//             set: { serviceContainer.connectionSettings.responseLength = Int($0) }
//         )
//     }
    
    
//     var body: some View {
//         VStack(spacing: 0) {
//             ScrollView {
//                 VStack(spacing: 24) {
//                     // Connection Section
//                     VStack(alignment: .leading, spacing: 16) {
//                         HStack {
//                             Text("Connection")
//                                 .font(.title2)
//                                 .fontWeight(.semibold)
//                                 .foregroundColor(.white)
//                             Spacer()
//                         }
                        
//                         VStack(spacing: 12) {
//                             // Connection Type Row
//                             Button(action: {
//                                 showingConnectionTypeSheet = true
//                             }) {
//                                 HStack {
//                                     VStack(alignment: .leading, spacing: 2) {
//                                         Text("Connection Type")
//                                             .foregroundColor(.white)
//                                             .font(.body)
//                                         Text(connectionType)
//                                             .foregroundColor(.gray)
//                                             .font(.subheadline)
//                                     }
//                                     Spacer()
//                                     Image(systemName: "chevron.right")
//                                         .foregroundColor(.gray)
//                                         .font(.system(size: 14, weight: .medium))
//                                 }
//                                 .padding()
//                                 .background(Color(.systemGray6).opacity(0.3))
//                                 .cornerRadius(12)
//                             }
//                             .buttonStyle(PlainButtonStyle())
//                             .confirmationDialog("Select Connection Type", isPresented: $showingConnectionTypeSheet) {
//                                 Button("KoboldAI") {
//                                     connectionType = "KoboldAI"
//                                 }
//                                 Button("OpenRouter") {
//                                     connectionType = "OpenRouter"
//                                 }
//                                 Button("Cancel", role: .cancel) { }
//                             }
                            
//                             // Response Length Slider
//                             VStack(alignment: .leading, spacing: 8) {
//                                 HStack {
//                                     Text("Response Length")
//                                         .foregroundColor(.white)
//                                         .font(.body)
//                                     Spacer()
//                                     Text("\(Int(responseLength))")
//                                         .foregroundColor(.gray)
//                                         .font(.subheadline)
//                                 }
                                
//                                 Slider(value: $responseLength, in: 100...2000, step: 100)
//                                     .accentColor(.blue)
//                             }
//                             .padding()
//                             .background(Color(.systemGray6).opacity(0.3))
//                             .cornerRadius(12)
//                         }
//                     }
                    
//                     // KoboldAI Section
//                     VStack(alignment: .leading, spacing: 16) {
//                         HStack {
//                             Text(connectionType)
//                                 .font(.title2)
//                                 .fontWeight(.semibold)
//                                 .foregroundColor(.white)
//                             Spacer()
//                         }
                        
//                         VStack(spacing: 12) {
//                             // Host Field
//                             VStack(alignment: .leading, spacing: 8) {
//                                 Text("Host")
//                                     .foregroundColor(.white)
//                                     .font(.body)
                                
//                                 TextField("e.g., 127.0.0.1", text: $hostText)
//                                     .textFieldStyle(PlainTextFieldStyle())
//                                     .padding()
//                                     .background(Color(.systemGray6).opacity(0.3))
//                                     .cornerRadius(12)
//                                     .foregroundColor(.white)
//                             }
                            
//                             // Port Field
//                             VStack(alignment: .leading, spacing: 8) {
//                                 Text("Port")
//                                     .foregroundColor(.white)
//                                     .font(.body)
                                
//                                 TextField("e.g., 5000", text: $portText)
//                                     .textFieldStyle(PlainTextFieldStyle())
//                                     .padding()
//                                     .background(Color(.systemGray6).opacity(0.3))
//                                     .cornerRadius(12)
//                                     .foregroundColor(.white)
//                                     .keyboardType(.numberPad)
//                             }
                            
//                             // Context Limit Slider
//                             VStack(alignment: .leading, spacing: 8) {
//                                 HStack {
//                                     Text("Context Limit")
//                                         .foregroundColor(.white)
//                                         .font(.body)
//                                     Spacer()
//                                     Text("\(Int(contextLimit))")
//                                         .foregroundColor(.gray)
//                                         .font(.subheadline)
//                                 }
                                
//                                 Slider(value: $contextLimit, in: 512...8192, step: 256)
//                                     .accentColor(.blue)
//                             }
//                             .padding()
//                             .background(Color(.systemGray6).opacity(0.3))
//                             .cornerRadius(12)
//                         }
//                     }
                    
//                     // Extra spacing for bottom content
//                     Spacer()
//                         .frame(height: 80)
//                 }
//                 .padding(.horizontal, 16)
//                 .padding(.top, 16)
//             }
            
//             // Bottom Status and Button Area
//             HStack {
//                 // Status
//                 HStack(spacing: 8) {
//                     Text("Status:")
//                         .foregroundColor(.white)
//                         .font(.body)
                    
//                     HStack(spacing: 4) {
//                         Circle()
//                             .fill(isConnected ? Color.green : Color.red)
//                             .frame(width: 8, height: 8)
//                         Text(isConnected ? "Connected" : "Disconnected")
//                             .foregroundColor(isConnected ? .green : .red)
//                             .font(.body)
//                             .fontWeight(.medium)
//                     }
//                 }
                
//                 Spacer()
                
//                 // Test Connection Button
//                 Button(action: {
//                     // Action placeholder
//                 }) {
//                     Text("Test Connection")
//                         .font(.body)
//                         .fontWeight(.medium)
//                         .foregroundColor(.black)
//                         .padding(.horizontal, 24)
//                         .padding(.vertical, 12)
//                         .background(Color.white)
//                         .cornerRadius(25)
//                 }
//             }
//             .padding(.horizontal, 16)
//             .padding(.bottom, 16)
//             .background(Color.black)
//         }
//         .background(Color.black)
//     }
// }

// struct ConnectionsSettingsViewNew_Previews: PreviewProvider {
//     static var previews: some View {
//         ConnectionsSettingsViewNew()
//             .preferredColorScheme(.dark)
//     }
// }
