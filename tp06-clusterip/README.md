# TP 6 — Service ClusterIP

**Durée : 15 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp06-clusterip
```

## 1. Un back-end derrière un ClusterIP

`back-end.yml` déploie 3 pods `whoami` : chacun répond avec son propre nom. `service-definition.yml` les regroupe derrière le Service `back-end`.

```bash
kubectl apply -f back-end.yml -f service-definition.yml
kubectl get services
kubectl describe service back-end
```

1. Quelle est la `CLUSTER-IP` du Service ? A-t-il une IP externe ou un NodePort ?
2. Que contient la ligne `Endpoints` ?

## 2. L'appeler depuis l'intérieur du cluster

Un ClusterIP n'est joignable que depuis le cluster. Lancez un pod temporaire et appelez l'IP du Service plusieurs fois :

```bash
kubectl run -it --rm client --image=busybox:1.37 --restart=Never -- sh
```

Dans le pod :

```sh
for i in 1 2 3 4 5 6; do wget -qO- http://<CLUSTER-IP> | grep Hostname; done
exit
```

Quel pod a répondu à chaque appel ? Que fait le Service ?

## 3. Seuls les pods prêts reçoivent du trafic

`back-end-pas-pret.yml` ajoute un quatrième pod avec les mêmes labels, mais dont la readiness échoue.

```bash
kubectl apply -f back-end-pas-pret.yml
kubectl get pods -l type=back-end
kubectl describe service back-end
```

1. Le nouveau pod est-il `READY` ?
2. Son IP apparaît-elle dans `Endpoints` ? Recommencez les appels de la partie 2 : répond-il un jour ?

## 4. Le Service survit aux pods

```bash
kubectl delete pod -l type=back-end
kubectl get pods -o wide
kubectl get service back-end
```

Les pods ont de nouvelles IP. Et la `CLUSTER-IP` du Service ?

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
```

## Ce qu'il faut retenir

- Un Service donne une IP virtuelle stable devant des pods dont l'IP change.
- ClusterIP, le type par défaut, n'est joignable que depuis l'intérieur du cluster.
- Le Service répartit les requêtes entre les pods sélectionnés par ses labels.
- Seuls les pods `READY` reçoivent du trafic : c'est la readinessProbe qui en décide.
