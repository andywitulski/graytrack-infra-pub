# ATP-010: Endpoint management

**Objective:** Prove enrollment, policy delivery and that only device paths are public.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | Console private | From outside: `curl -o /dev/null -w '%{http_code}' https://mdm.example.com/login` and `/api/v1/fleet/hosts` | 403 |
| T2 | Enrollment needs the secret | From outside: open `/enroll` with no secret | Page loads and reports an invalid secret |
| T3 | Policy delivered | Enroll a test device; check console OS settings; try to set a simple passcode | Both profiles Verified; weak passcode refused |
| T4 | Configuration drift corrected | Change a managed setting in the console; run `bin/fleet-gitops prod` | Setting is restored |
