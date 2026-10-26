# TP 11 — Volumes, PV, PVC et StorageClass

**Durée : 25 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp11-volumes
```

## 1. Un volume `hostPath`

`random-number.yml` reprend l'exemple du cours : le pod tire un nombre et l'écrit dans `/opt/number.out`, monté depuis le dossier `/data` du nœud.

```bash
kubectl apply -f random-number.yml
kubectl get pod random-number-generator -w     # Ctrl+C après 20 secondes
kubectl describe pod random-number-generator
```

1. Le pod démarre-t-il ? Que dit la section `Events` ?
2. `type: Directory` exige que le dossier existe déjà sur le nœud. Remplacez-le par `type: DirectoryOrCreate`, supprimez le pod et réappliquez.

Relancez le pod deux fois pour ajouter deux nombres :

```bash
kubectl delete -f random-number.yml && kubectl apply -f random-number.yml
kubectl get pods -o wide
```

Un DaemonSet `lecteur` lit maintenant `/data/number.out` sur **chacun** des 3 nœuds :

```bash
kubectl apply -f lecteur.yml
kubectl logs -l app=lecteur --prefix
```

Sur combien de nœuds le fichier existe-t-il ? Contient-il tous vos nombres ? Quel est le problème de `hostPath` dans un cluster à plusieurs nœuds ?

## 2. PersistentVolume et PersistentVolumeClaim (statique)

L'administrateur crée un PV de 1 Gi, le développeur le réclame avec un PVC de 500 Mi :

```bash
kubectl apply -f pv-definition.yaml
kubectl get persistentvolume
kubectl apply -f pvc-definition.yaml
kubectl get persistentvolumeclaim
kubectl get persistentvolume
```

1. Le PVC `myclaim` est-il `Bound` ? À quel PV ? Quelle capacité obtient-il ?
2. Les deux fichiers contiennent `storageClassName: ""`. Sur k3s, sans cette ligne, le PVC partirait vers la classe par défaut et ne se lierait pas à `pv-vol1`.

Un second PVC demande 2 Gi :

```bash
kubectl apply -f pvc-trop-gros.yaml
kubectl get pvc
kubectl describe pvc pvc-trop-gros
```

Pourquoi reste-t-il `Pending` ?

Supprimez `myclaim` et regardez le PV :

```bash
kubectl delete pvc myclaim
kubectl get pv
```

Que veut dire `Released` ? Que signifie `RECLAIM POLICY: Retain` ?

## 3. La StorageClass : le disque à la demande

```bash
kubectl get storageclass
kubectl apply -f storageclass.yaml
kubectl get pvc data-pvc
```

`data-pvc` reste `Pending`. Pourquoi ? (Indice : `volumeBindingMode`.)

Un pod utilise le PVC. Il affiche le journal, puis y ajoute une ligne :

```bash
kubectl apply -f pod-journal.yml
kubectl get pvc data-pvc
kubectl get pv
kubectl logs journal
```

Qui a créé le PV ? Supprimez le pod, recréez-le, et relisez ses logs :

```bash
kubectl delete -f pod-journal.yml && kubectl apply -f pod-journal.yml
kubectl logs journal
```

Les données ont-elles survécu au pod ?

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
kubectl get pv
```

Le PV de `data-pvc` a disparu avec lui (`reclaimPolicy: Delete`). `pv-vol1` a été supprimé par son fichier.

## Ce qu'il faut retenir

- Un volume survit au conteneur ; `hostPath` reste collé à un nœud.
- PV : le stockage, créé par l'admin. PVC : la demande, faite par l'appli. Kubernetes les lie (capacité, mode d'accès, classe).
- Aucun PV ne convient : le PVC reste `Pending`.
- Avec une StorageClass, le PV est créé automatiquement. Sur k3s : `local-path`, le disque du nœud, sans réplication.
