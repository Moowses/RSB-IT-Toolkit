# RSB IT Toolkit

RSB IT Toolkit is an engineering-preview Windows utility for safe, reversible branch-PC maintenance and local-account hardening. It uses modular PowerShell, state backups, transaction rollback, structured logs, and a release bootstrap—not a mixed BAT/PowerShell payload.

> **Not production-ready.** Do not use this on a live branch PC until the Windows 10 and Windows 11 lab matrix passes and an IT lead approves a tagged release.

## Supported environment

- Windows 10 or Windows 11 x64
- Windows PowerShell 5.1, launched elevated (a 32-bit launcher is redirected to native 64-bit PowerShell)
- One active local employee session

Domain, Microsoft Account, and Entra identities are deliberately blocked in v1. The tool keeps the existing employee profile; it does not replace or migrate accounts.

## Technician runbook

### Before you begin

1. Work from an elevated **Windows PowerShell** session on a Windows 10/11 x64 device.
2. Confirm that exactly one employee is actively signed in and their account is a **local Windows account**. Stop if it is a domain, Microsoft Account, or Entra account.
3. Do not sign the employee out, rename the computer/account, or disconnect remote support while the baseline runs.
4. Know where to obtain the recovery-account password from the approved IT password process. Do not put that password in a ticket, chat, command, or document.

### Preview release: launch from a trusted checkout

Until a signed/tagged release exists, branch IT must use a trusted checkout prepared by IT—not the online bootstrap command:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\start.ps1
```

In the GUI, select **Preflight Only** first. Review the employee identity, SID, enabled status, Users membership, Administrators membership, and RSB IT Admin status. If any result is failed or unexpected, stop and collect logs; do not click Apply.

### Apply the Branch Security Baseline

1. Click **Apply Branch Security Baseline** only after a successful preflight.
2. Enter and confirm the recovery password when prompted. It is handled as a SecureString and is not saved by the toolkit.
3. Wait for a final `SUCCESS` or `FAILED` result. Do not close the window during the operation.
4. On `FAILED`, read the rollback status. A `RolledBack` result means the captured account/policy state was restored; `RollbackFailed` requires escalation to IT support before anyone signs out or restarts the PC.

### Recovery, logs, and escalation

- Use **Undo Branch Security Baseline** only when directed by IT or to recover a known baseline transaction.
- Logs: `%ProgramData%\RSB-IT\Logs`
- State and policy backups: `%ProgramData%\RSB-IT\State`
- For an incident, provide the transaction ID, text log, JSON state summary, Windows version/build, and what action was selected. Remove unrelated personal information. **Never send passwords.**

### Future tagged releases

After IT approves a signed, tagged public release, the intended bootstrap command is:

```powershell
irm https://raw.githubusercontent.com/Moowses/rsb-it-toolkit/main/bootstrap.ps1 | iex
```

The bootstrap obtains a named release asset and its SHA256 manifest, verifies the digest, then starts the extracted ordinary PowerShell files. It never contains a password or token.

### Engineering-preview lab channel

Only for controlled Windows 10/11 lab validation—not branch deployment—the current published preview can be launched with:

```powershell
$script = irm https://raw.githubusercontent.com/Moowses/rsb-it-toolkit/main/bootstrap.ps1
& ([scriptblock]::Create($script)) -Channel dev
```

The `dev` channel resolves the newest published GitHub pre-release, verifies its SHA256 manifest, and records the release version in its normal output. The ordinary one-line bootstrap remains reserved for an approved stable release.

## Safety model

- Run **Preflight Only** before applying the baseline.
- The baseline creates and verifies `RSB IT Admin`, verifies the employee is in Users, exports policy/state, applies policies, then removes employee admin rights last.
- If a critical post-change verification fails, rollback is attempted automatically. Its result is reported separately from the deployment failure.
- The optional Control Panel/Settings restriction targets the detected employee SID only, never the elevated IT account.

## Known limitations

- v1 intentionally stops for multiple active sessions, no safe active employee session, domain accounts, Microsoft Accounts, and Entra identities.
- A remote-access tool such as UltraViewer is not a hard dependency; confirm an approved support path before a restart.
- The release workflow builds a SHA256-verified ZIP. Authenticode signing must be configured with an organization-owned certificate before a production release.

## Development

```powershell
Invoke-Pester .\tests
Invoke-ScriptAnalyzer -Path . -Recurse
```

See `SPEC.md`, `docs/TRANSACTION-MODEL.md`, and `docs/LAB-VALIDATION.md`.
