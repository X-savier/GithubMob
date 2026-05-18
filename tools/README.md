# tools/

Out-of-band helpers for the ViewXRent test harness.

## `mobile_read_probe.dart`

Pure-Dart CLI used by `tests/contract/runner.spec.js` to perform reads from a "mobile-shaped" perspective (mirroring `lib/services/*.dart` query shapes) without needing the Flutter engine.

The Flutter app imports `supabase_flutter`, which depends on a Flutter binding — that means `lib/services/*.dart` can't run from a plain `dart run`. This probe re-implements the same query shapes using the pure-dart `supabase` package, which IS callable from `dart run`. Anything that exercises Edge Functions or Postgres queries against the same test project is fair game for the probe.

### Use

```
cd tools
dart pub get
```

Then opt into the probe path from the contract runner:

```
RUN_MOBILE_PROBE=1 npm --prefix tests run test:contract
```

The runner sets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and the tenantA credentials in the subprocess env.

### Add a command

Each new command lives in `_dispatch()` in `mobile_read_probe.dart`. Mirror the return shape of the corresponding `lib/services/*.dart` function so the cross-platform runner can compare web vs. mobile output field-by-field.
