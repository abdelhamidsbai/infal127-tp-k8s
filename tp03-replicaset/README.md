# TP 3 — ReplicaSet et auto-guérison

**Durée : 15 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp03-replicaset
```

## 1. Créer le ReplicaSet

Lisez `replicaset-definition.yml`, puis :

```bash
kubectl create -f replicaset-definition.yml
kubectl get replicaset
kubectl get pods -o wide
```

1. Combien de pods ? Comment sont-ils nommés ?
2. Sur quels nœuds sont-ils répartis ?

## 2. L'auto-guérison

Dans un **second terminal** (bouton `+` du terminal), surveillez les pods :

```bash
kubectl get pods -w
```

Dans le premier, supprimez un pod (remplacez par un vrai nom) :

```bash
kubectl delete pod myapp-replicaset-xxxxx
```

Que se passe-t-il dans le second terminal ? Qui a recréé le pod, et pourquoi ?

## 3. Changer le nombre de copies

Trois façons de faire, essayez-les dans l'ordre :

```bash
kubectl scale rs myapp-replicaset --replicas=5
kubectl scale --replicas=6 -f replicaset-definition.yml
```

Puis modifiez `replicas: 3` en `replicas: 2` dans le fichier, et :

```bash
kubectl replace -f replicaset-definition.yml
kubectl get rs
```

Après les deux premières commandes, le fichier dit-il encore la vérité ? Pourquoi la troisième méthode est-elle préférable ?

## 4. Le sélecteur

Le ReplicaSet ne possède pas ses pods : il les compte grâce à leurs labels.

```bash
kubectl get pods -l type=front-end
kubectl apply -f pod-intrus.yml
kubectl get pods
```

Le pod `intrus` porte le label `type: front-end`. Que lui arrive-t-il ? Pourquoi ?

Le fichier `replicaset-casse.yml` contient une erreur de labels :

```bash
kubectl create -f replicaset-casse.yml
```

Lisez le message d'erreur, puis corrigez le fichier pour qu'il soit accepté.

## Nettoyage

```bash
kubectl delete rs myapp-replicaset
kubectl get pods
kubectl delete -f replicaset-casse.yml --ignore-not-found
```

Que deviennent les pods quand on supprime le ReplicaSet ?

## Ce qu'il faut retenir

- Un ReplicaSet maintient `replicas` pods en vie, en comparant sans arrêt l'état désiré et l'état réel.
- `template` est le moule : la définition complète d'un pod.
- Les labels du `template` doivent correspondre au `selector`.
- On scale en modifiant le fichier : sinon, le YAML ne décrit plus la réalité.
