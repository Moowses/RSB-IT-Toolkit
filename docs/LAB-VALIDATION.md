# Manual laboratory validation matrix

This matrix is a release gate. Record date, image/build, operator, log transaction ID, expected result, and actual result for every row before calling any release production-ready.

| Lab | Required exercises |
|---|---|
| Windows 10 x64 clean local account | Preflight; apply baseline; verify profile/SID retained; time restrictions; undo; repeat apply for idempotency |
| Windows 11 x64 clean local account | Same as Windows 10 plus product-name/build display check |
| 32-bit PowerShell launcher on x64 | Confirm native 64-bit relaunch and LocalAccounts availability |
| Failure injection | Policy failure after backup; final verification failure; confirm rollback and separate outcome reporting |
| Unsupported identities | Domain, Entra/Microsoft Account, multiple session, no Explorer/session — confirm no changes |

Attach sanitized logs and screenshots to the release-validation issue. No completed rows are present yet.
