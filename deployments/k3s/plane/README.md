# Plane on local k3s

This directory deploys Plane Community and the official Plane MCP Server on a
single-node k3s cluster.

## Components

- Plane CE Helm chart `1.6.2` / Plane `v1.4.1`
- PostgreSQL, Valkey, RabbitMQ, and MinIO with `local-path` persistence
- Traefik route at `http://work.local`
- Plane MCP Server `v0.2.11` at
  `http://mcp.work.local/http/api-key/mcp`

The Plane worker has a 3 GiB memory limit because Celery detects all 16 CPUs
on this node and exceeds the chart's 1 GiB default while starting its pool.

The bootstrap script generates runtime credentials directly in Kubernetes.
Credentials are not written to this repository.

## Deploy

Ensure `kubectl` points at the local k3s cluster, then run:

```sh
KUBECONFIG=/home/azel/.kube/config ./deployments/k3s/plane/deploy.sh
```

The k3s Helm Controller installs the official Plane chart, so a local Helm
binary is not required.

`plane-ingress.yaml` supplies the HTTP Traefik route because Plane chart 1.6.2
renders its native Traefik route on `websecure` even when certificate creation
is disabled.

Add the local names to `/etc/hosts`:

```text
10.168.2.11 work.local mcp.work.local
```

The `work.localhost` and `mcp.work.localhost` aliases remain available when
accessing the services directly from the k3s host.

## MCP client

After creating the first Plane workspace and a personal API key, connect an
MCP client to:

```text
http://mcp.work.local/http/api-key/mcp
```

Send the API key as a bearer token and the Plane workspace slug in the
`X-Workspace-Slug` header. The MCP server validates the key against the
cluster-internal Plane API and does not store it.

This local deployment is configured for the API-key MCP endpoint. OAuth needs
a Plane OAuth application registered for the MCP server before it can be used.
