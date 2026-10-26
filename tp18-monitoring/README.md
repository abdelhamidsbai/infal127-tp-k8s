# TP 18 — Monitoring (optionnel)

**Durée : 15 minutes.** L'installation de la partie 2 est lourde (1 à 2 Go de mémoire) : fermez les autres TP avant de commencer.

## 1. Avant tout outil

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -15
kubectl top nodes
kubectl top pods -A --sort-by=memory | head -10
```

1. Quels sont les derniers événements du cluster ?
2. Quel nœud est le plus chargé ? Quel pod consomme le plus de mémoire ?

## 2. kube-prometheus-stack

Un seul chart Helm installe Prometheus, Grafana, Alertmanager, l'opérateur Prometheus et ses CRD :

```bash
helm repo add prom https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prom/kube-prometheus-stack -n monitoring --create-namespace
kubectl get pods -n monitoring -w        # 2 à 3 minutes, puis Ctrl+C
kubectl get crd | grep monitoring.coreos.com
```

Repérez la CRD `servicemonitors` : c'est elle qui dit à Prometheus quoi collecter.

## 3. Grafana

Récupérez le mot de passe de l'utilisateur `admin`, puis ouvrez Grafana :

```bash
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 --decode; echo
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Ouvrez le port 3000 de l'onglet **PORTS**, connectez-vous, puis ouvrez **Dashboards** → **Kubernetes / Compute Resources / Cluster**.

Retrouvez-vous les chiffres de `kubectl top` ?

## Nettoyage

```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

## Ce qu'il faut retenir

- Trois signaux : les métriques (Prometheus), les logs (Loki, Elasticsearch), les traces (OpenTelemetry, Tempo).
- Avant tout outil : `kubectl get events` et `kubectl top`.
- kube-prometheus-stack : un chart Helm qui installe un opérateur et ses CRD. Tout ce qu'on a vu se rejoint ici.
