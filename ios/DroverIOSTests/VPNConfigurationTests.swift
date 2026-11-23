import NetworkExtension
import Security
import XCTest
@testable import DroverIOS

final class VPNConfigurationTests: XCTestCase {
    private let credentialReference = Data([1, 2, 3])

    func testBuildsUsernameAndPasswordProtocol() throws {
        let configuration = VPNConfiguration(server: " vpn.example.com ", remoteIdentifier: "vpn.example.com\n",
                                             username: " drover ")
        let result = try configuration.makeProtocol(credentialReference: credentialReference)

        XCTAssertEqual(result.serverAddress, "vpn.example.com")
        XCTAssertEqual(result.remoteIdentifier, "vpn.example.com")
        XCTAssertEqual(result.username, "drover")
        XCTAssertEqual(result.authenticationMethod, .none)
        XCTAssertTrue(result.useExtendedAuthentication)
        XCTAssertEqual(result.passwordReference, credentialReference)
        XCTAssertNil(result.sharedSecretReference)
        XCTAssertFalse(result.disconnectOnSleep)
    }

    func testBuildsPreSharedKeyProtocolWithoutUsername() throws {
        let configuration = VPNConfiguration(server: "vpn.example.com", remoteIdentifier: "vpn.example.com",
                                             authentication: .sharedSecret)
        let result = try configuration.makeProtocol(credentialReference: credentialReference)

        XCTAssertEqual(result.authenticationMethod, .sharedSecret)
        XCTAssertFalse(result.useExtendedAuthentication)
        XCTAssertEqual(result.sharedSecretReference, credentialReference)
        XCTAssertNil(result.username)
        XCTAssertNil(result.passwordReference)
    }

    func testRejectsMissingFields() {
        var configuration = VPNConfiguration(server: " ")
        XCTAssertThrowsError(try configuration.makeProtocol(credentialReference: credentialReference)) {
            XCTAssertEqual($0 as? ConfigurationError, .missingServer)
        }
        configuration.server = "vpn.example.com"
        XCTAssertThrowsError(try configuration.makeProtocol(credentialReference: credentialReference)) {
            XCTAssertEqual($0 as? ConfigurationError, .missingRemoteIdentifier)
        }
        configuration.remoteIdentifier = "vpn.example.com"
        XCTAssertThrowsError(try configuration.makeProtocol(credentialReference: credentialReference)) {
            XCTAssertEqual($0 as? ConfigurationError, .missingUsername)
        }
        configuration.username = "drover"
        XCTAssertThrowsError(try configuration.makeProtocol(credentialReference: Data())) {
            XCTAssertEqual($0 as? ConfigurationError, .missingCredential)
        }
    }

    func testOnDemandOnlyEvaluatesDiscordDomainSuffixes() throws {
        let configuration = VPNConfiguration()
        let rules = configuration.makeOnDemandRules()
        XCTAssertFalse(configuration.onDemand)
        XCTAssertEqual(rules.count, 1)

        let evaluate = try XCTUnwrap(rules.first as? NEOnDemandRuleEvaluateConnection)
        let connectionRules = try XCTUnwrap(evaluate.connectionRules)
        XCTAssertEqual(connectionRules.count, 1)

        let discordRule = try XCTUnwrap(connectionRules.first)
        XCTAssertEqual(discordRule.action, .connectIfNeeded)
        XCTAssertEqual(Set(discordRule.matchDomains), [
            "discord.com", "discordapp.com", "discord.gg", "discord.media",
            "discordapp.net", "discordcdn.com", "discord.co", "gateway.discord.gg",
        ])
    }

    func testKeychainErrorDistinguishesMissingSigningEntitlement() {
        let signingError = VPNKeychain.KeychainError(status: errSecMissingEntitlement)
        XCTAssertTrue(signingError.localizedDescription.contains("provisioning profile"))
        XCTAssertTrue(signingError.localizedDescription.contains("Keychain access group"))

        let genericError = VPNKeychain.KeychainError(status: errSecInternalError)
        XCTAssertTrue(genericError.localizedDescription.contains("\(errSecInternalError)"))
    }
}
