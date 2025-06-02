#!/bin/bash

set -euo pipefail


if [ -z "${1:-}" ]; then
  read -rp "Enter Namespace to deploy resource : " NAMESPACE
else
  NAMESPACE="$1"
fi

echo "🔧 Using namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "📄 Creating ConfigMap..."
kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  config.txt: |
    This is a sample config file.
EOF

echo "🔐 Creating Secret..."
kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-secret
type: Opaque
data:
  username: $(echo -n 'admin' | base64)
  password: $(echo -n 's3cr3t' | base64)
EOF

echo "🚀 Creating Deployment..."
kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-deploy
  template:
    metadata:
      labels:
        app: demo-deploy
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

echo "📦 Creating standalone Pod with ConfigMap..."
kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-config
spec:
  containers:
  - name: alpine
    image: alpine
    command: ["sleep", "3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: demo-config
EOF

echo "🔐 Creating another Pod with Secret..."
kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-secret
spec:
  containers:
  - name: alpine
    image: alpine
    command: ["sleep", "3600"]
    env:
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: demo-secret
          key: username
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: demo-secret
          key: password
EOF

echo "🔌 Creating Service for Deployment..."
kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: demo-service
spec:
  selector:
    app: demo-deploy
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF

echo "⏳ Waiting for resources to be ready..."
kubectl wait --namespace $NAMESPACE --for=condition=Ready pod/pod-with-config --timeout=60s
kubectl wait --namespace $NAMESPACE --for=condition=Ready pod/pod-with-secret --timeout=60s
kubectl rollout status deployment/demo-deployment -n $NAMESPACE

echo "🔍 Verifying resources..."
kubectl get all -n $NAMESPACE
kubectl get configmap demo-config -n $NAMESPACE
kubectl get secret demo-secret -n $NAMESPACE

echo "✅ All resources deployed and verified successfully in namespace '$NAMESPACE'"
