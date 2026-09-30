# RSB IT Toolkit

An engineering-preview WPF utility for safe, reversible branch-PC maintenance and local-account hardening. It uses modular PowerShell, Pester, state backups, transaction rollback, structured logs, and a release bootstrap—not a mixed BAT/PowerShell payload.

> **Not production-ready.** Do not deploy broadly until the Windows 10 and Windows 11 lab matrix passes.

## Supported environment

- Windows 10 or Windows 11 x64
- Windows PowerShell 5.1, launched elevated (a 32-bit launcher is redirected to native 64-bit PowerShell)
- One active local employee session

Domain, Microsoft Account, and Entra identities are deliberately blocked in v1. The tool keeps the existing employee profile; it does not replace or migrate accounts.

## Launch

Development checkout:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\start.ps1
```

After a signed, tagged public release exists, the intended bootstrap command is:

```powershell
irm https://raw.githubusercontent.com/Moowses/rsb-it-toolkit/main/bootstrap.ps1 | iex
```

The bootstrap obtains a named release asset and its SHA256 manifest, verifies the digest, then starts the extracted ordinary PowerShell files. It never contains a password or token.

## Safety and recovery

- Run **Preflight Only** before applying the baseline.
- The baseline creates and verifies `RSB IT Admin`, verifies the employee is in Users, exports policy/state, applies policies, then removes employee admin rights last.
- If a critical post-change verification fails, rollback is attempted automatically. Use **Undo Branch Security Baseline** for a deliberate recovery.
- Logs: `%ProgramData%\RSB-IT\Logs`; state/policy backups: `%ProgramData%\RSB-IT\State`.

For an issue, attach the matching JSON summary and text log after removing any unrelated personal information. Never send passwords. Screenshots are intentionally placeholders until lab validation supplies verified captures.

## Development

```powershell
Invoke-Pester .\tests
Invoke-ScriptAnalyzer -Path . -Recurse
```

See `SPEC.md`, `docs/TRANSACTION-MODEL.md`, and `docs/LAB-VALIDATION.md`.
