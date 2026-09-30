# RSB IT Toolkit contributor guide

This repository manages local Windows security settings. Make changes small, test them with Pester, and never persist a password, secret, or decrypted SecureString.

## Safety rules

- Target Windows PowerShell 5.1 and Windows 10/11 x64. Relaunch native 64-bit PowerShell before importing `Microsoft.PowerShell.LocalAccounts`.
- Treat state backup creation and preflight as prerequisites to every mutating security action.
- Resolve local built-in groups by SID, never by their English display names.
- Never use `HKCU` for employee policy while elevated. Target `HKEY_USERS\\<SID>` or temporarily load only that user's `NTUSER.DAT`.
- Do not remove a user's Administrators membership until the recovery administrator, Users membership, policy backup, and policy verification have all succeeded.
- A failed transaction must attempt rollback and record the deployment and rollback outcomes independently.

Run `Invoke-Pester ./tests` and `Invoke-ScriptAnalyzer -Path . -Recurse` before opening a pull request.
