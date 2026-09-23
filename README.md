# Multicluster Agentic OLS demo

A retryable hub-and-spoke setup for demonstrating OLS-3950 and OLS-3951.

## Setup

```text
./setup.sh                 install the locked controller image set
./setup.sh --build-images  one-off image-build override
manifests/<stage>/install.sh
manifests/<stage>/uninstall.sh
./teardown.sh
```

The three rebuilt controller images are pushed to the public `quay.io/kgordeev`
namespace with the convenience tag `latest`. Stage `00-images` immediately
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
For the demo flow, stage 07 creates an always-firing critical PrometheusRule
on the spoke, then waits for hub AAA to create the target-spoke run:

```bash
manifests/07-demo-incident/trigger.sh
manifests/07-demo-incident/check.sh
```

The check command prints the generated AgenticRun name. Approve Analysis and
then Execution in the hub console when ready. Run
`manifests/07-demo-incident/resolve.sh` to delete the PrometheusRule and clear
the alert. Stage 07 retains the run for inspection until its uninstall script
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

Always remove the spoke registration while the hub controller is running. The
hub controller must complete SpokeCluster finalizers before the hub stack is
removed.
