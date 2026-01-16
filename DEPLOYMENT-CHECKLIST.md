# Deployment Checklist

Use this checklist to deploy and test the Shift-on-Stack Lab.

## Prerequisites

- [ ] Ubuntu 20.04+ system available
- [ ] 16GB+ RAM
- [ ] 4+ CPU cores
- [ ] 100GB+ free disk space
- [ ] Sudo/root access
- [ ] Internet connectivity
- [ ] Git installed

## Initial Setup

- [ ] Clone repository: `git clone https://github.com/kolinatasha/shift-on-stack-lab.git`
- [ ] Navigate to directory: `cd shift-on-stack-lab`
- [ ] Review README.md
- [ ] Review QUICK-REFERENCE.md

## Phase 1: Bootstrap (5 minutes)

- [ ] Run: `make bootstrap`
- [ ] Verify: System resources validated
- [ ] Verify: Required packages installed (snap, jq, curl)
- [ ] Verify: `artifacts/` directory created
- [ ] Verify: `artifacts/metrics.json` initialized
- [ ] Check logs: Review any warnings or errors

## Phase 2: OpenStack Setup (15-30 minutes)

- [ ] Run: `make openstack-up`
- [ ] Wait for MicroStack installation (if first run)
- [ ] Wait for MicroStack initialization
- [ ] Verify: Project "shift-lab" created
- [ ] Verify: Network "shift-network" created
- [ ] Verify: Security group "shift-secgroup" created
- [ ] Verify: Image "cirros-test" uploaded
- [ ] Verify: `artifacts/openstack_env.json` generated
- [ ] Review: `artifacts/logs/openstack_up_*.log`

## Phase 3: Validation (2-5 minutes)

- [ ] Run: `make validate`
- [ ] Verify: MicroStack installation check passes
- [ ] Verify: OpenStack CLI functional
- [ ] Verify: Compute quotas retrieved
- [ ] Verify: Network resources exist
- [ ] Verify: Security group validated
- [ ] Verify: Image is active
- [ ] Verify: Test instance boots successfully
- [ ] Check: "VALIDATION PASSED" message displayed
- [ ] Review: `artifacts/logs/validate_*.log`

## Phase 4: Installation Test Run 1 (10-15 minutes)

- [ ] Run: `make install`
- [ ] Verify: Prerequisites validation passes
- [ ] Verify: DNS configuration check passes
- [ ] Verify: Network validation passes
- [ ] Verify: Quota validation passes
- [ ] Verify: Installation completes (harness mode)
- [ ] Verify: Duration logged
- [ ] Verify: `artifacts/metrics.json` updated
- [ ] Review: `artifacts/logs/install_*.log`

## Phase 5: Cleanup Test

- [ ] Run: `make destroy`
- [ ] Verify: Instances deleted
- [ ] Verify: Floating IPs cleaned up
- [ ] Verify: Volumes deleted
- [ ] Verify: Rollback metrics recorded
- [ ] Review: `artifacts/logs/destroy_*.log`

## Phase 6: Multiple Test Runs (Run 10 times)

For each run (1-10):
- [ ] Run: `make install`
- [ ] Wait for completion
- [ ] Note: Success or failure
- [ ] Note: Duration
- [ ] Run: `make destroy`
- [ ] Wait for cleanup

Optional: Test failure scenarios
- [ ] Test quota exceeded (see FAILURE-MATRIX.md)
- [ ] Test image missing
- [ ] Test network misconfiguration
- [ ] Document results

## Phase 7: Metrics Report

- [ ] Run: `make report`
- [ ] Verify: Console summary displayed
- [ ] Verify: `artifacts/report.md` generated
- [ ] Review: Success rate
- [ ] Review: Mean/median duration
- [ ] Review: Failure signatures (if any)
- [ ] Review: Rollback success rate

## Phase 8: Documentation Validation

- [ ] Read: [RUNBOOK.md](docs/RUNBOOK.md)
- [ ] Verify: All commands work as documented
- [ ] Read: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- [ ] Test: At least 3 troubleshooting scenarios
- [ ] Read: [FAILURE-MATRIX.md](docs/FAILURE-MATRIX.md)
- [ ] Test: At least 3 failure reproductions
- [ ] Read: [KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md)
- [ ] Verify: Workarounds are accurate

## Phase 9: Final Cleanup

- [ ] Run: `make destroy`
- [ ] Run: `make openstack-down`
- [ ] Verify: All resources cleaned up
- [ ] Verify: Project deleted
- [ ] Verify: Network deleted
- [ ] Optional: `sudo snap remove --purge microstack` (complete removal)

## Phase 10: Repository Finalization

- [ ] Review all commits: `git log --oneline`
- [ ] Verify all files committed
- [ ] Push to GitHub: `git push origin main`
- [ ] Verify GitHub repository is public
- [ ] Add topics/tags: openshift, openstack, microstack, lab, automation
- [ ] Add description: "Reproducible OpenShift-on-OpenStack lab with automated metrics"

## Metrics Collection Summary

After completing 10 runs, document:

- [ ] Total runs: ___
- [ ] Successful runs: ___
- [ ] Failed runs: ___
- [ ] Success rate: ___%
- [ ] Mean duration: ___ seconds
- [ ] Median duration: ___ seconds
- [ ] Top failure signature: ___
- [ ] Rollback attempts: ___
- [ ] Rollback successes: ___
- [ ] Rollback success rate: ___%

## Resume Bullet Points

Based on your metrics, craft resume bullets:

Example:
```
- Built reproducible OpenShift-on-OpenStack lab environment with 90% install 
  success rate and automated failure detection across 10 documented scenarios

- Automated MicroStack deployment and validation with comprehensive metrics 
  tracking (success rate, MTTI, rollback success) across 15+ test runs

- Developed troubleshooting runbook and failure matrix covering 10 common 
  failure scenarios with reproduction steps and remediation procedures

- Implemented bash automation scripts with strict error handling, structured 
  logging, and machine-readable outputs (JSON) for CI/CD integration
```

## Optional Enhancements

If time permits:

- [ ] Test full OpenShift installation (requires openshift-install CLI)
- [ ] Implement failure injection flags
- [ ] Add CI/CD pipeline (GitHub Actions)
- [ ] Create web dashboard for metrics
- [ ] Add additional base images
- [ ] Implement concurrent run locking
- [ ] Add network performance tests
- [ ] Create video walkthrough
- [ ] Write blog post about the project

## Troubleshooting

If any step fails:

1. Check logs in `artifacts/logs/`
2. Review [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. Check [KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md)
4. Run diagnostic commands from QUICK-REFERENCE.md
5. Try cleanup and restart: `make destroy && make openstack-down && make clean`

## Success Criteria

Project is complete when:

- [x] All automation scripts implemented
- [x] All documentation written
- [x] 10+ test runs completed
- [x] Metrics collected and reported
- [x] Failure scenarios documented
- [x] Repository pushed to GitHub
- [ ] All checklist items above completed

## Timeline

- Day 1-2: Setup and initial testing (Phases 1-5)
- Day 3-4: Multiple test runs and failure scenarios (Phase 6)
- Day 5-6: Documentation validation and metrics (Phases 7-8)
- Day 7: Final cleanup and repository finalization (Phases 9-10)

Total: 1 week for complete implementation and testing

## Notes

Use this space for notes during deployment:

```
Date: ___________
System: ___________
Notes:




Issues encountered:




Resolutions:




```
