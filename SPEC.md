# RSB IT Toolkit specification

## Status

**Engineering preview — not production-ready.** Automated tests and documented Windows 10 and Windows 11 lab runs are release gates. See `docs/LAB-VALIDATION.md`.

## Purpose

RSB IT Toolkit is an elevated Windows IT utility for branch technicians. It preserves the existing employee's local profile and account while applying a reversible standard-user security baseline. It is an original PowerShell/WPF implementation; it does not include or derive from WinUtil source code.

## Supported scope

| Item | v1 support |
|---|---|
| Windows | Windows 10/11, x64, Windows PowerShell 5.1 |
| Identities | One active local employee account |
| Unsupported stop states | Multiple active sessions; domain, Entra, or Microsoft accounts; no safe employee identity |
| Execution | Elevated native 64-bit PowerShell |

## Baseline contract

The baseline creates or repairs `RSB IT Admin`, enabled and verified in local Administrators; ensures the detected employee is enabled and verified in built-in Users; exports policy and writes state; configures secure-desktop credential UAC and time/time-zone user rights for Administrators plus LOCAL SERVICE; and only then removes employee Administrators membership. Existing SID, profile, desktop, files, and application settings remain intact.

The optional Control Panel restriction is independent, targets only `HKU\\<employee SID>`, and is reversible. Passwords are accepted only as SecureStrings and are never logged, serialized, or placed in configuration.

## Failure model

Preflight makes no changes. After state backup, changes execute as named transaction steps. A critical failure triggers rollback of completed steps in reverse order. The final result always reports both primary and rollback status. Operations are designed to be idempotent.

## Release gates

1. Pester regression suite and ScriptAnalyzer pass.
2. A technician completes the matrix in `docs/LAB-VALIDATION.md` on clean Windows 10 and 11 labs.
3. Security review confirms no secret persistence and a successful undo path.
4. Only then may a tagged GitHub release be labeled production-ready.
