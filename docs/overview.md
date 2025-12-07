# Project Overview

This project is a cross-platform mobile application for managing and viewing personal receipts from various retailers.

## **[KEY-CONCEPT]** Core Functionality

The primary goal is to provide users with a single interface to access their digital receipts from different store accounts (e.g., Biedronka, Lidl).

The application's core features include:

1. **Secure Authentication:** Users log into their retailer accounts via an in-app browser. Session credentials are securely stored on the device using `flutter_secure_storage`.
2. **Receipt Fetching:** A core component written in Rust handles the business logic of communicating with retailer APIs to fetch receipt data.
3. **Receipt Display:** Receipts are displayed in a simple, readable list within the Flutter UI.

## **[CRITICAL]** Project Goal

The main goal is to build a functional and easy-to-use receipt viewer with analytics for monitoring home budgets.
