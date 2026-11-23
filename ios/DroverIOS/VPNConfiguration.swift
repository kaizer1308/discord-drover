import Foundation
import NetworkExtension

enum Authentication: String, CaseIterable, Identifiable {
    case password = "Username & password"
    case sharedSecret = "Pre-shared key"

    var id: Self { self }
}

struct VPNConfiguration {
    var server = ""
    var remoteIdentifier = ""
    var authentication = Authentication.password
    var username = ""
    var onDemand = false

    func makeProtocol(credentialReference: Data) throws -> NEVPNProtocolIKEv2 {
        let server = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteIdentifier = remoteIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !server.isEmpty else { throw ConfigurationError.missingServer }
        guard !remoteIdentifier.isEmpty else { throw ConfigurationError.missingRemoteIdentifier }
        guard authentication != .password || !username.isEmpty else { throw ConfigurationError.missingUsername }
        guard !credentialReference.isEmpty else { throw ConfigurationError.missingCredential }

        let vpnProtocol = NEVPNProtocolIKEv2()
        vpnProtocol.serverAddress = server
        vpnProtocol.remoteIdentifier = remoteIdentifier
        vpnProtocol.disconnectOnSleep = false

        switch authentication {
        case .password:
            vpnProtocol.authenticationMethod = .none
            vpnProtocol.useExtendedAuthentication = true
            vpnProtocol.username = username
            vpnProtocol.passwordReference = credentialReference
        case .sharedSecret:
            vpnProtocol.authenticationMethod = .sharedSecret
            vpnProtocol.useExtendedAuthentication = false
            vpnProtocol.sharedSecretReference = credentialReference
        }
        return vpnProtocol
    }

    func makeOnDemandRules() -> [NEOnDemandRule] {
        let evaluate = NEOnDemandRuleEvaluateConnection()
        evaluate.connectionRules = [NEEvaluateConnectionRule(matchDomains: [
            "discord.com", "discordapp.com", "discord.gg", "discord.media",
            "discordapp.net", "discordcdn.com", "discord.co", "gateway.discord.gg",
        ], andAction: .connectIfNeeded)]
        return [evaluate]
    }
}

enum ConfigurationError: LocalizedError {
    case missingServer, missingRemoteIdentifier, missingUsername, missingCredential

    var errorDescription: String? {
        switch self {
        case .missingServer: return "Enter the IKEv2 server address."
        case .missingRemoteIdentifier: return "Enter the remote ID provided by your VPN server."
        case .missingUsername: return "Enter your VPN username."
        case .missingCredential: return "Enter your VPN password or pre-shared key."
        }
    }
}
