# Smart Task Manager

A Material 3 task manager with local accounts and per-account task storage in
SQLite. Data stays on the device and is not synchronized or backed up to a
cloud service.

## Run

```sh
flutter pub get
flutter run
```

Android and iOS use `sqflite`. Windows, Linux, and macOS initialize
`sqflite_common_ffi` at startup. Web uses `sqflite_common_ffi_web`, which stores
the database in browser IndexedDB; it is experimental and browser data is tied
to the origin/port. The database is created automatically on first launch;
local account passwords are stored as salted PBKDF2 hashes.

For web, generate the SQLite WASM and shared worker assets after dependency
updates:

```sh
flutter pub run sqflite_common_ffi_web:setup
flutter run -d chrome
```

Keep the same local web port to access the same browser database. Data remains
local and is not synchronized or backed up to a cloud service.
