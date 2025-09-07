#!/usr/bin/env bash
set -eu

# Dynamic objects
kubectl delete pod nfs-dyn-reader --ignore-not-found
kubectl delete pod nfs-dyn-writer --ignore-not-found
kubectl delete pvc nfs-dyn-pvc --ignore-not-found

# Static objects
kubectl delete pod nfs-static-pod --ignore-not-found
kubectl delete pvc nfs-static-pvc --ignore-not-found
kubectl delete pv nfs-static-pv --ignore-not-found
