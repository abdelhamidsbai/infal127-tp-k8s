# TP 0 — La course au cluster

**Objectif : 20 minutes.** En binôme, chacun dans son codespace, entraide autorisée dans le binôme. Gagne le premier binôme dont les deux écrans affichent « Welcome to nginx! ».

## 1. Créer le cluster

```bash
k3d cluster create cesi --agents 2
kubectl get nodes
```

Vous obtenez 3 nœuds : `k3d-cesi-server-0` (le control plane) et deux workers, `k3d-cesi-agent-0` et `k3d-cesi-agent-1`. Tous doivent être en `STATUS: Ready`. Pas encore ? Attendez quelques secondes et relancez.

## 2. Déployer un premier serveur web

```bash
kubectl create deployment web --image=nginx
kubectl get pods        # relancez jusqu'à voir Running
```

## 3. L'ouvrir dans le navigateur

```bash
kubectl port-forward deploy/web 8080:80
```

Ouvrez l'onglet **PORTS** en bas de VS Code, puis cliquez sur l'icône 🌐 de la ligne 8080. La page doit afficher **Welcome to nginx!**

Laissez la commande tourner tant que vous consultez la page. `Ctrl+C` pour l'arrêter.

## Bonus

```bash
kubectl get pods -A
```

Que reconnaissez-vous dans cette liste ? Faites le lien avec les « batteries incluses » de k3s.

```bash
kubectl cluster-info
kubectl config get-contexts
```

À quel cluster votre `kubectl` parle-t-il ? Où est rangée cette information ?

## Bloqué ?

Levez la main : on teste aussi le réseau de l'école. Si le codespace ne démarre pas du tout, on bascule sur [Killercoda](https://killercoda.com/playgrounds/scenario/kubernetes).

## Nettoyage

```bash
kubectl delete deployment web
```

Gardez le cluster `cesi` : il sert pour tous les TP suivants.
