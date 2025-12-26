Purpose
-------
This file gives concise, repo-specific guidance for AI coding agents working in this k6-based API test repository. Focus on discoverable patterns, developer workflows, and concrete commands so an agent can be immediately productive.

Key locations
-------------
- Tests: [tests/1_health.js](tests/1_health.js) and the rest of the `tests/` folder.
- Reports: [reports](reports) (HTML test reports are written here).
- Helpers / scripts: `run_all_tests.bat`, `combined_report.bat` at repo root; see [README.md](README.md) for context.

Big picture
-----------
- This repository contains k6 JavaScript test scripts in `tests/`. Each file is a standalone k6 script executed with `k6 run`.
- Test files are named with a numerical prefix to indicate sequence and variants use suffixes like `_BR` and `_UR` (e.g. `10.1_get_note.js`, `10.2_get_note_BR.js`). Treat the numeric prefix as an ordering key and suffixes as variant indicators — do not rename without updating any coordinating scripts.
- Test outputs are produced as HTML reports (see `reports/`). `run_all_tests.bat` is the convenience wrapper used to run the whole suite on Windows.

Developer workflows (concrete)
-----------------------------
- Run a single test (from `tests` folder):

```powershell
cd tests
k6 run .\1_health.js
```

- Run all tests (Windows, from `tests` folder):

```powershell
cd tests
.\run_all_tests.bat
```

- Combine or rearrange reports: `combined_report.bat` exists but README notes it "needs adjustments"; inspect the file before running.

Project-specific patterns & conventions
-------------------------------------
- File naming: numeric prefix (ordering) + descriptive slug + optional variant suffixes (`_BR`, `_UR`). When adding tests, follow the existing numbering scheme.
- Reports: tests produce HTML files placed under `reports/` using the naming convention `NN.M_name[_VAR]?.html`. New report generation should follow that pattern to stay consistent.
- Platform: repo is set up for Windows usage (batch files). Prefer PowerShell/CMD commands when writing or updating scripts unless cross-platform support is intentionally added.
- k6 dependency/version: README documents k6 v1.4.0 as the expected version; keep generated command-lines compatible with installed k6.

Integration points & external dependencies
-----------------------------------------
- Tests call the expandtesting API (see README links). Network access and valid API endpoints are required when running tests.
- Report generation likely depends on `k6-reporter` or similar tooling (refer to README and `combined_report.bat`). Inspect bat files to see how HTML files are produced.

What to avoid changing without verification
-----------------------------------------
- Do not rename or reorder tests without updating `run_all_tests.bat` or any orchestration scripts that rely on filename patterns.
- Do not run `combined_report.bat` blindly; it is flagged in documentation as needing adjustments.

Examples agents should use when editing or adding tests
-----------------------------------------------------
- To add a new test after `9.2_get_all_notes_UR.js`:

1. Create `tests/10.1_new_feature.js` following the structure of existing k6 scripts.
2. Run it locally: `k6 run .\tests\10.1_new_feature.js`
3. Confirm HTML report appears under `reports/`.

Editing & documentation
----------------------
- Update [README.md](README.md) when you change developer-facing scripts or test-running instructions.
- Keep changes minimally invasive: prefer adding new numbered files rather than renaming existing ones.

If something is unclear
----------------------
- Ask the repository owner whether `_BR` and `_UR` denote environment variants or test categories before introducing new variant suffixes.
- If you need cross-platform support, propose a small PowerShell/Node wrapper and update `README.md` with usage examples.

Next steps (ask the user)
------------------------
- Review this guidance and tell me if you want me to (a) apply it as `.github/copilot-instructions.md`, (b) include more examples from specific tests, or (c) merge content from any existing agent guidance you maintain elsewhere.
