# Multicluster Agentic OLS demo

Hub-and-spoke setup for OLS multicluster with MCE or secret-based credentials.

## Quick start

Copy `.env.example` to `.env`, set both kubeconfig paths and supply
`ONLY_OLS_OPENAI_API_KEY` through the environment or `.env`. Log in to Quay
before building images (`podman login quay.io`).

### Credential modes

| Mode | Flag | How it works |
|------|------|-------------|
| **Secret** | `--secret` | Admin kubeconfig Secret provided manually (stage 04) |
| **MCE** | `--mce` | Auto-discovers spokes via ManagedCluster CRs; stage 04 is skipped |

### Setup

```bash
# Full MCE demo (auto-discovery + alerts adapter)
./setup.sh --mce

# Full secret demo
./setup.sh --secret

# Core only (no alerts adapter config) — useful for e2e testing
./setup.sh --mce --core
./setup.sh --secret --core

# Rebuild all controller images first
./setup.sh --mce --build-images
```

### Teardown

```bash
# Secret mode
./teardown.sh

# MCE mode (also detaches spoke from MCE)
./teardown.sh --mce
```

## Stages

| Stage | Name | Secret | MCE |
|-------|------|--------|-----|
| 00-images | Build controller images | optional | optional |
| 00-mce | MCE operator + spoke import | skipped | ✓ |
| 01 | Agentic OLS (operator, OTEL, console) | ✓ | ✓ |
| 02 | LLM provider + agent | ✓ | ✓ |
| 03 | lightspeed-hub + HubConfig | secret mode | mce mode |
| 04 | Spoke registration (manual SpokeCluster) | ✓ | skipped |
| 05 | Alerts adapter config | full only | full only |
| 06 | Demo incident | manual | manual |

## MCE mode details

Stage `00-mce` is idempotent — it detects existing MCE operator, MCE instance,
and imported spoke, skipping what's already present. It imports the spoke via
`auto-import-secret` using the `SPOKE_KUBECONFIG` from `.env`.

In MCE mode, stage 03 deploys the hub controller which automatically:
- discovers the spoke from MCE's ManagedCluster CR
- creates a ManagedServiceAccount (per-spoke token, MCE-rotated)
- pushes RBAC to the spoke via ManifestWork (work-manager applies it)
- creates the SpokeCluster and standing kubeconfig

No manual spoke-side setup is needed.

Set `MCE_CHANNEL` in `.env` to override the operator channel (default
`stable-2.11`).

## Demo incident

```bash
manifests/06-demo-incident/trigger.sh   # create always-firing critical alert
manifests/06-demo-incident/check.sh     # verify AgenticRun was created
manifests/06-demo-incident/resolve.sh   # delete the PrometheusRule
```

## Image sources

Stage `00-images` builds from a gitignored source cache (`.demo/sources/`).
Override for PR branches:

```text
AGENTIC_OPERATOR_SOURCE_URL / AGENTIC_OPERATOR_SOURCE_REF
HUB_SOURCE_URL / HUB_SOURCE_REF
AAA_SOURCE_URL / AAA_SOURCE_REF
```

## Safety

Teardown removes stages in reverse order. In MCE mode it skips stage 04
(discovery handles spoke lifecycle). It gives controller cleanup 60s, then
bypasses known finalizers. The quickstart uninstall deletes the entire
`openshift-lightspeed` namespace — inventory shared resources before running.
