# sansebassms

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase setup

This project expects the `GOOGLE_SERVICE_INFO_PLIST_B64` environment variable
to provide the `GoogleService-Info.plist` contents during build time.

- The variable may contain **either** the Base64 encoding of the raw plist
  file **or** the full XML content pasted directly (both formats are supported).
- To generate Base64 in PowerShell:

  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\sansebassmsFirebase\GoogleService-Info.plist")) | Out-File -Encoding ascii -NoNewline "plist.b64.txt"
  ```

- Paste the variable content **without quotes** and **without extra spaces**.

## CI

El build usa `--no-codesign`; Codemagic firma en Publish.
