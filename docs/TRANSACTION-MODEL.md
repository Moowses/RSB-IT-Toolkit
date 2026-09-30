# State and transaction model

Each mutating run has a GUID transaction ID and a JSON state document under `%ProgramData%\RSB-IT\State`. The state is atomically written before the first change and after every completed step. It contains account SID/membership facts, a pointer to the exported security-policy INF, the original employee Control Panel value, transaction steps, and status—but never a password.

| State | Meaning | Allowed next state |
|---|---|---|
| `Preflight` | Read-only validation | `BackedUp`, `Failed` |
| `BackedUp` | State and policy export persisted | `Applying`, `Failed` |
| `Applying` | Named steps execute | `Verified`, `RollingBack`, `Failed` |
| `Verified` | Final checks passed | `Succeeded` |
| `RollingBack` | Completed steps reverse in LIFO order | `RolledBack`, `RollbackFailed` |

Rollback restores the employee’s prior built-in Users/Administrators membership, imports the saved security policy, and restores/removes the employee-only registry value according to captured presence/value. A rollback failure is not concealed by the initial failure; both appear in logs and the JSON summary.

`state/schema.json` is intentionally descriptive rather than a runtime dependency so Windows PowerShell 5.1 remains supported.
