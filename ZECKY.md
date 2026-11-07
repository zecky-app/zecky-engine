# Zecky engine

The Zcash light-client engine (`libzcashlc`) used by Zecky Lock it (iPhone and
Mac) and Zecky Pocket.

## What it is

- **All cryptography, key derivation, proofs and transaction building come from
  the official Zcash core, librustzcash**, as published on crates.io by the Zcash
  developers (MIT OR Apache-2.0). Zecky does not implement any of it.
- **The FFI (the C functions the apps call)** is the official one from
  [zcash-swift-wallet-sdk](https://github.com/zcash/zcash-swift-wallet-sdk) **4.0.0**
  (MIT), imported unchanged in the first commit (tag `upstream-4.0.0`).
- 4.0.0 is the final release of that SDK and does not support NU7. The second
  commit adapts **only the FFI connection code** to the NU7 releases of the
  librustzcash crates. `git diff upstream-4.0.0` shows every change.

## NU7

| | |
|---|---|
| Activation height (mainnet) | 3,543,405 |
| Consensus branch ID | `0x77190AD9` |
| Block spacing after NU7 | 25 seconds (ZIP 218) |
| Source of these values | `zcash_protocol` 0.11.0 (`consensus.rs`) |

Proven by the test `tests::branch_id_for_height_selects_nu7_from_its_mainnet_activation`
(rust/src/lib.rs): `zcashlc_branch_id_for_height` returns NU6.3 (`0x37A5165B`) at
3,543,404 and NU7 (`0x77190AD9`) from 3,543,405.

## Core versions (pinned in Cargo.lock, with crates.io checksums)

zcash_protocol 0.11.0 · zcash_primitives 0.31.0 · zcash_proofs 0.31.0 ·
zcash_client_backend 0.25.0 · zcash_client_sqlite 0.23.0 · zcash_keys 0.17.0 ·
zcash_address 0.14.0 · zcash_transparent 0.11.0 · orchard 0.16.0 ·
sapling-crypto 0.9.0 · pczt 0.10.0 · halo2_proofs 0.4.0 · redjubjub 0.9.0 ·
reddsa 0.6.1

## What the NU7 commit changes (connection code only)

- Dependency versions moved to the NU7 releases; the `[patch]` git pins to
  in-progress librustzcash revisions were removed. All Zcash crates come from
  crates.io releases, checked by checksum in Cargo.lock.
- Two dependencies still come from git, as in upstream 4.0.0: `ur` and
  `ur-registry` from Keystone (they read and write the QR codes of the Keystone
  hardware wallet). Both are pinned to an exact commit, not a tag.
- Community voting is removed: the `zcash_voting` dependency, its FFI functions
  (`zcashlc_voting_*`) and, in the Swift package, its wrapper and tests. Zecky
  does not use it, and it pulled in many crates of its own.
- `rust/src/rng_compat.rs`: `rand` 0.10 has no `OsRng`; the same operating-system
  generator (getrandom → `CCRandomGenerateBytes` on iOS, `getentropy` on macOS) is passed where the new
  APIs ask for an RNG. It panics rather than degrade if the OS generator fails.
- New explicit arguments the crates now require (RNG, clock, network block
  spacing), type conversions, and the ZIP 316 revision 2 address API (the engine
  still emits revision 0 addresses, readable by every wallet).
- The single-use transparent address check keeps a one-day window at the chain
  tip's block spacing, and counts its retry delay in 75-second reference
  blocks, so it checks at the same pace in time before and after NU7.
- Clearer errors: `RecipientAddressExpired` for an expired ZIP 316 revision 2
  address, and `NoSupportedReceivers` for an address with no payable receiver.
- No remaining C function changed its signature; the voting functions are gone.

- `libc` is held at 0.2.189, the version upstream 4.0.0 shipped. From 0.2.190
  libc declares `proc_pidinfo` for macOS only, and `sysinfo` (used by Tor's
  memory quota) then fails to compile for iOS. Check this before moving it.

- Dependency age: every crate in Cargo.lock was published at least 14 days
  before the build (checked against crates.io on November 5, 2026; cutoff
  October 22). 37 newer patch releases were pinned back with
  `cargo update -p <crate> --precise <version>`, among them bls12_381 0.9.0,
  pairing 0.24.0, halo2_proofs 0.4.0, equihash 0.3.0 and aes 0.9.3 (the newer
  ones only change performance). None had to stay new: the NU7 core crates
  themselves were released on October 21.

## Build

On a Mac with Xcode and rustup:

```
make -C BuildSupport install
make ffi-all
```

The result is `BuildSupport/products/libzcashlc.xcframework`. Record its
SHA-256 in the apps' engine checksum tests together with the commit it was
built from. Builds use the committed Cargo.lock (`--locked`).

## Checks

The upstream GitHub workflows (CI on macOS, CodeQL, zizmor, proto sync) and
Dependabot were removed: they target the Zcash team's setup. Every engine
change is checked by `cargo test`, an independent review of the FFI diff and
a full Mac build before it is released.

## Updating

For each Zcash network upgrade or security release of librustzcash: bump the
crates, run `cargo test`, review the FFI diff independently, rebuild, update the
checksum pins in the apps, test on testnet, then one small mainnet send.

## Licence

MIT, as the upstream SDK (see LICENSE). The librustzcash crates are MIT OR
Apache-2.0.
