# TP 12 — ServiceAccount et RBAC

**Durée : 20 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp12-rbac
```

## 1. Un ServiceAccount et son jeton

```bash
kubectl create serviceaccount dashboard-sa
TOKEN=$(kubectl create token dashboard-sa --duration=1h)
echo $TOKEN | cut -c1-50
```

Appelez l'API Kubernetes avec ce jeton. L'adresse de l'API est celle de `kubectl cluster-info` :

```bash
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -sk $APISERVER/api/v1/namespaces/default/pods \
  --header "Authorization: Bearer $TOKEN"
```

1. Que répond l'API ? Le jeton prouve-t-il l'identité ? Donne-t-il des droits ?
2. `-k` évite de vérifier le certificat de l'API : en vrai, on passe `--cacert ca.crt`.

## 2. Le jeton monté dans le pod

Une nouvelle commande, pour ouvrir un terminal dans un conteneur : `kubectl exec`.

```bash
kubectl apply -f pod-dashboard.yml
kubectl exec dashboard -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl get pod dashboard -o jsonpath='{.spec.serviceAccountName}'; echo
```

Le pod `sans-jeton` n'appelle jamais l'API : il désactive le montage du jeton.

```bash
kubectl apply -f pod-sans-jeton.yml
kubectl exec sans-jeton -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

Pourquoi est-ce une bonne pratique ? (Pensez à une faille qui donne un shell à un attaquant.)

## 3. Donner un droit précis : Role et RoleBinding

`role-pod-reader.yaml` crée un Role (lire les pods du namespace `default`) et le lie à `dashboard-sa`.

```bash
kubectl apply -f role-pod-reader.yaml
curl -sk $APISERVER/api/v1/namespaces/default/pods \
  --header "Authorization: Bearer $TOKEN" | grep '"name"' | head -5
kubectl auth can-i list pods --as=system:serviceaccount:default:dashboard-sa
kubectl auth can-i delete pods --as=system:serviceaccount:default:dashboard-sa
kubectl auth can-i list pods -n kube-system --as=system:serviceaccount:default:dashboard-sa
```

Expliquez chacune des trois réponses.

## 4. Le scénario du stagiaire

Tom, le stagiaire, doit pouvoir **lire** les pods du namespace `dev`, et rien d'autre. Complétez `stagiaire.yaml` (les `À_COMPLÉTER`), puis vérifiez :

```bash
kubectl apply -f stagiaire.yaml
kubectl auth can-i get pods -n dev --as tom          # attendu : yes
kubectl auth can-i list pods -n dev --as tom         # attendu : yes
kubectl auth can-i delete pods -n dev --as tom       # attendu : no
kubectl auth can-i get pods -n default --as tom      # attendu : no
kubectl auth can-i get secrets -n dev --as tom       # attendu : no
```

`--as tom` : vous, administrateur, empruntez l'identité de Tom pour tester ses droits. Kubernetes ne gère pas les utilisateurs : Tom existe parce qu'un certificat ou un fournisseur d'identité le dit.

## 5. Bonus : ClusterRole

```bash
kubectl auth can-i list nodes --as tom
```

Les nœuds n'appartiennent à aucun namespace. Écrivez un `ClusterRole` `node-reader` (verbes `get`, `list` sur `nodes`) et un `ClusterRoleBinding` vers Tom, puis vérifiez.

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
kubectl delete serviceaccount dashboard-sa
```

## Ce qu'il faut retenir

- Deux types de comptes : les utilisateurs (humains, gérés hors de Kubernetes) et les ServiceAccounts (les applis).
- Un jeton prouve l'identité, il ne donne aucun droit : c'est RBAC qui autorise.
- Role + RoleBinding : un namespace. ClusterRole + ClusterRoleBinding : tout le cluster.
- Moindre privilège : un ServiceAccount par appli, et `automountServiceAccountToken: false` si elle n'appelle pas l'API.
