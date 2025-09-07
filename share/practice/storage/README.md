# PV & PVC Practice

This folder contains small, self-contained PV/PVC exercises designed for k8s practice.

## Prereqs
- A working cluster (v1.24+) with `kubectl` access.
- NFS CSI driver installed (you already have `csi-nfs-*` pods).
- A StorageClass named `nfs-storage` (you already have one; change below if needed).

---

## Exercise 1 — Dynamic provisioning (RWX)

1) Create a 1Gi RWX PVC using the `nfs-storage` StorageClass:

```bash
kubectl apply -f 01-dynamic-pvc.yaml
kubectl get pvc
```

2) Mount it in a writer pod that writes the node name to a file:

```bash
kubectl apply -f 02-dynamic-writer-pod.yaml
kubectl get pod nfs-dyn-writer -w
kubectl exec nfs-dyn-writer -- sh -c 'cat /data/out/host.txt'
```

3) Mount the same PVC in a reader pod to verify RWX sharing:

```bash
kubectl apply -f 03-dynamic-reader-pod.yaml
kubectl exec nfs-dyn-reader -- sh -c 'cat /data/out/host.txt'
```

Expected: both pods see the same file.


## Exercise 2 — Static provisioning (PV + PVC)

Use this if you want to practice static PV binding (common exam task).

Edit 04-static-pv.yaml and set:

* spec.nfs.server: your NFS server IP/hostname
* spec.nfs.path: an exported path that exists (e.g. /srv/nfs/static-pv1)

```bash
kubectl apply -f 04-static-pv.yaml
kubectl apply -f 05-static-pvc.yaml
kubectl get pv,pvc
kubectl apply -f 06-static-pod.yaml
kubectl exec nfs-static-pod -- sh -c 'cat /work/hello.txt'
```


Expected: file contains “hello-from-static-pv”.

## Cleanup
```bash
./90-cleanup.sh
```

## Tips (PV/PVC)

Match modes & size: accessModes and requested resources.requests.storage must be compatible with the PV.

Static binding:

* PVC must not specify a storageClassName (or set it to "") to bind to a classless static PV.

* If PVC has selector labels, the PV must have matching metadata.labels.

Reclaim policy:

* Retain will keep the NFS data after PVC deletion (you must clean manually).

* Delete is handled by the provisioner (dynamic). For CSI NFS, it typically removes the subdir it created (not the whole export).

RWX test: always prove multi-pod read/write by mounting the same claim in two pods.

Troubleshooting: kubectl describe pvc <name> shows events when binding fails. kubectl describe pv <name> shows claim refs & reasons.
