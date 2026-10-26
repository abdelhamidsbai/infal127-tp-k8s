# TP 4 — Deployment : mise à jour et retour arrière

**Durée : 25 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp04-deployment
```

## 1. Créer le Deployment

Lisez `deployment-definition.yml` (image `nginx:1.26`), puis :

```bash
kubectl create -f deployment-definition.yml
kubectl get deployments
kubectl get replicaset
kubectl get pods
kubectl get all
```

Regardez les noms : `myapp-deployment` → `myapp-deployment-<hash>` → `myapp-deployment-<hash>-<id>`. Qui gère qui ?

## 2. Une mise à jour (méthode déclarative)

Dans un second terminal, gardez un œil sur les ReplicaSets :

```bash
kubectl get rs -w
```

Dans le fichier, passez l'image en `nginx:1.27`, puis :

```bash
kubectl apply -f deployment-definition.yml
kubectl rollout status deployment/myapp-deployment
kubectl annotate deployment/myapp-deployment kubernetes.io/change-cause="passage en nginx 1.27"
kubectl rollout history deployment/myapp-deployment
```

1. Combien de ReplicaSets voyez-vous maintenant ? Combien de pods chacun ?
2. Que contient la colonne `CHANGE-CAUSE` ?

## 3. Une mise à jour (méthode impérative)

```bash
kubectl set image deployment/myapp-deployment nginx=nginx:1.28
kubectl rollout status deployment/myapp-deployment
kubectl annotate deployment/myapp-deployment kubernetes.io/change-cause="passage en nginx 1.28"
```

Ouvrez `deployment-definition.yml` : quelle image indique-t-il ? Quel est le problème ?

## 4. Oups, un bug : le retour arrière

Quelqu'un déploie une image qui n'existe pas :

```bash
kubectl set image deployment/myapp-deployment nginx=nginx:1.99
kubectl rollout status deployment/myapp-deployment     # Ctrl+C au bout de 20 secondes
kubectl get pods
```

1. Combien d'anciens pods tournent encore ? Le service est-il coupé ?
2. Revenez en arrière :

```bash
kubectl rollout undo deployment/myapp-deployment
kubectl rollout history deployment/myapp-deployment
kubectl get pods
```

Quelle image tourne maintenant ?

## 5. Une mise à jour sans coupure

Le fichier `deployment-sans-coupure.yml` déploie `myapp` avec `maxSurge: 1`, `maxUnavailable: 0` et une `readinessProbe`.

```bash
kubectl apply -f deployment-sans-coupure.yml
kubectl rollout status deployment/myapp
```

Ouvrez `deployment-sans-coupure-v2.yml` : la nouvelle version a une sonde qui ne répondra jamais (mauvais port). Déployez-la et observez :

```bash
kubectl apply -f deployment-sans-coupure-v2.yml
kubectl get pods -w        # 30 secondes, puis Ctrl+C
```

1. Combien de pods v2 démarrent ? Sont-ils `READY` ?
2. Combien de pods v1 restent en place ? Pourquoi la mise à jour s'arrête-t-elle ?
3. Réparez avec `kubectl rollout undo deployment/myapp`.

## Nettoyage

```bash
kubectl delete -f deployment-definition.yml -f deployment-sans-coupure.yml
```

## Ce qu'il faut retenir

- Un Deployment gère des ReplicaSets, qui gèrent des pods : on n'écrit que le Deployment.
- Modifier le `template` déclenche un rolling update : un nouveau ReplicaSet monte, l'ancien descend.
- `rollout status`, `rollout history`, `rollout undo` : suivre, tracer, revenir en arrière.
- Avec `maxUnavailable: 0` et une readiness, une version qui ne démarre pas ne remplace jamais l'ancienne.
