# Multicluster Agentic OLS demo

A retryable hub-and-spoke setup for demonstrating OLS-3950 and OLS-3951.

## Setup

```text
./setup.sh                                  install stages 01-05 from locked images
./setup.sh --core                           install only stages 01-04
./setup.sh --core --build-images            rebuild and lock images first
manifests/<stage>/install.sh                rerun a failed stage after diagnosis
./teardown.sh --confirm-namespace-wipe     remove all stages (including incident)
```

The three rebuilt controller images are pushed to the configured image registry
with the convenience tag `latest`. Stage `00-images` immediately
resolves those tags to immutable digests in the gitignored
`.demo/image-lock.env` file. All cluster stages consume the digest lock, never
`latest`. Stage 00 uses the local OpenShift pull secret for Red Hat base-image
pulls and requires an active interactive Quay login before pushing.

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

Copy `.env.example` to `.env`. Keep kubeconfig paths and the OpenAI key only in
that untracked file. Set `WITH_IMAGES=true` in `.env` when setup should rebuild
all three controller images before installation. `openshift-lightspeed` and the
single registered spoke name `spoke` are fixed demo resource names.

## Safety

Setup with `--core` still deploys the hub-owned multicluster adapter in stage
03; stage 04 waits for its rollout after registration. It does not configure
Alertmanager polling or create the incident. Existing adapter configuration
from an earlier full setup is not reset by `--core`; use a fresh environment.

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
