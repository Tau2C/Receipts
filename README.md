# Receipts

Privacy-first receipt and loyalty tooling built with Flutter + Rust.

The app uses Flutter for UI and platform integration, Rust for core logic, and `flutter_rust_bridge` for FFI bindings.

## Current Status

This repository is currently scaffolded from the Flutter + `flutter_rust_bridge` quickstart.

Implemented today:
- Flutter app startup and Rust bridge initialization
- Example Rust API call (`greet("Tom")`)
- Generated FFI bindings for Dart and Rust
- Basic integration test proving the Rust call works end-to-end

Planned direction (from project intent):
- Loyalty account barcode management
- Receipt fetching and storage
- Price scraping and retrieval

## Tech Stack

- Flutter (Dart)
- Rust
- `flutter_rust_bridge` (v2.11.1)
- Cargokit glue package (`rust_builder/`) for mobile/desktop Rust builds

## Repository Layout

- `lib/` Flutter app and generated Dart bridge bindings
- `rust/` Rust crate with exported API used by Flutter
- `rust_builder/` Build glue for compiling Rust as a Flutter plugin
- `integration_test/` End-to-end Flutter integration test(s)
- `android/`, `ios/` Native platform projects

## Prerequisites

- Flutter SDK
- Rust toolchain (`rustup`, `cargo`)
- Platform toolchains for your target (Android SDK, Xcode for iOS)

Optional (if using Nix):
- `nix-shell` with `default.nix`

## Getting Started

1. Install Flutter dependencies:

```sh
flutter pub get
```

2. Run the app:

```sh
flutter run
```

On launch, the app initializes Rust and renders the result of calling the Rust `greet` function.

## Testing

Run unit/widget tests:

```sh
flutter test
```

Run integration tests:

```sh
flutter test integration_test
```

## Working on Rust APIs

Rust APIs exposed to Flutter live under `rust/src/api/`.

After changing Rust API signatures, regenerate bridge code:

```sh
flutter_rust_bridge_codegen generate
```

Project bridge config is in `flutter_rust_bridge.yaml`.

## Notes

- Generated files under `lib/src/rust/` and `rust/src/frb_generated.rs` are codegen output and should not be edited manually.
- `rust_builder/` is infrastructure for building Rust with Flutter; most app logic belongs in `lib/` and `rust/src/`.
