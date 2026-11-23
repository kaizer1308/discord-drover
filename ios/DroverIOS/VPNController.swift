import NetworkExtension

@MainActor
final class VPNController {
    private let manager = NEVPNManager.shared()

    var status: NEVPNStatus { manager.connection.status }

    func load() async throws -> VPNConfiguration {
        try await manager.loadFromPreferences()
        guard let vpnProtocol = manager.protocolConfiguration as? NEVPNProtocolIKEv2 else {
            return VPNConfiguration()
        }
        return VPNConfiguration(
            server: vpnProtocol.serverAddress ?? "",
            remoteIdentifier: vpnProtocol.remoteIdentifier ?? "",
            authentication: vpnProtocol.authenticationMethod == .sharedSecret ? .sharedSecret : .password,
            username: vpnProtocol.username ?? "",
            onDemand: manager.isOnDemandEnabled
        )
    }

    func save(_ configuration: VPNConfiguration, secret: String) async throws {
        try await manager.loadFromPreferences()
        let previous = manager.protocolConfiguration as? NEVPNProtocolIKEv2
        let savedReference = configuration.authentication == .password
            ? previous?.passwordReference : previous?.sharedSecretReference
        let newReference = secret.isEmpty ? nil : try VPNKeychain.store(secret)
        guard let reference = newReference ?? savedReference else { throw ConfigurationError.missingCredential }

        do {
            manager.protocolConfiguration = try configuration.makeProtocol(credentialReference: reference)
            manager.localizedDescription = "Discord Drover"
            manager.isEnabled = true
            manager.onDemandRules = configuration.onDemand ? configuration.makeOnDemandRules() : nil
            manager.isOnDemandEnabled = configuration.onDemand
            try await manager.saveToPreferences()
        } catch {
            if let newReference { VPNKeychain.remove(newReference) }
            throw error
        }

        for oldReference in [previous?.passwordReference, previous?.sharedSecretReference].compactMap({ $0 })
            where oldReference != reference {
            VPNKeychain.remove(oldReference)
        }
    }

    func connect() async throws {
        try await manager.loadFromPreferences()
        if status == .disconnected || status == .invalid {
            try manager.connection.startVPNTunnel()
        }
    }

    func disconnect() async throws {
        try await manager.loadFromPreferences()
        if manager.isOnDemandEnabled {
            manager.isOnDemandEnabled = false
            try await manager.saveToPreferences()
        }
        manager.connection.stopVPNTunnel()
    }
}
