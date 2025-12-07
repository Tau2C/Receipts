# GEMINI.MD: AI Collaboration Guide

This document provides essential context for AI models interacting with this project. Adhering to these guidelines will ensure consistency and maintain code quality.

## 1. Project Overview & Purpose

+ **Primary Goal:** This is a cross-platform mobile application built with Flutter to manage and display receipts from various retailers.
+ **Business Domain:** Retail / Personal Finance. The application allows users to log into their store accounts and view their purchase history.

## 2. Core Technologies & Stack

+ **Languages:**
  + Dart (SDK: ^3.5.0)
  + Rust (Edition: 2024)
+ **Frameworks & Runtimes:**
  + Flutter (for the UI)
+ **Databases:**
  + SQLITE. `flutter_secure_storage` is employed for securely persisting session credentials on the device.
+ **Key Libraries/Dependencies:**
  + **Flutter/Dart:** `flutter_rust_bridge` (for native code interop), `flutter_secure_storage` (for credentials).
  + **Rust:** `flutter_rust_bridge` (for native code interop).
+ **Package Manager(s):**
  + `pub` for Dart/Flutter.
  + `cargo` for Rust.

## 3. Architectural Patterns

+ **Overall Architecture:** The project follows a hybrid architecture where the user interface is built with Flutter, and the core business logic (API interaction, data processing) is implemented in a Rust library. `flutter_rust_bridge` is used to create a seamless connection between the Dart front-end and the Rust back-end.
+ **Directory Structure Philosophy:**
  + `/app/lib`: Contains all Dart source code for the Flutter application.
  + `/app/rust`: Contains the Rust source code for the native library that handles business logic.
  + `/app/integration_test`: Contains integration tests that verify the Flutter app's behavior, including its interaction with the Rust layer.
  + `/app/rust_builder`: A helper package likely used by `cargokit` to build and integrate the Rust code into the Flutter project for different platforms.
  + Standard Flutter platform directories (`/app/android`, `/app/ios`, `/app/linux`, etc.) for platform-specific code.

## 4. Coding Conventions & Style Guide

+ **Formatting:** The project uses `flutter_lints`, which enforces the standard Dart and Flutter style guides. Adhere to the rules defined in `/app/analysis_options.yaml`.
+ **Naming Conventions:**
  + `variables`, `functions`: `camelCase`
  + `classes`, `enums`: `PascalCase`
  + `files`: `snake_case.dart`
+ **API Design:** The internal API between Dart and Rust is defined in the `/app//rust/src/api/` directory. Changes here require running the `flutter_rust_bridge` code generator. The external API interactions with retailer backends are handled within the Rust crate.
+ **Error Handling:** In Dart, use `try...catch` blocks for calls to the Rust library. The Rust code should propagate errors up to the Dart layer.

## 5. Key Files & Entrypoints

+ **Main Entrypoint(s):**
  + **Flutter App:** `/app/lib/main.dart`
  + **Rust Library:** `/app/rust/src/lib.rs`
+ **Configuration:**
  + **Flutter Dependencies:** `/app/pubspec.yaml`
  + **Rust Dependencies:** `/app/rust/Cargo.toml`
  + **Dart/Rust Bridge:** `/app/flutter_rust_bridge.yaml`
  + **Linter Rules:** `/app/analysis_options.yaml`

## 6. Development & Testing Workflow

+ **Local Development Environment:** Requires a full Flutter installation and the Rust toolchain (including `cargo`). The `flutter_rust_bridge` code generator is run automatically when running compiling flutter.
+ **Testing:** Integration tests are located in `/app/integration_test`. They are run using the `flutter test integration_test` command. New features should be accompanied by corresponding integration tests that validate the UI and the underlying Rust logic.
+ **CI/CD Process:** No CI/CD pipeline is configured in the repository at this time.

## 7. Specific Instructions for AI Collaboration

+ **Contribution Guidelines:** No formal `CONTRIBUTING.md` exists. Follow the existing patterns and conventions outlined in this document.
+ **Infrastructure (IaC):** No Infrastructure as Code is present in this project.
+ **Security:** Be mindful of security. Session tokens are stored using `flutter_secure_storage`. Do not log or expose sensitive user data or credentials.
+ **Dependencies:**
  + To add a new Dart dependency, use `flutter pub add <package>`.
  + To add a new Rust dependency, `cd rust` and use `cargo add <crate>`.
  + After adding a dependency, ensure the project still builds and all tests pass.
+ **Commit Messages:** Follow the Conventional Commits specification (e.g., `feat:`, `fix:`, `docs:`, `refactor:`) to maintain a clean and readable git history.
+ **Limitations:** The AI cannot directly execute commands like `flutter run` or other commands that require an interactive terminal or a running device/emulator. These commands will be cancelled by the user.

## 8. Documentation

Documentation instructions are located in the `docs/AGENT_INSTRUCTIONS.md` file.

Please read that file and follow the rules and prompts within it when interacting with this project's documentation.

## 9. Debugging

For scripts that are used for debugging or development purposes, such as generating placeholder images, add any necessary dependencies to `dev_dependencies`. These scripts should be accessible from a debug menu within the application to allow for debugging on a device.
