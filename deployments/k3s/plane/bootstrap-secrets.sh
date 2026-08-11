#!/usr/bin/env bash

set -euo pipefail

namespace="plane"
release="plane-app"
kubectl_cmd=(kubectl)

if [[ -n "${KUBECONFIG:-}" ]]; then
  kubectl_cmd+=(--kubeconfig "${KUBECONFIG}")
fi

secret_exists() {
  "${kubectl_cmd[@]}" --namespace "${namespace}" get secret "$1" >/dev/null 2>&1
}

read_secret() {
  "${kubectl_cmd[@]}" --namespace "${namespace}" get secret "$1" \
    --output "go-template={{ index .data \"$2\" }}" | base64 --decode
}

if ! secret_exists plane-runtime-postgres; then
  postgres_password="$(openssl rand -hex 24)"
  "${kubectl_cmd[@]}" --namespace "${namespace}" create secret generic plane-runtime-postgres \
    --from-literal=POSTGRES_USER=plane \
    --from-literal=POSTGRES_DB=plane \
    --from-literal="POSTGRES_PASSWORD=${postgres_password}"
fi

if ! secret_exists plane-runtime-rabbitmq; then
  rabbitmq_password="$(openssl rand -hex 24)"
  "${kubectl_cmd[@]}" --namespace "${namespace}" create secret generic plane-runtime-rabbitmq \
    --from-literal=RABBITMQ_DEFAULT_USER=plane \
    --from-literal="RABBITMQ_DEFAULT_PASS=${rabbitmq_password}"
fi

if ! secret_exists plane-runtime-doc-store; then
  minio_password="$(openssl rand -hex 24)"
  "${kubectl_cmd[@]}" --namespace "${namespace}" create secret generic plane-runtime-doc-store \
    --from-literal=FILE_SIZE_LIMIT=20971520 \
    --from-literal=AWS_S3_BUCKET_NAME=uploads \
    --from-literal=USE_MINIO=1 \
    --from-literal=MINIO_ROOT_USER=plane-minio \
    --from-literal="MINIO_ROOT_PASSWORD=${minio_password}" \
    --from-literal=AWS_ACCESS_KEY_ID=plane-minio \
    --from-literal="AWS_SECRET_ACCESS_KEY=${minio_password}" \
    --from-literal="AWS_S3_ENDPOINT_URL=http://${release}-minio:9000"
fi

postgres_password="$(read_secret plane-runtime-postgres POSTGRES_PASSWORD)"
rabbitmq_password="$(read_secret plane-runtime-rabbitmq RABBITMQ_DEFAULT_PASS)"

if ! secret_exists plane-runtime-app; then
  secret_key="$(openssl rand -hex 32)"
  live_secret_key="$(openssl rand -hex 32)"
  "${kubectl_cmd[@]}" --namespace "${namespace}" create secret generic plane-runtime-app \
    --from-literal="SECRET_KEY=${secret_key}" \
    --from-literal="LIVE_SERVER_SECRET_KEY=${live_secret_key}" \
    --from-literal="REDIS_URL=redis://${release}-redis.${namespace}.svc.cluster.local:6379/" \
    --from-literal="DATABASE_URL=postgresql://plane:${postgres_password}@${release}-pgdb.${namespace}.svc.cluster.local:5432/plane" \
    --from-literal="AMQP_URL=amqp://plane:${rabbitmq_password}@${release}-rabbitmq.${namespace}.svc.cluster.local:5672/"
fi

live_secret_key="$(read_secret plane-runtime-app LIVE_SERVER_SECRET_KEY)"

if ! secret_exists plane-runtime-live; then
  "${kubectl_cmd[@]}" --namespace "${namespace}" create secret generic plane-runtime-live \
    --from-literal="LIVE_SERVER_SECRET_KEY=${live_secret_key}" \
    --from-literal="REDIS_URL=redis://${release}-redis.${namespace}.svc.cluster.local:6379/"
fi

if ! secret_exists plane-runtime-mcp; then
  mcp_oauth_secret="$(openssl rand -hex 32)"
  "${kubectl_cmd[@]}" --namespace "${namespace}" create secret generic plane-runtime-mcp \
    --from-literal=PLANE_OAUTH_PROVIDER_CLIENT_ID=plane-mcp-local \
    --from-literal="PLANE_OAUTH_PROVIDER_CLIENT_SECRET=${mcp_oauth_secret}"
fi

"${kubectl_cmd[@]}" --namespace "${namespace}" label secret \
  plane-runtime-postgres plane-runtime-rabbitmq plane-runtime-doc-store \
  plane-runtime-app plane-runtime-live plane-runtime-mcp \
  app.kubernetes.io/part-of=plane --overwrite >/dev/null

echo "Plane runtime secrets are ready in namespace ${namespace}."
