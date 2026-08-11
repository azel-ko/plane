#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
kubectl_cmd=(kubectl)

if [[ -n "${KUBECONFIG:-}" ]]; then
  kubectl_cmd+=(--kubeconfig "${KUBECONFIG}")
fi

"${kubectl_cmd[@]}" apply --filename "${script_dir}/namespace.yaml"
"${script_dir}/bootstrap-secrets.sh"
"${kubectl_cmd[@]}" apply --filename "${script_dir}/plane-helmchart.yaml"
"${kubectl_cmd[@]}" apply --filename "${script_dir}/plane-ingress.yaml"
"${kubectl_cmd[@]}" apply --filename "${script_dir}/mcp-server.yaml"

echo "Plane installation submitted to the k3s Helm controller."
echo "Plane:     http://work.local"
echo "Plane MCP: http://mcp.work.local/http/api-key/mcp"
