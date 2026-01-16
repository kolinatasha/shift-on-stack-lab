# Shift-on-Stack Lab

A reproducible lab environment for deploying OpenShift on OpenStack using MicroStack.

## Goals

- Automate OpenStack environment setup using MicroStack
- Provide a reproducible OpenShift-on-OpenStack installation workflow
- Track installation metrics and failure patterns
- Document troubleshooting procedures and known issues

## Prerequisites

- Ubuntu 20.04+ (recommended for MicroStack)
- 16GB+ RAM, 4+ CPU cores, 100GB+ disk space
- Sudo/root access
- Internet connectivity
- OpenShift pull secret from [cloud.redhat.com](https://cloud.redhat.com/openshift/install/pull-secret)

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/kolinatasha/shift-on-stack-lab.git
cd shift-on-stack-lab

# 2. Bootstrap dependencies
make bootstrap

# 3. Bring up OpenStack environment
make openstack-up

# 4. Validate OpenStack setup
make validate

# 5. Install OpenShift (or run harness)
make install

# 6. Generate metrics report
make report

# 7. Cleanup
make destroy
make openstack-down
```

## Expected Runtime

- OpenStack setup: 15-30 minutes (first run)
- OpenStack validation: 2-5 minutes
- OpenShift install: 45-90 minutes (full install) or 10-15 minutes (harness validation)
- Cleanup: 5-10 minutes

## Known Limitations

- MicroStack requires Ubuntu (snap-based installation)
- Full OpenShift install requires significant local resources
- Some failure scenarios may require manual intervention
- Network configuration is simplified for lab purposes
- DNS resolution uses simplified setup (not production-grade)

## Project Structure

```
.
├── Makefile              # Main automation targets
├── hack/                 # Automation scripts
│   ├── openstack_up.sh
│   ├── openstack_down.sh
│   ├── validate_openstack.sh
│   ├── install_openshift.sh
│   ├── destroy_cluster.sh
│   └── report.sh
├── docs/                 # Documentation
│   ├── RUNBOOK.md
│   ├── TROUBLESHOOTING.md
│   ├── FAILURE-MATRIX.md
│   └── KNOWN-ISSUES.md
├── artifacts/            # Generated outputs
│   ├── openstack_env.json
│   ├── metrics.json
│   ├── logs/
│   └── report.md
└── CONTRIBUTING.md
```

## Documentation

- [Runbook](docs/RUNBOOK.md) - Step-by-step operational procedures
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Failure Matrix](docs/FAILURE-MATRIX.md) - Known failure scenarios and reproduction
- [Known Issues](docs/KNOWN-ISSUES.md) - Tracked issues and workarounds

## Metrics Tracked

- Install success rate
- Mean/median time to install
- Failure signatures and frequency
- Rollback success rate

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT