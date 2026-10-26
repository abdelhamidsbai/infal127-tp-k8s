# TP 1 — Pods et YAML

**Durée : 20 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp01-pod
```

## 1. Un pod en une commande (impératif)

```bash
kubectl run nginx --image=nginx
kubectl get pods
```

Relancez `kubectl get pods` jusqu'à voir `STATUS: Running` et `READY: 1/1`. Par quel statut le pod est-il passé avant ?

```bash
kubectl get pods -o wide
```

Sur quel nœud tourne votre pod ? Quelle est son adresse IP ?

```bash
kubectl describe pod nginx
```

Lisez la section `Events`, en bas : quelles étapes le cluster a-t-il suivies pour démarrer votre pod ?

Supprimez-le :

```bash
kubectl delete pod nginx
kubectl get pods
```

Il ne revient pas. Est-ce un problème ? (On y répondra bientôt.)

## 2. Le même pod en YAML (déclaratif)

Créez le fichier `pod-definition.yml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
    type: front-end
spec:
  containers:
  - name: nginx-container
    image: nginx
```

```bash
kubectl apply -f pod-definition.yml
kubectl get pods --show-labels
```

1. Ajoutez le label `env: dev` dans le fichier, puis relancez `kubectl apply -f pod-definition.yml`. Le pod est-il recréé (regardez la colonne `AGE`), ou simplement mis à jour ?
2. Que vous apprend `kubectl explain pod.spec.containers` ?
3. Remplacez les 2 espaces devant `image: nginx` par une tabulation, puis relancez `kubectl apply`. Que dit kubectl ? Corrigez.
4. Retirez le tiret devant `- name: nginx-container` et relancez. Même question. Remettez le tiret.

## 3. Deux conteneurs, un seul pod

Lisez `multi-container.yml` : un conteneur principal (nginx) et un auxiliaire (sidecar) qui l'interroge toutes les 5 secondes.

```bash
kubectl apply -f multi-container.yml
kubectl get pod web-et-sidecar -o wide
kubectl describe pod web-et-sidecar
```

1. Que signifie `2/2` dans la colonne `READY` ?
2. Combien d'adresses IP le pod a-t-il, pour deux conteneurs ?
3. Le sidecar appelle nginx sur `http://localhost:80`. Pourquoi est-ce possible ? (On lira ce qu'il reçoit au TP 2.)
4. Pour obtenir la même chose avec Docker seul, quelles options faudrait-il passer à `docker run` ?

## Nettoyage

Gardez `web-et-sidecar` pour le TP 2, supprimez le reste :

```bash
kubectl delete -f pod-definition.yml
```

## Ce qu'il faut retenir

- `kubectl run` pour tester, un fichier YAML et `kubectl apply` pour travailler pour de vrai.
- Un manifeste a toujours `apiVersion`, `kind`, `metadata` (identité, labels) et `spec` (ce qu'on veut).
- YAML : 2 espaces, jamais de tabulation, un tiret pour chaque élément de liste.
- `kubectl describe` et sa section `Events` : le premier réflexe quand quelque chose ne va pas.
- Les conteneurs d'un même pod partagent le réseau : même IP, même `localhost`.
