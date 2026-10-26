# TP 10 — Ingress

**Durée : 25 minutes** (dont 5 minutes de bonus HTTPS). Placez-vous dans le dossier du TP :

```bash
cd tp10-ingress
```

Deux applications de la boutique en ligne : `wear` (vêtements) et `watch` (montres). Chacune répond simplement son nom.

## 1. Les applications et le contrôleur

```bash
kubectl apply -f apps.yml
kubectl get pods,services
kubectl get ingressclass
kubectl get service -n kube-system traefik
```

1. Les Services `wear-service` et `watch-service` sont de quel type ? Sont-ils joignables de l'extérieur ?
2. Quel contrôleur Ingress est installé ? Comment est-il lui-même exposé ?

Gardez l'adresse de Traefik dans une variable :

```bash
IP=$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $IP
```

## 2. Une seule application : `defaultBackend`

```bash
kubectl apply -f ingress-wear.yaml
kubectl get ingress
curl http://$IP/
curl http://$IP/nimporte-quoi
```

Pourquoi les deux URL répondent-elles `wear` ?

## 3. Deux applications : règles par chemin

```bash
kubectl delete -f ingress-wear.yaml
kubectl apply -f ingress-wear-watch.yaml
curl http://$IP/wear
curl http://$IP/watch
curl -i http://$IP/autre
kubectl describe ingress ingress-wear-watch
```

1. Que répond `/autre` ? Pourquoi ?
2. Dans `describe`, que voit-on entre parenthèses à côté de chaque Service ?

Pour voir le résultat dans le navigateur, dans un second terminal :

```bash
kubectl port-forward -n kube-system svc/traefik 8081:80
```

Puis ouvrez le port 8081 de l'onglet **PORTS** et ajoutez `/wear` ou `/watch` à l'URL.

## 4. Deux applications : règles par nom d'hôte

`ingress-hosts.yaml` porte le même nom (`ingress-wear-watch`) : il remplace la version par chemins.

```bash
kubectl apply -f ingress-hosts.yaml
curl -H "Host: wear.my-online-store.com" http://$IP/
curl -H "Host: watch.my-online-store.com" http://$IP/
curl -i http://$IP/
```

Les trois requêtes arrivent sur la même IP. Sur quoi Traefik se base-t-il pour choisir l'application ?

## 5. Bonus : HTTPS en trois lignes

Créez un certificat auto-signé et rangez-le dans un Secret de type TLS :

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 30 \
  -keyout wear.key -out wear.crt -subj "/CN=wear.my-online-store.com"
kubectl create secret tls wear-tls --cert=wear.crt --key=wear.key
```

Ajoutez le bloc `tls` (voir `ingress-tls.yaml`), puis testez :

```bash
kubectl apply -f ingress-tls.yaml
curl -k --resolve wear.my-online-store.com:443:$IP https://wear.my-online-store.com/
```

Vérifiez quel certificat Traefik présente :

```bash
curl -vk --resolve wear.my-online-store.com:443:$IP https://wear.my-online-store.com/ 2>&1 | grep subject
```

Vous voyez `TRAEFIK DEFAULT CERT` ? Traefik n'a pas encore chargé votre Secret : relancez après quelques secondes.

À quoi sert `-k` ? Qui crée ce certificat en production ?

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
kubectl delete secret wear-tls --ignore-not-found
rm -f wear.key wear.crt
```

## Ce qu'il faut retenir

- L'Ingress donne un seul point d'entrée HTTP(S) pour plusieurs Services ClusterIP.
- Il faut un contrôleur : k3s installe Traefik (`ingressClassName: traefik`).
- Les règles trient par chemin (`pathType` obligatoire) ou par nom d'hôte (en-tête `Host`).
- Aucune règle ne correspond : `defaultBackend`, sinon 404.
