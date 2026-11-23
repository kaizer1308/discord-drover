import NetworkExtension
import SwiftUI

@main
struct DroverApp: App {
    var body: some Scene {
        WindowGroup {
            VPNView()
        }
    }
}

private struct VPNView: View {
    @State private var controller = VPNController()
    @State private var configuration = VPNConfiguration()
    @State private var secret = ""
    @State private var status = NEVPNStatus.invalid
    @State private var isBusy = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("VPN status", value: statusText)
                    if isConnectedOrConnecting {
                        Button("Disconnect") { performDisconnect() }
                    } else {
                        Button("Connect") { performSave(connect: true) }
                            .disabled(status == .disconnecting)
                    }
                } footer: {
                    Text("For Discord voice, connect before opening Discord or joining a call. Your VPN may also carry traffic from other apps.")
                }

                Section("IKEv2 server") {
                    TextField("Server address", text: $configuration.server)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                    TextField("Remote ID", text: $configuration.remoteIdentifier)
                    Picker("Authentication", selection: $configuration.authentication) {
                        ForEach(Authentication.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    if configuration.authentication == .password {
                        TextField("Username", text: $configuration.username)
                            .textContentType(.username)
                    }
                    SecureField(configuration.authentication == .password ? "Password" : "Pre-shared key", text: $secret)
                        .onChange(of: configuration.authentication) { _, _ in secret = "" }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isConnectedOrConnecting || status == .disconnecting)

                Section {
                    Toggle("Connect on demand for Discord domains", isOn: $configuration.onDemand)
                    Button("Save configuration") { performSave(connect: false) }
                } footer: {
                    Text("On demand can start the VPN if a matching Discord hostname is unreachable. It does not route Discord separately and may not start when only voice is blocked. Disconnect turns on demand off.")
                }
                .disabled(isConnectedOrConnecting || status == .disconnecting)
            }
            .navigationTitle("Discord Drover")
            .disabled(isBusy)
            .overlay { if isBusy { ProgressView() } }
        }
        .task {
            await run {
                configuration = try await controller.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
            status = controller.status
        }
        .alert("VPN error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var isConnectedOrConnecting: Bool {
        [.connecting, .connected, .reasserting].contains(status)
    }

    private var statusText: String {
        switch status {
        case .invalid: return "Not configured"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reasserting: return "Reconnecting"
        case .disconnecting: return "Disconnecting"
        @unknown default: return "Unknown"
        }
    }

    private func performSave(connect: Bool) {
        Task {
            await run {
                try await controller.save(configuration, secret: secret)
                secret = ""
                if connect { try await controller.connect() }
            }
        }
    }

    private func performDisconnect() {
        Task {
            await run {
                try await controller.disconnect()
                configuration.onDemand = false
            }
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        isBusy = true
        defer {
            status = controller.status
            isBusy = false
        }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
