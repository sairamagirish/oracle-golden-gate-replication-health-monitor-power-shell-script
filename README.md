# oracle-golden-gate-replication-health-monitor-power-shell-script
Production-ready Oracle Golden Gate health validation framework that performs post operational health checks using process status, lag analysis, RBA movement, trail sequence progression, and replication activity validation to ensure data is actively flowing across Golden Gate environments.

## Overview

This project provides an automated Oracle Golden Gate health validation solution designed for post verification, maintenance activities, outage recovery, and routine operational monitoring using power-shell script.

Unlike traditional health checks that rely solely on process status, this tool validates actual replication activity by analyzing multiple Golden Gate metrics over time.

The script captures two snapshots of Golden Gate process state and compares critical indicators such as process status, lag trends, RBA movement, sequence progression, and replication statistics to determine whether processes are actively processing data.

## Key Features

- Validates EXTRACT, PUMP, and REPLICAT processes.
- Detects stagnant processes reporting RUNNING status.
- Performs lag trend analysis.
- Verifies RBA movement between checkpoints.
- Monitors trail file sequence progression.
- Uses STATS validation to confirm data flow.
- Differentiates idle systems from stuck processes.
- Generates detailed health logs.
- Provides OK, WARN, and FAIL classifications.

## Use Cases

- Oracle Golden Gate post validation
- Outage recovery verification
- Maintenance window checks
- Production health monitoring
- Replication troubleshooting

## Key Benefits

- Ensures Golden-Gate processes are actively processing data, not just reporting RUNNING status.
- Automates post-restart and post-maintenance health validation.
- Verifies replication progress using lag trends, RBA movement, and trail file progression.
- Detects hidden replication bottlenecks and stalled processes.
- Minimizes the risk of undetected replication failures.
- Provides standardized health checks across multiple Golden Gate environments.
- Accelerates operational validation and troubleshooting activities.
- Reduces manual monitoring effort through automated analysis and reporting.
- Enhances reliability of replication operations in production environments.
- Supports proactive identification of performance and data flow issues.

Expected Output :
- [OK] Processing normally
- [WARN] Lag increasing
- [FAIL] Not RUNNING
- ✅ OGG HEALTHY
- ❌ OGG ISSUES DETECTED

## Technologies

- Oracle Golden Gate
- PowerShell
- GGSCI
- Replication Monitoring
- Operational Automation

## Disclaimer

This project is based on operational experience with Oracle Golden Gate environments. All environment-specific information has been removed or generalized. Review and test thoroughly before use in production.

## Author

Sai Rama Girish Kuppili
Database Engineer
