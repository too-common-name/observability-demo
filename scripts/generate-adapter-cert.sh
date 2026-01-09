#!/bin/bash
set -e

NAMESPACE="openshift-tracing"
CA_SECRET_NAME="tempo-platform-signing-ca"
TARGET_SECRET_NAME="mcp-adapter-mtls"
TMP_DIR=$(mktemp -d)

echo "🔒 Checking mTLS adapter certificate..."

echo "   ⚙️  Generating new Client Certificate signed by Tempo CA..."

oc get secret "$CA_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$TMP_DIR/ca.crt"
oc get secret "$CA_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > "$TMP_DIR/ca.key"

openssl genrsa -out "$TMP_DIR/adapter.key" 2048 >/dev/null 2>&1
openssl req -new -key "$TMP_DIR/adapter.key" \
    -out "$TMP_DIR/adapter.csr" \
    -subj "/CN=mcp-adapter" >/dev/null 2>&1

openssl x509 -req -in "$TMP_DIR/adapter.csr" \
    -CA "$TMP_DIR/ca.crt" -CAkey "$TMP_DIR/ca.key" -CAcreateserial \
    -out "$TMP_DIR/adapter.crt" -days 365 -sha256 >/dev/null 2>&1

oc create secret generic "$TARGET_SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-file=tls.crt="$TMP_DIR/adapter.crt" \
    --from-file=tls.key="$TMP_DIR/adapter.key" \
    --from-file=ca.crt="$TMP_DIR/ca.crt" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null

echo "   ✅ Created secret '$TARGET_SECRET_NAME' in '$NAMESPACE'."

rm -rf "$TMP_DIR"