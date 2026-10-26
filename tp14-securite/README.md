# TP 14 — Sécurité des pods et des images

**Durée : 15 minutes** (dont 5 minutes de bonus). Placez-vous dans le dossier du TP :

```bash
cd tp14-securite
```

## 1. Refuser de tourner en root

`pod-root.yml` demande `runAsNonRoot: true`, mais l'image `nginx` démarre en root.

```bash
kubectl apply -f pod-root.yml
kubectl get pod pod-root
kubectl describe pod pod-root | tail -5
```

Quel est le statut ? Que dit le message d'erreur ?

## 2. Un conteneur avec le moins de droits possible

`pod-securise.yml` reprend le `securityContext` du cours avec `nginx-unprivileged`, une image prévue pour tourner sans root, sur le port 8080.

```bash
kubectl apply -f pod-securise.yml
kubectl get pod pod-securise
kubectl exec pod-securise -- id
kubectl exec pod-securise -- touch /etc/test
kubectl exec pod-securise -- touch /tmp/test
```

1. Sous quel utilisateur tourne le conteneur ?
2. Pourquoi peut-on écrire dans `/tmp` mais pas dans `/etc` ?

## 3. Pod Security Admission

Le namespace `securise` impose le niveau `restricted` :

```bash
kubectl apply -f namespace-restricted.yaml
kubectl apply -f pod-root.yml -n securise
kubectl apply -f pod-securise.yml -n securise
kubectl get pods -n securise
```

1. Le premier pod est-il créé ? Lisez la liste des règles qu'il enfreint.
2. Le second est-il accepté ?

## 4. Bonus : scanner avec Trivy

```bash
trivy image --severity CRITICAL nginx:1.27
trivy config .
```

1. L'image contient-elle des vulnérabilités critiques ?
2. Que reproche Trivy à `pod-root.yml` ?

Pour un résumé de tout le cluster (plus long) : `trivy k8s --report summary`.

## Nettoyage

```bash
kubectl delete -f pod-root.yml -f pod-securise.yml --ignore-not-found
kubectl delete namespace securise
```

## Ce qu'il faut retenir

- `securityContext` : pas de root, pas d'escalade, système de fichiers en lecture seule, aucune capability.
- Pod Security Admission : un label sur le namespace (`privileged`, `baseline`, `restricted`) et le cluster refuse les pods non conformes.
- Une image se construit minimale, se scanne (Trivy), se signe, et se déploie avec un tag fixe, jamais `:latest`.
