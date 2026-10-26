# TP 13 — NetworkPolicy

**Durée : 15 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp13-networkpolicy
```

Une boutique en trois couches, dans le namespace `boutique` : `front` → `api` (port 8080) → `db` (port 5432).

## 1. Par défaut, tout est ouvert

```bash
kubectl apply -f boutique.yml
kubectl get pods -n boutique --show-labels
```

Depuis le front, appelez l'API, puis directement la base :

```bash
kubectl exec -n boutique front -- wget -qO- -T 3 http://api:8080 | head -1
kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432 | head -1
```

Le front n'a aucune raison de parler à la base. Que se passerait-il si le front était piraté ?

## 2. Tout fermer : `default-deny`

```bash
kubectl apply -f default-deny.yaml
kubectl exec -n boutique front -- wget -qO- -T 3 http://api:8080 | head -1
kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432 | head -1
```

Que signifie `podSelector: {}` ? Que répond `wget` ? Qui a bloqué la connexion ?

## 3. Rouvrir flux par flux

```bash
kubectl apply -f api-from-front.yaml
kubectl exec -n boutique front -- wget -qO- -T 3 http://api:8080 | head -1
kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432 | head -1
```

Le premier appel passe, le second reste bloqué. Pourquoi ?

## 4. À vous : l'API doit joindre la base

Complétez `db-from-api.yaml` : seuls les pods `app: api` peuvent joindre les pods `app: db`, sur le port 5432.

Pour tester, lancez un pod de test qui **porte le label** `app: api` :

```bash
kubectl apply -f db-from-api.yaml
kubectl run -n boutique test-api --image=busybox:1.37 --labels=app=api -- sleep 3600
kubectl wait -n boutique --for=condition=Ready pod/test-api
kubectl exec -n boutique test-api -- wget -qO- -T 3 http://db:5432 | head -1
kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432 | head -1
```

Le pod de test passe, le front reste bloqué. Pour une NetworkPolicy, qu'est-ce qui définit l'identité d'un pod ?

## Nettoyage

```bash
kubectl delete namespace boutique
```

## Ce qu'il faut retenir

- Par défaut, le réseau est plat : tout pod peut joindre tout pod, dans tous les namespaces.
- Une politique `default-deny` par namespace, puis une règle explicite par flux autorisé.
- Les règles visent des labels et des ports, pas des IP.
- Il faut un CNI qui les applique : k3s intègre un contrôleur, Flannel seul ne le ferait pas.
