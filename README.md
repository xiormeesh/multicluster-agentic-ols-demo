# Multicluster Agentic OLS demo

A retryable hub-and-spoke setup for demonstrating OLS-3950 and OLS-3951.

## Recommended setup: core hub and spoke

Copy `.env.example` to the gitignored `.env`, set both kubeconfig paths and
supply `ONLY_OLS_OPENAI_API_KEY` through the environment or `.env`. Log in to
Quay with an account that can push to the configured image repository using
`podman login quay.io` before building images. From the repo root, run:

```bash
./setup.sh --core --build-images
```

This runs optional image stage 00, then stages 01–04: Agentic OLS, a real LLM
and Agent, lightspeed-hub, and spoke registration. Stage 00 builds and pushes
three controller images tagged `latest`, then records immutable digests and
source commits in gitignored `.demo/image-lock.env`; deployments use only the
digests. Stage 00 uses the local OpenShift pull secret for Red Hat base-image
pulls. If it fails, setup stops before cluster installation; inspect the error
instead of proceeding with an old or partial image lock.

To reuse an existing complete image lock and cached source checkouts, run
`./setup.sh --core` instead. Rerunning setup or a failed
`manifests/<stage>/install.sh` retries installation after diagnosing the error.
Core mode skips stage 05 Alertmanager configuration, but stage 03 still creates
the hub-owned adapter with an empty receiver allowlist, and stage 04 waits for
it to become ready.

For the **full alert demo**, run `./setup.sh` (stages 01–05) or
`./setup.sh --build-images` to rebuild first. Stage 05 enables the `critical`
receiver and may create AgenticRuns for existing matching alerts. Setup never
runs stage 06; the demo incident is always triggered separately. To remove
either setup, run `./teardown.sh --confirm-namespace-wipe` after reading the
[destructive scope](#safety) below.

## MCE environment (optional)

By default the demo registers the spoke with a secret-mode `SpokeCluster`
(direct admin kubeconfig). Pass `--mce` to also set up the MultiCluster Engine
prerequisite needed for MCE-based spoke access development:

```bash
./setup.sh --core --mce
```

This runs the `00-mce` stage first (before the OLS stages). Every step is
idempotent and detects existing resources before creating them, so a failed run
can be rerun to resume:

- installs the MCE operator via OLM **only if it is not already present** (if the
  MCE CRD exists it leaves operator resources untouched, so a manual install is
  never disturbed and no duplicate OperatorGroup is created)
- ensures a `MultiClusterEngine` instance exists, creating the recommended
  minimal `engine` instance only if none is present
- imports the spoke as a `ManagedCluster` via `auto-import-secret`
- ensures the `cluster-proxy` add-on, creating it only if MCE has not already
  auto-deployed it via a global placement

`cluster-proxy` is the konnectivity reverse tunnel the hub uses to reach the
spoke kube-API; `managed-serviceaccount` is intentionally not enabled because
the MCE credential path uses hub service-account tokens, not MSA tokens.

### cluster-proxy and local DNS

The `ManagedCluster` import is the part this stage owns, and it completes on
its own. The `cluster-proxy` add-on additionally needs the spoke agent to open
a konnectivity tunnel to the hub proxy endpoint
(`cluster-proxy-anp.apps.<hub>`). In local clusters without cross-cluster apps
DNS the spoke cannot resolve that hostname, so the add-on never reports
`Available` (its health lease is never written). This is the same local-DNS
limitation the `SPOKE_ROUTER_IP` note below works around in the other
direction.

The stage therefore treats cluster-proxy readiness as a **warning, not a
failure** (wait bounded by `CLUSTER_PROXY_TIMEOUT`, default `120s`). It does not
block OLS-3954 development, which is tested without a live tunnel. Live
MCE-mode spoke access requires making the hub apps hostname resolve from inside
the spoke, which is an environment/DNS task, not part of these scripts.

`--mce` is additive: it does **not** change stage 04, which still registers the
secret-mode `SpokeCluster`. Switching that to `credentialSource: mce` is
separate product work and is layered on once the corresponding code exists.

Set `MCE_CHANNEL` in local `.env` to override the operator channel (default
`stable-2.11`).

Teardown with `--mce` is a **partial** teardown: it detaches the spoke
(`./teardown.sh --confirm-namespace-wipe --mce`) but deliberately leaves the
operator and `MultiClusterEngine` instance installed, since reinstalling them
is slow and they are shared environment infra. Remove them manually for a full
MCE uninstall.

## Spoke Alertmanager DNS

AAA normally uses pod DNS to reach the spoke Alertmanager route. Set
`SPOKE_ROUTER_IP` in local `.env` only when that route cannot resolve from the
hub AAA pod. Stage 05 then adds a pod host alias for the fixed spoke route;
when the variable is absent, it leaves pod DNS unchanged.

## Live alert-driven incident

The hub-local and direct target-spoke smoke tests live with their corresponding setup stages.
For the demo flow, stage 06 creates an always-firing critical PrometheusRule
on the spoke, then waits for hub AAA to create the target-spoke run:

```bash
manifests/06-demo-incident/trigger.sh
manifests/06-demo-incident/check.sh
```

The check command prints the generated AgenticRun name. Approve Analysis and
then Execution in the hub console when ready. Run
`manifests/06-demo-incident/resolve.sh` to delete the PrometheusRule and clear
the alert. Stage 06 retains the run for inspection until its uninstall script
is run.

## Image sources

Stage `00-images` maintains its own gitignored source cache under
`.demo/sources`, so it never modifies sibling development checkouts. By default
it builds `main` from each upstream repository. Set these optional local values
when a controller must come from a PR branch:

```text
AGENTIC_OPERATOR_SOURCE_URL
AGENTIC_OPERATOR_SOURCE_REF
HUB_SOURCE_URL
HUB_SOURCE_REF
AAA_SOURCE_URL
AAA_SOURCE_REF
```

Use a fork URL plus its branch name for a PR, while leaving the other
controllers on upstream `main`. The Agentic OLS quickstart retains its
Konflux-backed sandbox image because the demo rebuilds only the three
controllers.

## Local configuration

Keep `.env`, kubeconfig paths and credentials untracked. Set
`WITH_IMAGES=true` in `.env` if every setup invocation should rebuild all
three controller images; `--build-images` rebuilds for just one invocation.
`openshift-lightspeed` and the registered spoke name `spoke` are fixed demo
resource names.

## Safety

Stage 01 quickstart installs `lightspeed-agentic-alerts-adapter`, the
single-cluster adapter, then scales it to 0 so it cannot compete with the
hub-owned `lightspeed-hub-alerts-adapter`. Stage 03 creates the hub-owned
multicluster adapter even with `--core`; stage 04 waits for its rollout after
registration. Core setup does not configure Alertmanager polling or create the
incident. Configuration from an earlier full setup is not reset by `--core`;
use a fresh environment.

Teardown always removes stage 06, then stages 05-01 in reverse order. It gives
controller cleanup 60 seconds, then bypasses *known* run/spoke finalizers only
in this explicitly confirmed disposable-cluster wipe. Unknown finalizers and
API/auth failures stop teardown. It removes the spoke managed namespace and
known hub/spoke cluster-scoped RBAC, then verifies namespace deletion. A forced
finalizer bypass can leave other external resources behind; inspect failures
before claiming the pair is clean.

**Destructive scope:** the cached Agentic OLS quickstart uninstall uses `--force`
and removes *all* AgenticRuns, approvals, results, Agents, providers and the
entire `openshift-lightspeed` namespace, not only demo-owned objects. Inventory
this shared namespace before confirming the wipe. Unrelated SpokeClusters
block teardown before any deletion. Repeating teardown is safe only after
checking the first failed stage and its cluster state; unexpected API errors
must not be ignored. No remote images or local image lock are deleted.

<!-- TODO: after OLS 2.0 merges classic and agentic OLS, migrate setup and
teardown to the new installation and cleanup protocols instead of quickstart. -->
