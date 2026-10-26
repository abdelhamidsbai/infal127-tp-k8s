# TP 9 — Secret

**Durée : 15 minutes.** Placez-vous dans le dossier du TP :

```bash
cd tp09-secret
```

## 1. Créer un Secret (impératif)

```bash
kubectl create secret generic app-secret \
  --from-literal=DB_Host=mysql \
  --from-literal=DB_User=root \
  --from-literal=DB_Password=paswrd
kubectl get secrets
kubectl describe secret app-secret
```

`describe` affiche-t-il les valeurs ?

## 2. Base64 n'est pas du chiffrement

```bash
kubectl get secret app-secret -o yaml
echo -n 'cGFzd3Jk' | base64 --decode
```

Combien de temps faut-il pour retrouver le mot de passe ? Qui peut le faire ?

## 3. Créer un Secret (déclaratif)

Complétez `secret-data.yaml` : encodez chaque valeur, puis collez le résultat à la place des `À_COMPLÉTER`.

```bash
echo -n 'postgres' | base64
echo -n 'admin' | base64
echo -n 'S3cr3t!' | base64
kubectl apply -f secret-data.yaml
```

Pourquoi l'option `-n` est-elle indispensable ?

Ouvrez ensuite `secret-stringdata.yaml` : même Secret, mais en texte clair grâce à `stringData`. Appliquez-le et vérifiez avec `-o yaml` que Kubernetes a encodé les valeurs lui-même.

```bash
kubectl apply -f secret-stringdata.yaml
kubectl get secret db-secret-clair -o yaml
```

## 4. Injecter un Secret dans un pod

En variables d'environnement (`envFrom`) :

```bash
kubectl apply -f pod-secret-env.yml
kubectl logs secret-env
```

En fichiers (volume) :

```bash
kubectl apply -f pod-secret-volume.yml
kubectl logs secret-volume
```

1. Les valeurs arrivent-elles encodées ou décodées dans le conteneur ?
2. Combien de fichiers dans `/etc/secrets` ? Sur quel type de système de fichiers sont-ils montés ?

## Nettoyage

```bash
kubectl delete -f . --ignore-not-found
kubectl delete secret app-secret
```

## Ce qu'il faut retenir

- Un Secret sépare les mots de passe de la configuration, avec des droits d'accès à part.
- Dans `data`, les valeurs sont en base64 : un encodage, pas un chiffrement. `stringData` accepte le texte clair.
- `describe` masque les valeurs, `-o yaml` non.
- Dans Git, jamais de Secret en clair : Sealed Secrets, SOPS ou un coffre externe (Vault).
