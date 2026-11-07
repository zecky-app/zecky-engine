//
//  ScanOverview.swift
//  ZcashLightClientKit
//

import Foundation

/// A read-only view of how far the wallet has scanned, for a host's sync
/// details: the heights the wallet has fully and furthest scanned, and the
/// block ranges it still has to scan with the priority the engine gave them.
/// Returned by `SDKSynchronizer.scanOverview()`.
public struct ScanOverview: Equatable, Sendable {
    /// One block range still to scan.
    public struct ToScan: Equatable, Sendable {
        /// The first block of the range.
        public let first: BlockHeight
        /// The block after the last one of the range, so the range is `first..<end`.
        public let end: BlockHeight
        /// The engine's scan priority for the range (`ScanRange.Priority` raw value).
        public let priority: UInt8

        public init(first: BlockHeight, end: BlockHeight, priority: UInt8) {
            self.first = first
            self.end = end
            self.priority = priority
        }
    }

    /// The height below which every block is scanned, or `nil` when nothing is.
    public let fullyScanned: BlockHeight?
    /// The highest block scanned so far, or `nil` when nothing is.
    public let maxScanned: BlockHeight?
    /// The ranges still to scan. Ranges the engine marks as scanned or ignored are left out.
    public let toScan: [ToScan]

    public init(fullyScanned: BlockHeight?, maxScanned: BlockHeight?, toScan: [ToScan]) {
        self.fullyScanned = fullyScanned
        self.maxScanned = maxScanned
        self.toScan = toScan
    }
}
