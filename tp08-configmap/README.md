# TP 8 — Variables d'environnement et ConfigMap

**Durée : 20 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp08-configmap
```

L'application `webapp-color` affiche une page de la couleur indiquée par la variable `APP_COLOR`.

## 1. Une variable en clair

```bash
kubectl apply -f pod-color.yml
kubectl port-forward pod/webapp-color 8080:8080
```

Ouvrez le port 8080 (onglet **PORTS**) : la page est rose. `Ctrl+C` pour arrêter le port-forward. Où la couleur est-elle définie ?

## 2. Créer une ConfigMap (impératif)

```bash
kubectl create configmap app-config \
  --from-literal=APP_COLOR=blue \
  --from-literal=APP_MODE=prod
kubectl get configmaps
kubectl describe configmap app-config
```

## 3. Injecter une seule clé : `env`

`webapp.yml` déploie la même application, mais lit `APP_COLOR` dans la ConfigMap.

```bash
kubectl apply -f webapp.yml
kubectl port-forward deploy/webapp 8080:8080
```

Quelle couleur ? `Ctrl+C`.

## 4. Injecter toutes les clés : `envFrom`

```bash
kubectl apply -f pod-envfrom.yml
kubectl logs env-check
```

Le pod affiche ses variables d'environnement. Retrouvez-vous `APP_COLOR` et `APP_MODE` ?

## 5. Injecter en fichiers : le volume

```bash
kubectl apply -f pod-volume.yml
kubectl logs config-volume
```

Chaque clé de la ConfigMap est devenue un fichier dans `/etc/app`. Le pod relit `/etc/app/APP_COLOR` toutes les 5 secondes.

## 6. Modifier la ConfigMap

`config-map.yaml` est la version déclarative de la ConfigMap, versionnable dans Git, avec `APP_COLOR: green`.

```bash
kubectl apply -f config-map.yaml
kubectl logs -f config-volume        # attendez jusqu'à 1 minute, puis Ctrl+C
```

1. Le pod `config-volume` voit-il la nouvelle couleur ? Sans redémarrer ?
2. Relancez le port-forward vers `deploy/webapp` : la page est-elle verte ?
3. Les variables d'environnement sont lues au démarrage du conteneur. Redémarrez les pods, puis vérifiez :

```bash
kubectl rollout restart deployment/webapp
kubectl port-forward deploy/webapp 8080:8080
```

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
```

## Ce qu'il faut retenir

- La configuration vit dans l'environnement, pas dans le code ni dans l'image.
- Une ConfigMap stocke de la configuration non sensible, en clair, dans un bloc `data`.
- Trois injections : `envFrom` (toutes les clés), `env` (une clé), volume (un fichier par clé).
- Modifier une ConfigMap ne redémarre rien : les variables demandent un `rollout restart`, le volume se met à jour seul.
