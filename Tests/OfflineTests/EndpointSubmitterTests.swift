//
//  EndpointSubmitterTests.swift
//  ZcashLightClientKitTests
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class EndpointSubmitterTests: ZcashTestCase {
    private func makeSubmitter() throws -> GRPCEndpointSubmitter {
        GRPCEndpointSubmitter(
            torClient: TorClient(torDir: try __torDirURL()),
            sdkFlags: SDKFlags(torEnabled: false, exchangeRateEnabled: false),
            logger: submissionLifecycleLogger()
        )
    }

    private func makeTransaction() -> CreatedTransaction {
        CreatedTransaction(
            txId: Data(repeating: 0xAB, count: 32),
            raw: Data([0x01, 0x02, 0x03, 0x04]),
            expiryHeight: 123_456
        )
    }

    private func makeSendResponse(errorCode: Int32, errorMessage: String) -> SendResponse {
        var response = SendResponse()
        response.errorCode = errorCode
        response.errorMessage = errorMessage
        return response
    }

    func testSubmitDeliversRawBytesToEndpoint() async throws {
        let service = try RecordingCompactTxStreamerService(sendResponse: makeSendResponse(errorCode: 0, errorMessage: ""))
        defer { try? service.stop() }
        let submitter = try makeSubmitter()
        let transaction = makeTransaction()

        try await submitter.submit(transaction: transaction, to: service.endpoint)

        XCTAssertEqual(service.recordedTransactions(), [transaction.raw])
    }

    func testSubmitThrowsSubmitErrorOnServerRejection() async throws {
        let service = try RecordingCompactTxStreamerService(sendResponse: makeSendResponse(errorCode: -25, errorMessage: "rejected"))
        defer { try? service.stop() }
        let submitter = try makeSubmitter()

        do {
            try await submitter.submit(transaction: makeTransaction(), to: service.endpoint)
            XCTFail("Expected submitError")
        } catch let TransactionEncoderError.submitError(code, message) {
            XCTAssertEqual(code, -25)
            XCTAssertEqual(message, "rejected")
        }
    }

    func testSubmitThrowsTransportErrorForUnreachableEndpoint() async throws {
        let submitter = try makeSubmitter()
        // Nothing listens on this port; expect a transport-level failure.
        let endpoint = LightWalletEndpoint(
            address: "127.0.0.1",
            port: 1,
            secure: false,
            singleCallTimeoutInMillis: 2_000,
            streamingCallTimeoutInMillis: 2_000
        )

        do {
            try await submitter.submit(transaction: makeTransaction(), to: endpoint)
            XCTFail("Expected a transport error")
        } catch let TransactionEncoderError.submitError(code, message) {
            XCTFail("Expected a transport error, not a server rejection: \(code) \(message)")
        } catch {
            // Any non-submitError error is the expected transport failure.
        }
    }

    // MARK: Zecky: Tor for sending only

    func testPrivateNetworkEndpoints() {
        let isPrivate = { (host: String) in LightWalletEndpoint(address: host, port: 8137, secure: false).isOnPrivateNetwork }
        for host in ["127.0.0.1", "localhost", "LOCALHOST", "10.0.0.5", "192.168.1.32", "172.16.0.1", "172.31.255.255", "100.64.0.1", "100.127.1.1"] {
            XCTAssertTrue(isPrivate(host), host)
        }
        for host in ["zec.rocks", "8.8.8.8", "172.32.0.1", "100.128.0.1", "192.169.1.1", "010.0.0.1", "127.1", "127.0.0.1.evil.example", "", "1.2.3.256", "::1"] {
            XCTAssertFalse(isPrivate(host), host)
        }
    }

    func testSubmitOverTorRule() async {
        let own = LightWalletEndpoint(address: "127.0.0.1", port: 8137, secure: false)
        let server = LightWalletEndpoint(address: "zec.rocks", port: 443, secure: true)

        let off = SDKFlags(torEnabled: false, exchangeRateEnabled: false)
        let offOwn = await off.submitsOverTor(to: own)
        let offServer = await off.submitsOverTor(to: server)
        XCTAssertFalse(offOwn)
        XCTAssertFalse(offServer)

        let sending = SDKFlags(torEnabled: false, exchangeRateEnabled: false)
        await sending.submitOverTorFlagUpdate(true)
        let sendingOwn = await sending.submitsOverTor(to: own)
        let sendingServer = await sending.submitsOverTor(to: server)
        XCTAssertFalse(sendingOwn, "the own node is reached directly: Tor cannot reach it")
        XCTAssertTrue(sendingServer, "a public server only over Tor")

        // Upstream behaviour unchanged: Tor for everything.
        let everything = SDKFlags(torEnabled: true, exchangeRateEnabled: false)
        let everythingOwn = await everything.submitsOverTor(to: own)
        XCTAssertTrue(everythingOwn)
    }

    func testSubmitOverTorStillDeliversToTheOwnNodeDirectly() async throws {
        let service = try RecordingCompactTxStreamerService(sendResponse: makeSendResponse(errorCode: 0, errorMessage: ""))
        defer { try? service.stop() }
        let flags = SDKFlags(torEnabled: false, exchangeRateEnabled: false)
        await flags.submitOverTorFlagUpdate(true)
        let submitter = GRPCEndpointSubmitter(
            torClient: TorClient(torDir: try __torDirURL()),
            sdkFlags: flags,
            logger: submissionLifecycleLogger()
        )
        let transaction = makeTransaction()
        XCTAssertTrue(service.endpoint.isOnPrivateNetwork)

        try await submitter.submit(transaction: transaction, to: service.endpoint)

        XCTAssertEqual(service.recordedTransactions(), [transaction.raw])
    }
}
