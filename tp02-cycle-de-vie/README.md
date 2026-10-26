# TP 2 — Cycle de vie et sondes

**Durée : 25 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp02-cycle-de-vie
```

## 1. Lire ce que dit un conteneur

Le pod `web-et-sidecar` du TP 1 tourne toujours :

```bash
kubectl logs web-et-sidecar -c sidecar
```

Le sidecar reçoit bien la page de nginx via `localhost`. À quoi sert `-c sidecar` ?

## 2. Reconnaître les statuts

Appliquez les deux pods cassés et observez :

```bash
kubectl apply -f pod-image-introuvable.yml -f pod-qui-plante.yml
kubectl get pods -w        # 1 minute, puis Ctrl+C
```

Pour chacun des deux pods :

1. Quel `STATUS` voyez-vous ? Que veut-il dire ? (Pour `pod-qui-plante`, il alterne entre `Error` et `CrashLoopBackOff` : pourquoi, et pourquoi l'attente s'allonge-t-elle à chaque fois ?)
2. Trouvez la cause : `kubectl describe pod <nom>` pour l'un, `kubectl logs <nom>` pour l'autre. Pourquoi pas la même commande ?
3. Corrigez les deux fichiers, supprimez les pods (`kubectl delete -f <fichier>`), réappliquez-les et vérifiez qu'ils passent en `Running`. Pour `pod-qui-plante.yml`, on ne sait pas encore fournir une variable : simulez la correction en remplaçant `exit 1` par `sleep 3600`.

## 3. L'arrêt d'un pod

```bash
time kubectl delete -f pod-qui-plante.yml
```

La suppression prend une trentaine de secondes. Que se passe-t-il pendant ce temps ? Pourquoi le processus `sleep` ne s'arrête-t-il pas tout de suite ?

## 4. La sonde de vivacité (liveness)

Le fichier `sonde-demo.yaml` reprend la démo : le conteneur crée `/tmp/ok`, le supprime au bout de 30 secondes, et la sonde vérifie qu'il existe.

```bash
kubectl apply -f sonde-demo.yaml
kubectl get pod sonde-demo -w        # attendez au moins 1 minute
```

1. Au bout de combien de temps `RESTARTS` passe-t-il à 1 ? Retrouvez ce délai à partir de `initialDelaySeconds`, `periodSeconds` et `failureThreshold`.
2. Trouvez le message `Liveness probe failed` dans `kubectl describe pod sonde-demo`.

## 5. La sonde de disponibilité (readiness)

Copiez `sonde-demo.yaml` en `sonde-readiness.yaml`, changez le nom du pod en `sonde-readiness` et remplacez `livenessProbe` par `readinessProbe`.

```bash
kubectl apply -f sonde-readiness.yaml
kubectl get pod sonde-readiness -w
```

Que deviennent `READY` et `RESTARTS` après 30 secondes ? Quelle différence avec la liveness ?

## 6. À vous : deux sondes à réparer

Le fichier `sondes-nginx.yml` contient deux sondes `httpGet` mal configurées.

```bash
kubectl apply -f sondes-nginx.yml
kubectl get pod sondes-nginx -w
```

1. Pourquoi `READY` reste-t-il à `0/1` ?
2. Pourquoi `RESTARTS` augmente-t-il ?
3. Corrigez les deux sondes. Une sonde ne se modifie pas sur un pod existant : supprimez-le, puis réappliquez.

Le pod doit afficher `1/1` et ne plus redémarrer.

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
kubectl delete pod web-et-sidecar
```

## Ce qu'il faut retenir

- `ImagePullBackOff` : l'image n'existe pas, on lit `describe`. `CrashLoopBackOff` : l'appli plante, on lit `logs`.
- L'arrêt d'un pod : SIGTERM, 30 secondes de grâce, puis SIGKILL.
- Une liveness qui échoue redémarre le conteneur. Une readiness qui échoue le met en `READY 0/1`, sans rien redémarrer.
- Trois façons de tester : `httpGet`, `tcpSocket`, `exec`.
