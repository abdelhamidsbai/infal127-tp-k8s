# TP 17 — Helm

**Durée : 25 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp17-helm
```

Helm est déjà installé dans le codespace : `helm version`.

On utilise le chart `podinfo`, une petite application web dont on peut changer le message et la couleur.

## 1. Trouver un chart

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm repo list
helm search repo podinfo
helm show values podinfo/podinfo | grep -A4 "^ui:"
```

Quelle est la différence entre la version du chart et la version de l'application (`APP VERSION`) ?

## 2. Un chart, deux releases

Lisez `values-dev.yaml` et `values-prod.yaml`, puis installez le même chart deux fois :

```bash
helm install podinfo-dev podinfo/podinfo -n dev --create-namespace -f values-dev.yaml
helm install podinfo-prod podinfo/podinfo -n prod --create-namespace -f values-prod.yaml
helm list -A
kubectl get all -n prod
```

1. Combien de pods en dev ? En prod ? D'où vient la différence ?
2. Combien d'objets Kubernetes une seule commande `helm install` a-t-elle créés ?

Ouvrez la version de prod dans le navigateur :

```bash
kubectl port-forward -n prod svc/podinfo-prod 9898:9898
```

Ouvrez le port 9898 de l'onglet **PORTS**. `Ctrl+C` pour arrêter.

## 3. Mettre à jour, revenir en arrière

```bash
helm upgrade podinfo-prod podinfo/podinfo -n prod -f values-prod.yaml --set ui.color="#d9534f"
helm history podinfo-prod -n prod
```

Rouvrez le port-forward : la page a changé de couleur. Puis :

```bash
helm rollback podinfo-prod 1 -n prod
helm history podinfo-prod -n prod
kubectl get secrets -n prod -l owner=helm
```

1. Le rollback efface-t-il la révision 2, ou en crée-t-il une nouvelle ?
2. Où Helm range-t-il son historique ?

## 4. Écrire son propre chart

```bash
helm create monchart
ls monchart monchart/templates
helm lint monchart
helm template mon-app ./monchart | head -40
```

1. Retrouvez la structure du cours : `Chart.yaml`, `values.yaml`, `templates/`.
2. Que fait `helm template` ? Qu'a-t-il installé dans le cluster ?
3. Dans `monchart/values.yaml`, passez `replicaCount` à 2, puis installez :

```bash
helm install mon-app ./monchart
kubectl get pods
```

## 5. Bonus : un chart depuis un registre OCI

```bash
helm install demo oci://ghcr.io/stefanprodan/charts/podinfo -n demo --create-namespace
helm list -n demo
```

Pas de `helm repo add` : le chart est téléchargé directement depuis le registre, comme une image.

## Nettoyage

```bash
helm uninstall podinfo-dev -n dev
helm uninstall podinfo-prod -n prod
helm uninstall mon-app
helm uninstall demo -n demo --ignore-not-found
kubectl delete namespace dev prod demo --ignore-not-found
rm -rf monchart
```

Une commande par release suffit à tout retirer.

## Ce qu'il faut retenir

- Helm installe, met à jour et désinstalle une application complète d'un bloc, comme NuGet ou npm.
- Chart = templates + values. Un fichier de values par environnement, un seul chart.
- Release = une installation nommée. Chaque `upgrade` crée une révision, `rollback` y revient.
- `helm template` et `helm lint` vérifient un chart sans rien installer.
