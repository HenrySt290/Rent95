# Flutter Audit Pipeline

Rent95 ships an end-to-end quality/safety/performance gate for the Flutter app.
Same script runs identically on your laptop and in CI.

## What runs

| Phase | Command                                              | Fatal? |
|-------|------------------------------------------------------|--------|
| 1     | `flutter clean` + `flutter pub get`                  | ✅     |
| 2     | `flutter analyze --fatal-infos --fatal-warnings`     | ✅     |
| 3     | `dart format --output=none --set-exit-if-changed`    | ✅     |
| 4     | `dart pub outdated` (drift report)                   | ⚠ warn |
| 5     | `dart pub security audit` (native) + retracted check | ✅     |
| 6     | `flutter build <platform> --release --analyze-size`  | ✅     |

## Local usage

```bash
# Full audit (all six phases)
./scripts/audit.sh

# Fast PR-mode (skip the ~5 min build/size step)
./scripts/audit.sh --skip-build

# Profile iOS build size instead of Android APK
./scripts/audit.sh --platform ios

# Toggle Phase 4 off via env
SKIP_OUTDATED=1 ./scripts/audit.sh
```

Artifacts land in `build/audit/`:
- `pub-outdated.txt` / `pub-outdated.json` – Phase 4 drift snapshot
- `dep-security.txt` – Phase 5 audit output
- `size-analysis-<platform>.json` – Phase 6, open in DevTools > App Size Tool
- `build-<platform>.log` – full build stdout

## CI activation

The GitHub App scoped to this Arena session **cannot** push files under
`.github/workflows/` (missing `workflows` OAuth scope). The workflow therefore
ships as `deploy-templates/audit.yml`. To activate:

```bash
git checkout arena/019fa3e2-rent95
git pull
mkdir -p .github/workflows
git mv deploy-templates/audit.yml .github/workflows/audit.yml
git commit -m "ci: enable Flutter audit workflow"
git push
```

Once activated, the workflow gates every PR to `main`/`develop` on Phases 1–5,
and runs the full build+size matrix on pushes to `main` (or PRs tagged with
the `size` label).

## Strict analyzer config

`analysis_options.yaml` layers on top of `package:flutter_lints/flutter.yaml`:

- **Type safety** — `strict-casts`, `strict-inference`, `strict-raw-types`
  are all `true`; `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`,
  `always_declare_return_types` promoted to **errors**.
- **Debug hygiene** — `avoid_print`, `avoid_web_libraries_in_flutter`,
  `discarded_futures`, `unawaited_futures`.
- **`const` correctness** — `prefer_const_constructors`,
  `prefer_const_literals_to_create_immutables`,
  `prefer_const_declarations` are errors, not hints.
- **Widget hygiene** — `use_key_in_widget_constructors`,
  `sized_box_for_whitespace`, `sort_child_properties_last`.
- **Error handling** — `only_throw_errors`, `avoid_catches_without_on_clauses`,
  `use_rethrow_when_possible`.

Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `generated/**`)
are excluded, as are platform native folders (`android/`, `ios/`, etc.).

## Native tools first, fallbacks second

Phase 5 tries the modern native path (`dart pub security audit`, available on
recent Dart SDKs). If your SDK doesn't expose it yet, we fall back to:

1. `dart pub outdated --show-all --json` to detect **discontinued** or
   **retracted** packages (which the pub CLI flags in metadata).
2. Optional `pana` deep scan — enable by setting `AUDIT_INSTALL_PANA=1`.

## Troubleshooting

- **Phase 2 fails on generated files** — check `analyzer.exclude` in
  `analysis_options.yaml`. Add your codegen glob.
- **Phase 3 fails only in CI** — your editor is not on the pinned Dart
  formatter version. Run `dart format .` locally and commit.
- **Phase 6 OOMs in CI** — bump `runs-on` to `ubuntu-latest-l` or split the
  matrix (`apk` on PR, `aab` nightly only).
