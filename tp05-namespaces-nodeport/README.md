# TP 5 — DaemonSet, namespaces et NodePort

**Durée : 25 minutes** (dont 5 minutes de partie optionnelle). Placez-vous dans le dossier du TP :

```bash
cd tp05-namespaces-nodeport
```

## 1. (Optionnel) Un pod par nœud : le DaemonSet

```bash
kubectl apply -f daemonset.yaml
kubectl get ds -A
kubectl get pods -n kube-system -l app=log-agent -o wide
```

Combien de pods `log-agent` ? Sur quels nœuds ?

Ajoutez un quatrième nœud au cluster et observez :

```bash
k3d node create extra --cluster cesi
kubectl get nodes
kubectl get pods -n kube-system -l app=log-agent -o wide
```

Le nouveau nœud a-t-il reçu son pod ? Qui l'a créé ?

Retirez le nœud et le DaemonSet :

```bash
k3d node delete k3d-extra-0
kubectl delete node k3d-extra-0 --ignore-not-found
kubectl delete -f daemonset.yaml
```

## 2. Les namespaces

```bash
kubectl get namespaces
kubectl get pods --namespace=kube-system
```

Reconnaissez-vous les composants de k3s (DNS, Ingress, stockage, métriques) ?

Créez le namespace `team1` à partir du fichier, puis deux pods dedans, de deux façons différentes :

```bash
kubectl create -f namespace-definition.yml
kubectl create -f pod-definition.yml --namespace=team1
kubectl create -f pod-team1.yml
kubectl get pods
kubectl get pods --namespace=team1
```

1. Pourquoi `kubectl get pods` n'affiche-t-il rien ?
2. Dans `pod-team1.yml`, où le namespace est-il indiqué ?

Changez de namespace par défaut, puis revenez :

```bash
kubectl config set-context --current --namespace=team1
kubectl get pods
kubectl config set-context --current --namespace=default
```

## 3. Le réseau plat

```bash
kubectl get pods -n team1 -o wide
```

Notez l'IP de `myapp-pod`. Depuis un pod temporaire placé dans un autre namespace (`default`), appelez-la directement :

```bash
kubectl run -it --rm test --image=busybox:1.37 --restart=Never -- wget -qO- http://<IP-de-myapp-pod>
```

La page nginx s'affiche : aucun NAT, aucun port publié, même entre namespaces. `--rm` supprime le pod à la fin.

## 4. Le NodePort

Lisez `myapp.yml` (3 pods nginx `app: myapp`) et `service-definition.yml` (NodePort 30008), puis :

```bash
kubectl apply -f myapp.yml -f service-definition.yml
kubectl get service myapp-service
kubectl get nodes -o wide
```

Appelez le service sur **chacun** des 3 nœuds, avec la colonne `INTERNAL-IP` :

```bash
curl http://<IP-d-un-noeud>:30008
```

Pas de réponse au premier essai ? Réessayez après quelques secondes : kube-proxy doit d'abord installer les règles réseau du Service sur chaque nœud.

1. Les 3 nœuds répondent-ils, même ceux qui n'ont pas de pod `myapp` ?
2. La trinité des ports : dans `service-definition.yml`, remplacez `targetPort: 80` par `targetPort: 8080`, réappliquez et réessayez. Que se passe-t-il ? Pourquoi ? Remettez `80`.

## Nettoyage

```bash
kubectl delete namespace team1
kubectl delete -f myapp.yml -f service-definition.yml
```

Supprimer un namespace supprime tout ce qu'il contient.

## Ce qu'il faut retenir

- Un DaemonSet place exactement un pod par nœud, y compris sur les nœuds ajoutés plus tard.
- Un namespace isole les noms : `--namespace`, ou `metadata.namespace` dans le YAML.
- Chaque pod a sa propre IP, joignable depuis tous les autres pods, sans NAT.
- NodePort : `nodePort` (le nœud, 30000-32767) → `port` (le Service) → `targetPort` (le conteneur).
