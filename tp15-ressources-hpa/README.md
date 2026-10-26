# TP 15 — Requests, limits et HPA

**Durée : 25 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp15-ressources-hpa
```

## 1. Requests : le pod qui ne trouve pas de place

`pod-gourmand.yml` réserve 10 CPU. Votre codespace en a 2.

```bash
kubectl apply -f pod-gourmand.yml
kubectl get pod gourmand
kubectl describe pod gourmand | tail -5
```

Quel est le statut ? Que dit l'événement `FailedScheduling` ? Le pod consomme-t-il quoi que ce soit ?

Corrigez la requête à `cpu: "100m"`, supprimez le pod et réappliquez.

## 2. Limits : le conteneur qui dépasse

`pod-oom.yml` a une limite mémoire de 100 Mi, mais son programme tente d'en consommer 250.

```bash
kubectl apply -f pod-oom.yml
kubectl get pod oom -w        # 30 secondes, puis Ctrl+C
kubectl describe pod oom | grep -A3 "Last State"
```

1. Quel statut voyez-vous passer ? Que veut dire `OOMKilled` ?
2. Si c'était le CPU qui dépassait sa limite, le conteneur serait-il tué ?

## 3. L'autoscaling horizontal (HPA)

`api.yml` déploie une API qui consomme du CPU à chaque requête, avec `requests.cpu: 200m`.

Dans `hpa.yaml`, les valeurs sont plus petites que dans le cours (cible 50 %, 1 à 5 pods) : le codespace n'a que 2 CPU.

```bash
kubectl apply -f api.yml
kubectl top pods          # metrics-server est inclus dans k3s
kubectl apply -f hpa.yaml
kubectl get hpa
```

Dans un **second terminal**, surveillez l'HPA :

```bash
kubectl get hpa api -w
```

Dans le premier, générez de la charge :

```bash
kubectl run load --image=busybox:1.37 --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://api; done"
```

Attendez 1 à 2 minutes.

1. Que devient la colonne `TARGETS` ? Et `REPLICAS` ?
2. Vérifiez le calcul : pods voulus = pods actuels × utilisation ÷ cible (50 %).
3. Pourquoi ne fixe-t-on plus `replicas` dans `api.yml` une fois l'HPA en place ?

Arrêtez la charge :

```bash
kubectl delete pod load
```

La redescente prend environ 5 minutes : Kubernetes attend d'être sûr que la charge est vraiment retombée.

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
```

## Ce qu'il faut retenir

- Le scheduler place les pods selon leurs `requests`, pas selon leur consommation réelle.
- Au-delà de sa limite CPU, un conteneur est ralenti. Au-delà de sa limite mémoire, il est tué (`OOMKilled`).
- L'HPA ajuste `replicas` entre `minReplicas` et `maxReplicas`, à partir des métriques de metrics-server.
- Pas de `requests.cpu`, pas d'autoscaling sur le CPU.
