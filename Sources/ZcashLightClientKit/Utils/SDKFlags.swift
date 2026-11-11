//
//  SDKFlags.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-07-18.
//

import Foundation

/// A singleton actor with control flags for the SDK.
actor SDKFlags {
    /// `torEnabled` controls `SeviceMode` for the connection to the `LightWalletService`.
    /// When disabled, the `ServiceMode.direct` (GRPC) is enforced.
    /// When enabled, all Tor cases in `ServiceMode` are allowed.
    /// Accessible only internally inside the SDK to control the connection
    var torEnabled: Bool

    /// `exchangeRateEnabled` controls whether fetch of exnchage rate is enabled or disabled.
    /// When enabled, the `TorClient` is initialized but is not used for lwdService calls.
    var exchangeRateEnabled: Bool

    /// Zecky: `submitOverTor` sends transactions over Tor while every other
    /// lightwalletd call stays on its own connection ("own node for reading,
    /// Tor for sending"). Unlike `torEnabled` it changes nothing for reads, so
    /// it works with a sync endpoint Tor cannot reach, such as a node on this
    /// machine. Set through `SDKSynchronizer.submitOverTor(enabled:)` before
    /// the synchronizer starts, so background retries follow it from the
    /// first block.
    var submitOverTor = false

    /// This flag communicates state of initialization of `TorClient`
    /// `nil` = the attempt to initialize `TorClient` hasn't been initiated
    /// `false` = initialization of `TorClient` failed
    /// `true` = initialization of `TorClient` succeeded
    var torClientInitializationSuccessfullyDone: Bool?

    /// Runtime helper flag used to mark whether chainTip CBP action has been done.
    var chainTipUpdated = false
    var chainTipUpdatedTimestamp: TimeInterval = 0.0

    init(
        torEnabled: Bool,
        exchangeRateEnabled: Bool
    ) {
        self.torEnabled = torEnabled
        self.exchangeRateEnabled = exchangeRateEnabled
    }

    /// Helper method that wraps the decision logic for `ServiceMode`.
    /// When Tor is not enabled, it always must use fallback to `.direct` mode.
    func ifTor(_ serviceMode: ServiceMode) -> ServiceMode {
        torEnabled ? serviceMode : .direct
    }

    /// Use to update the `torEnabled` flag
    func torFlagUpdate(_ newFlag: Bool) {
        torEnabled = newFlag
    }

    /// Use to update the `submitOverTor` flag
    func submitOverTorFlagUpdate(_ newFlag: Bool) {
        submitOverTor = newFlag
    }

    /// Zecky: whether a submission to `endpoint` goes over Tor. Always when
    /// Tor is enabled for everything (unchanged upstream behaviour). With
    /// `submitOverTor`, every endpoint Tor can reach; an endpoint on this
    /// machine or a private network (the user's own node) cannot be reached
    /// through Tor and is contacted directly, which the app only asks for
    /// with the user's say-so. There is no fallback from Tor to a direct
    /// connection: a failed Tor submission fails.
    func submitsOverTor(to endpoint: LightWalletEndpoint) -> Bool {
        torEnabled || (submitOverTor && !endpoint.isOnPrivateNetwork)
    }

    // Use to update the `exchangeRateEnabled` flag
    func exchangeRateFlagUpdate(_ newFlag: Bool) {
        exchangeRateEnabled = newFlag
    }

    /// Use to update the `torClientInitializationSuccessfullyDone` flag
    func torClientInitializationSuccessfullyDoneFlagUpdate(_ newFlag: Bool?) {
        torClientInitializationSuccessfullyDone = newFlag
    }

    /// Use to update the `chainTipUpdated` flag
    func markChainTipAsUpdated() {
        chainTipUpdated = true
        chainTipUpdatedTimestamp = Date().timeIntervalSince1970
    }

    /// The client using the SDK called `start()`.
    /// Use this to reset or update any relevant flags if needed.
    func sdkStarted() {
        // If chain tip has been updated recently and is set to false, re-enable it
        if !chainTipUpdated && Date().timeIntervalSince1970 - chainTipUpdatedTimestamp < 120 {
            chainTipUpdated = true
        }
    }

    /// The client using the SDK called `stop()`, for example when the app is about to enter the background lifecycle.
    /// Use this to reset or update any relevant flags if needed.
    func sdkStopped() {
        // The SDK is stopped, so there will be a gap before the next start (doesn’t matter whether it’s a cold or foreground start).
        // The chain tip might be old enough to cause issues when attempting to send or shield funds before the next chain tip update call finishes.
        // Therefore, it is reset here.
        chainTipUpdated = false
    }
}
