import NetworkExtension
import SwiftUI

@main
struct DroverApp: App {
    var body: some Scene {
        WindowGroup {
            VPNView()
                .preferredColorScheme(.dark)
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
    @FocusState private var field: Field?
    @ScaledMetric private var rowHeight = 44.0

    private enum Field: Hashable { case server, remoteID, username, secret }

    private static let accent = Color(red: 0.39, green: 0.36, blue: 0.91)

    var body: some View {
        ScrollView {
            Group {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) { panels }
                } else {
                    panels
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .disabled(isBusy)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            LinearGradient(colors: [
                Color(red: 0.09, green: 0.10, blue: 0.22),
                Color(red: 0.035, green: 0.04, blue: 0.085),
                Color(red: 0.02, green: 0.025, blue: 0.05),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
            .overlay {
                RadialGradient(colors: [Self.accent.opacity(0.26), .clear],
                               center: .topTrailing, startRadius: 15, endRadius: 420)
            }
            .ignoresSafeArea()
        }
        .onChange(of: configuration.authentication) { _, _ in secret = "" }
        .task {
            await run {
                configuration = try await controller.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
            status = controller.status
        }
    }

    private var panels: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PERSONAL VPN")
                    .font(.caption2.weight(.semibold))
                    .tracking(2.5)
                    .foregroundStyle(Color(red: 0.66, green: 0.66, blue: 1))
                Text("Discord Drover")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text("IKEv2 tunnel for Discord voice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            connectionPanel
            serverPanel
            settingsPanel
            Text("Connect before joining voice. Other apps may also use the tunnel.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Self.accent.opacity(0.45), in: .rect(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("VPN status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 7) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(statusText)
                            .font(.headline)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                if isBusy { ProgressView().accessibilityLabel("Updating VPN") }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1, green: 0.74, blue: 0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("vpnError")
            }

            connectButton
                .disabled(status == .disconnecting)
        }
        .padding(15)
        .glassPanel()
    }

    private var connectButton: some View {
        let button = Button {
            if isConnectedOrConnecting { performDisconnect() } else { performSave(connect: true) }
        } label: {
            Label(isConnectedOrConnecting ? "Disconnect" : "Connect",
                  systemImage: isConnectedOrConnecting ? "stop.fill" : "power")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }

        return Group {
            if #available(iOS 26.0, *) { button.buttonStyle(.glassProminent) }
            else { button.buttonStyle(.borderedProminent).buttonBorderShape(.capsule) }
        }
        .controlSize(.large)
        .tint(Self.accent)
    }

    private var serverPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IKEv2 server")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if field != nil {
                    Button("Done") { field = nil }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.73, green: 0.72, blue: 1))
                }
            }
            .padding(.bottom, 4)

            row("server.rack") {
                TextField("Server address", text: $configuration.server)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .focused($field, equals: .server)
            }
            Divider()
            row("person.text.rectangle") {
                TextField("Remote ID", text: $configuration.remoteIdentifier)
                    .focused($field, equals: .remoteID)
            }
            Divider()
            row("lock.shield") {
                Picker("Authentication", selection: $configuration.authentication) {
                    ForEach(Authentication.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .padding(.leading, -8)
            }
            if configuration.authentication == .password {
                Divider()
                row("person") {
                    TextField("Username", text: $configuration.username)
                        .textContentType(.username)
                        .focused($field, equals: .username)
                }
            }
            Divider()
            row("key") {
                SecureField(configuration.authentication == .password ? "Password" : "Pre-shared key", text: $secret)
                    .focused($field, equals: .secret)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit { field = nil }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .padding(.bottom, 4)
        .glassPanel()
        .disabled(isConnectedOrConnecting || status == .disconnecting)
    }

    private func row<Content: View>(_ icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.70, green: 0.71, blue: 0.91))
                .frame(width: 20)
                .accessibilityHidden(true)
            content()
        }
        .frame(minHeight: rowHeight)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $configuration.onDemand) {
                Label("Connect on demand", systemImage: "bolt.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Self.accent)
            Text("Uses Discord domains, not a per-app route. May not start for voice-only blocks; disconnecting turns it off.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            let saveButton = Button("Save configuration") { performSave(connect: false) }
                .font(.subheadline.weight(.semibold))
            if #available(iOS 26.0, *) { saveButton.buttonStyle(.glass) }
            else { saveButton.buttonStyle(.bordered) }
        }
        .padding(15)
        .glassPanel()
        .disabled(isConnectedOrConnecting || status == .disconnecting)
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .mint
        case .connecting, .reasserting, .disconnecting: return .orange
        default: return .secondary
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
        field = nil
        errorMessage = nil
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

private extension View {
    @ViewBuilder
    func glassPanel() -> some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay { shape.strokeBorder(.white.opacity(0.1)).allowsHitTesting(false) }
        }
    }
}
