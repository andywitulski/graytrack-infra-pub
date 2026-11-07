# ATP-008: Detection and logging

**Objective:** Prove events reach the SIEM and trigger the right rules.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | Regression samples | Run `services.yml --limit wazuh_manager` | Completes: all logtest samples hit their rule |
| T2 | All agents active | `ssh ansible@siem01 sudo /var/ossec/bin/agent_control -l` | Every host Active |
| T3 | Failed SSH detected | From a test client: `ssh nosuchuser@git01` | Rule 5710 with host and source |
| T4 | Identity events | Wrong password at `auth`, five times | 100203, then 100204 |
| T5 | Automation account from elsewhere | Log in as `ansible` from a non-controller source, using a test certificate | Rule 100402 at level 10 |
| T6 | Tamper alert | On a VM: `sudo touch /etc/audit/rules.d/test.rules`, then remove it | Rule 100434 at level 10 |
| T7 | Log survival | Generate an event, then delete the local log on a test host | Event remains in the SIEM |

Also confirm that vulnerability detection lists each agent, and that a failed backup raises an alert by cancelling a test job.

**Sample evidence:** [first alert](../evidence/sample-wazuh-first-alert.txt).
