# Multicluster Agentic OLS demo

A retryable hub-and-spoke setup for demonstrating OLS-3950 and OLS-3951.

## Status

The lifecycle foundation is in place. The numbered installation stages are
added and validated one at a time. Do not run `setup.sh` until stages 01 through
05 are implemented.

## Intended workflow

```text
./setup.sh                 install a previously locked image set
./setup.sh --build-images  build controller images, lock digests, then install
manifests/<stage>/install.sh
manifests/<stage>/uninstall.sh
./teardown.sh
```

Image builds use a demo-owned gitignored source cache. Cluster installation
uses immutable image digests from the generated `.demo/image-lock.env` file.

## Configuration

Copy `.env.example` to `.env`. Keep kubeconfig paths and the OpenAI key only in
that untracked file. The three rebuilt controller images come from the generated
image lock; the Agentic OLS quickstart retains its Konflux-backed sandbox image.

## Safety

Always remove the spoke registration while the hub controller is running. The
hub controller must complete SpokeCluster finalizers before the hub stack is
removed.
