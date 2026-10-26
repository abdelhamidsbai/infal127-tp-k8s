# INFAL127 — TP Kubernetes

Tous les TP se font dans un **GitHub Codespace** : un environnement en ligne, dans votre navigateur, avec les outils déjà installés (Docker, kubectl, helm, k3d). Rien à installer sur votre ordinateur.

## Démarrer

1. Connectez-vous à votre compte GitHub **personnel**.
2. Ouvrez ce lien : **https://codespaces.new/abdelhamidsbai/infal127-tp-kubernetes**
3. Cliquez sur **Create codespace** et patientez 2 à 4 minutes.
4. Ouvrez le terminal (menu ☰ → Terminal → New Terminal) et commencez par le [TP 0](tp00-cluster/README.md).

## Règles d'usage

- **Fin de séance** : arrêtez votre codespace (☰ → *Stop Current Codespace*, ou depuis https://github.com/codespaces). Il s'arrête aussi seul après 30 minutes d'inactivité.
- **Reprise** : rouvrez le même codespace depuis https://github.com/codespaces. Votre cluster redémarre automatiquement.
- **Fin du module** : supprimez votre codespace, il consomme votre quota gratuit même arrêté.
- **Vos fichiers** restent dans votre codespace d'une séance à l'autre. Rien à rendre : on vérifie ensemble, en séance.

## Programme des TP

### Jour 1

| TP | Sujet | Durée |
|----|-------|-------|
| 0 | [La course au cluster](tp00-cluster/README.md) | 20 min |
| 1 | [Pods et YAML](tp01-pod/README.md) | 20 min |
| 2 | [Cycle de vie et sondes](tp02-cycle-de-vie/README.md) | 25 min |
| 3 | [ReplicaSet et auto-guérison](tp03-replicaset/README.md) | 15 min |
| 4 | [Deployment : mise à jour et retour arrière](tp04-deployment/README.md) | 25 min |
| 5 | [Namespaces, DaemonSet et NodePort](tp05-namespaces-nodeport/README.md) | 25 min |
| 6 | [Service ClusterIP](tp06-clusterip/README.md) | 15 min |
| 7 | [LoadBalancer et DNS](tp07-loadbalancer-dns/README.md) | 15 min |

### Jour 2

| TP | Sujet | Durée |
|----|-------|-------|
| 8 | [Variables d'environnement et ConfigMap](tp08-configmap/README.md) | 20 min |
| 9 | [Secret](tp09-secret/README.md) | 15 min |
| 10 | [Ingress](tp10-ingress/README.md) | 25 min |
| 11 | [Volumes, PV, PVC et StorageClass](tp11-volumes/README.md) | 25 min |
| 12 | [ServiceAccount et RBAC](tp12-rbac/README.md) | 20 min |
| 13 | [NetworkPolicy](tp13-networkpolicy/README.md) | 15 min |
| 14 | [Sécurité des pods et des images](tp14-securite/README.md) | 15 min |
| 15 | [Requests, limits et HPA](tp15-ressources-hpa/README.md) | 25 min |
| 16 | [CRD](tp16-crd/README.md) | 10 min |
| 17 | [Helm](tp17-helm/README.md) | 25 min |
| 18 | [Monitoring (optionnel)](tp18-monitoring/README.md) | 15 min |
