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
