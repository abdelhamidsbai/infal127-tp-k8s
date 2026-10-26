# TP 16 — CustomResourceDefinition

**Durée : 10 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp16-crd
```

## 1. Vous en utilisez déjà

```bash
kubectl get crd
```

Repérez les CRD de Traefik (`traefik.io`) et de k3s (`helm.cattle.io`). Ces types d'objets n'existent pas dans un Kubernetes de base.

## 2. Déclarer un nouveau type d'objet

```bash
kubectl apply -f backup-crd.yaml
kubectl get crd backups.demo.cesi.fr
kubectl api-resources | grep backups
```

Votre nouveau type apparaît à côté des types natifs.

## 3. Créer des objets de ce type

```bash
kubectl apply -f db-nightly.yaml
kubectl get backups
kubectl describe backup db-nightly
```

`kubectl explain` connaît aussi votre nouveau type :

```bash
kubectl explain backup.spec
```

D'où tient-il sa documentation ? (S'il répond qu'il ne trouve pas la ressource, attendez quelques secondes : l'API publie la documentation du nouveau type juste après sa création.)

Le schéma de la CRD est vérifié par l'API. Essayez un objet invalide :

```bash
kubectl apply -f backup-invalide.yaml
```

Pourquoi est-il refusé ?

## 4. Et à 2 h du matin ?

Rien ne se passera : aucune sauvegarde ne sera lancée. Pourquoi ? Que faudrait-il ajouter pour que l'objet `Backup` ait un effet ?

## Nettoyage

```bash
kubectl delete -f backup-crd.yaml
kubectl get backups
```

Supprimer la CRD supprime aussi tous les objets de ce type.

## Ce qu'il faut retenir

- Une CRD ajoute un nouveau `kind` à l'API : `kubectl get`, `describe`, `explain`, RBAC et Helm fonctionnent dessus.
- Une CRD seule ne fait que stocker des objets : c'est un contrôleur qui agit.
- Opérateur = CRD + contrôleur + savoir-faire d'un expert (CloudNativePG, cert-manager, Prometheus Operator…).
