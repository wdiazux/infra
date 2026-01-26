#!/usr/bin/env bash
set -euo pipefail

# Install NVIDIA GPU support (RuntimeClass + device plugin DaemonSet)
#
# Required environment variables:
#   KUBECONFIG                   - Path to kubeconfig file
#   NVIDIA_DEVICE_PLUGIN_VERSION - NVIDIA device plugin version (e.g., v0.18.1)

echo "=== Installing NVIDIA GPU Support ==="

# Create RuntimeClass
echo "Creating nvidia RuntimeClass..."
kubectl --kubeconfig="$KUBECONFIG" apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF

# Create NVIDIA device plugin DaemonSet
echo "Creating NVIDIA device plugin DaemonSet..."
kubectl --kubeconfig="$KUBECONFIG" apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      runtimeClassName: nvidia
      priorityClassName: system-node-critical
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: nvidia-device-plugin-ctr
          image: nvcr.io/nvidia/k8s-device-plugin:${NVIDIA_DEVICE_PLUGIN_VERSION}
          env:
            - name: DEVICE_DISCOVERY_STRATEGY
              value: nvml
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: device-plugin
              mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
EOF

echo "=== NVIDIA GPU Support Installed ==="
