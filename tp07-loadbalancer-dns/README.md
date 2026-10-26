# TP 7 — LoadBalancer et DNS

**Durée : 15 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp07-loadbalancer-dns
```

## 1. Le Service LoadBalancer

Dans le cloud, un Service `LoadBalancer` commande un vrai répartiteur de charge. k3s fournit le sien, Klipper : il publie le port du Service sur chaque nœud.

```bash
kubectl apply -f myapp.yml -f service-lb.yml
kubectl get service myapp-lb
```

1. Que contient la colonne `EXTERNAL-IP` ? Comparez avec `kubectl get nodes -o wide`.
2. Le Service a-t-il aussi un NodePort ? Et une ClusterIP ?
3. Appelez-le : `curl http://<EXTERNAL-IP>:8080`. Pas de réponse ? Attendez quelques secondes : k3s démarre un petit pod `svclb` sur chaque nœud pour publier le port. Regardez-les avec `kubectl get pods -n kube-system | grep svclb`.

Le port est `8080` et non `80` : sur k3s, le port 80 des nœuds est déjà pris par Traefik, qui est lui-même… un Service LoadBalancer (`kubectl get svc -n kube-system traefik`).

## 2. Le DNS du cluster

Créez un namespace `dev` et un Service `mysql-service` dedans (un faux MySQL : un pod `whoami`) :

```bash
kubectl apply -f dev.yml
kubectl get service -n dev
```

Depuis le namespace `default`, testez les trois noms :

```bash
kubectl run -it --rm dnstest --image=busybox:1.37 --restart=Never -- sh
```

Dans le pod :

```sh
nslookup mysql-service
nslookup mysql-service.dev
nslookup mysql-service.dev.svc.cluster.local
wget -qO- http://mysql-service.dev | grep Hostname
exit
```

1. Pourquoi le nom court `mysql-service` ne fonctionne-t-il pas ici ?
2. Recommencez depuis le namespace `dev` (`kubectl run -n dev …`) : le nom court fonctionne-t-il ?
3. Quelle IP renvoie le DNS : celle d'un pod ou celle du Service ?

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
```

## Ce qu'il faut retenir

- `LoadBalancer` = `NodePort` + `ClusterIP` + une IP externe fournie par l'infrastructure (Klipper sur k3s).
- Chaque Service a un nom DNS, résolu par CoreDNS : on appelle un nom, jamais une IP.
- `service` dans le même namespace, `service.namespace` partout, `service.namespace.svc.cluster.local` en nom complet.
