#!/usr/bin/env bash
# Rejoue chaque TP comme un étudiant, sur un cluster k3d à 3 nœuds.
# Les fichiers modifiés par les étudiants le sont sur une copie, jamais dans le dépôt.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export RAPPORT="$ROOT/rapport.md" JOURNAL="$ROOT/journal.log"
: > "$RAPPORT"; : > "$JOURNAL"
source "$ROOT/tests/lib.sh"
WORK=$(mktemp -d)
cp -r "$ROOT"/tp* "$WORK"/
DEBUT=$SECONDS

echo "# Rapport de simulation des TP" >> "$RAPPORT"
echo "" >> "$RAPPORT"
echo "k3d $(k3d version | head -1 | awk '{print $3}'), $(kubectl version --client | head -1), $(helm version --short)" >> "$RAPPORT"

chrono() { echo "_Durée de la simulation : $(( (SECONDS-T0) ))s_" >> "$RAPPORT"; }

#######################################################################
T0=$SECONDS; tp "TP 0 — La course au cluster"
check "création du cluster à 3 nœuds" "k3d cluster create cesi --agents 2 --wait"
check "3 nœuds Ready" "kubectl wait --for=condition=Ready node --all --timeout=120s && [ \$(kubectl get nodes --no-headers | wc -l) -eq 3 ]"
kubectl create deployment web --image=nginx >/dev/null
check "le deployment web démarre" "kubectl rollout status deploy/web --timeout=120s"
pf deploy/web 8080:80
check "port-forward : Welcome to nginx!" "curl -s localhost:8080 | grep -q 'Welcome to nginx!'"
pf_stop
check "bonus : kubectl get pods -A" "kubectl get pods -A"
check "bonus : cluster-info et contextes" "kubectl cluster-info && kubectl config get-contexts | grep -q k3d-cesi"
kubectl delete deployment web >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 1 — Pods et YAML"; cd "$WORK/tp01-pod"
kubectl run nginx --image=nginx >/dev/null
check "kubectl run : pod Running" "kubectl wait --for=condition=Ready pod/nginx --timeout=90s"
kubectl describe pod nginx | sed -n '/^Events:/,$p' | tee -a "$JOURNAL" >/dev/null
check "describe : section Events (Scheduled, Pulled, Started)" "kubectl describe pod nginx | sed -n '/^Events:/,\$p' | grep -q Scheduled && kubectl describe pod nginx | sed -n '/^Events:/,\$p' | grep -qi started"
kubectl delete pod nginx --wait >/dev/null
cat > pod-definition.yml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
    type: front-end
spec:
  containers:
  - name: nginx-container
    image: nginx
EOF
check "apply pod-definition.yml" "kubectl apply -f pod-definition.yml && kubectl wait --for=condition=Ready pod/myapp-pod --timeout=60s"
UID1=$(kubectl get pod myapp-pod -o jsonpath='{.metadata.uid}')
sed -i 's/    type: front-end/    type: front-end\n    env: dev/' pod-definition.yml
check "ajout du label env: dev sans recréer le pod" "kubectl apply -f pod-definition.yml && [ \"\$(kubectl get pod myapp-pod -o jsonpath='{.metadata.uid}')\" = '$UID1' ] && kubectl get pod myapp-pod --show-labels | grep -q env=dev"
check "kubectl explain pod.spec.containers" "kubectl explain pod.spec.containers | grep -q DESCRIPTION"
sed 's/^    image: nginx$/\timage: nginx/' pod-definition.yml > tab.yml
check_fail "tabulation dans le YAML : refusé" "kubectl apply -f tab.yml"
sed 's/^  - name: nginx-container/    name: nginx-container/' pod-definition.yml > tiret.yml
check_fail "tiret manquant : refusé" "kubectl apply -f tiret.yml"
kubectl apply -f multi-container.yml >/dev/null
check "multi-conteneurs : READY 2/2" "kubectl wait --for=condition=Ready pod/web-et-sidecar --timeout=90s && kubectl get pod web-et-sidecar | grep -q '2/2'"
check "multi-conteneurs : une seule IP" "[ \$(kubectl get pod web-et-sidecar -o jsonpath='{.status.podIPs[*].ip}' | wc -w) -eq 1 ]"
kubectl delete -f pod-definition.yml >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 2 — Cycle de vie et sondes"; cd "$WORK/tp02-cycle-de-vie"
check "logs du sidecar : page de nginx via localhost" "sleep 6; kubectl logs web-et-sidecar -c sidecar | grep -q 'Welcome to nginx!'"
kubectl apply -f pod-image-introuvable.yml -f pod-qui-plante.yml >/dev/null
check "nginx:1.99 → ErrImagePull / ImagePullBackOff" "wait_for 90 \"attente pod-image-introuvable | grep -qE 'ErrImagePull|ImagePullBackOff'\""
check "describe donne la cause (image introuvable)" "kubectl describe pod pod-image-introuvable | grep -qiE 'not found|failed to pull'"
check "pod-qui-plante → Error / CrashLoopBackOff, redémarrages" "wait_for 90 \"[ \\\$(redemarrages pod-qui-plante) -ge 2 ]\" && kubectl get pod pod-qui-plante --no-headers | grep -qE 'CrashLoopBackOff|Error'"
check "logs donnent la cause (DB_HOST absente)" "kubectl logs pod-qui-plante | grep -q 'DB_HOST absente'"
kubectl delete -f pod-image-introuvable.yml -f pod-qui-plante.yml --wait >/dev/null
sed -i 's/nginx:1.99/nginx/' pod-image-introuvable.yml
sed -i 's/exit 1/sleep 3600/' pod-qui-plante.yml
kubectl apply -f pod-image-introuvable.yml -f pod-qui-plante.yml >/dev/null
check "les deux pods corrigés passent en Running" "kubectl wait --for=condition=Ready pod/pod-image-introuvable pod/pod-qui-plante --timeout=90s"
T=$SECONDS; kubectl delete -f pod-qui-plante.yml --wait >/dev/null; DUREE=$((SECONDS-T))
check "arrêt avec délai de grâce : ~30 s (mesuré : ${DUREE}s)" "[ $DUREE -ge 20 ]"
kubectl apply -f sonde-demo.yaml >/dev/null
check "liveness exec : RESTARTS ≥ 1 en moins de 120 s" "wait_for 120 \"[ \\\$(redemarrages sonde-demo) -ge 1 ]\""
check "describe : Liveness probe failed" "kubectl describe pod sonde-demo | grep -q 'Liveness probe failed'"
sed -e 's/name: sonde-demo/name: sonde-readiness/' -e 's/livenessProbe/readinessProbe/' sonde-demo.yaml > sonde-readiness.yaml
kubectl apply -f sonde-readiness.yaml >/dev/null
check "variante readiness : prêt au début" "wait_for 30 \"[ \\\"\\\$(pret sonde-readiness)\\\" = true ]\""
check "variante readiness : READY 0/1 après 30 s, sans redémarrage" "wait_for 60 \"[ \\\"\\\$(pret sonde-readiness)\\\" = false ]\" && [ \$(redemarrages sonde-readiness) -eq 0 ]"
kubectl apply -f sondes-nginx.yml >/dev/null
check "sondes cassées : jamais prête et redémarre" "wait_for 90 \"[ \\\$(redemarrages sondes-nginx) -ge 1 ]\" && [ \"\$(pret sondes-nginx)\" = false ]"
kubectl delete -f sondes-nginx.yml --wait >/dev/null
sed -i -e 's/port: 8080/port: 80/' -e 's#path: /healthz#path: /#' sondes-nginx.yml
kubectl apply -f sondes-nginx.yml >/dev/null
check "sondes corrigées : 1/1 et 0 redémarrage après 40 s" "kubectl wait --for=condition=Ready pod/sondes-nginx --timeout=60s && sleep 40 && [ \$(redemarrages sondes-nginx) -eq 0 ]"
kubectl delete -f . --ignore-not-found --wait=false >/dev/null; kubectl delete pod web-et-sidecar --wait=false >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 3 — ReplicaSet"; cd "$WORK/tp03-replicaset"
kubectl create -f replicaset-definition.yml >/dev/null
check "3 pods créés" "wait_for 90 \"[ \\\$(kubectl get pods -l type=front-end --field-selector=status.phase=Running --no-headers | wc -l) -eq 3 ]\""
check "pods répartis sur plusieurs nœuds" "[ \$(kubectl get pods -l type=front-end -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | wc -l) -ge 2 ]"
P=$(kubectl get pods -l type=front-end -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$P" --wait=false >/dev/null
check "auto-guérison : un pod remplace celui supprimé" "wait_for 60 '! kubectl get pod $P' && wait_for 60 \"[ \\\$(kubectl get rs myapp-replicaset -o jsonpath='{.status.readyReplicas}') -eq 3 ]\""
check "scale rs --replicas=5" "kubectl scale rs myapp-replicaset --replicas=5 && wait_for 60 \"[ \\\$(kubectl get rs myapp-replicaset -o jsonpath='{.status.readyReplicas}') -eq 5 ]\""
check "scale -f --replicas=6" "kubectl scale --replicas=6 -f replicaset-definition.yml && wait_for 60 \"[ \\\$(kubectl get rs myapp-replicaset -o jsonpath='{.status.readyReplicas}') -eq 6 ]\""
sed -i 's/replicas: 3/replicas: 2/' replicaset-definition.yml
check "replace -f avec replicas: 2" "kubectl replace -f replicaset-definition.yml && wait_for 60 \"[ \\\$(kubectl get pods -l type=front-end --no-headers | grep -vc Terminating) -eq 2 ]\""
kubectl apply -f pod-intrus.yml >/dev/null
check "le pod intrus est supprimé par le ReplicaSet" "sleep 8; ! kubectl get pod intrus --no-headers 2>/dev/null | grep -v Terminating | grep -q . && [ \$(kubectl get pods -l type=front-end --no-headers | grep -vc Terminating) -eq 2 ]"
check_fail "replicaset-casse refusé (selector ≠ labels)" "kubectl create -f replicaset-casse.yml"
sed -i 's/type: backend/type: back-end/' replicaset-casse.yml
check "replicaset-casse corrigé accepté" "kubectl create -f replicaset-casse.yml"
kubectl delete rs myapp-replicaset >/dev/null; kubectl delete -f replicaset-casse.yml --ignore-not-found >/dev/null
check "supprimer le ReplicaSet supprime ses pods" "wait_for 60 \"[ \\\$(kubectl get pods -l type=front-end --no-headers 2>/dev/null | wc -l) -eq 0 ]\""
chrono

#######################################################################
T0=$SECONDS; tp "TP 4 — Deployment"; cd "$WORK/tp04-deployment"
kubectl create -f deployment-definition.yml >/dev/null
check "deployment nginx:1.26 prêt (3/3)" "kubectl rollout status deployment/myapp-deployment --timeout=120s"
check "kubectl get all : deployment, rs, pods" "kubectl get all | grep -q replicaset.apps/myapp-deployment"
sed -i 's/nginx:1.26/nginx:1.27/' deployment-definition.yml
check "mise à jour déclarative vers 1.27" "kubectl apply -f deployment-definition.yml && kubectl rollout status deployment/myapp-deployment --timeout=120s"
kubectl annotate deployment/myapp-deployment kubernetes.io/change-cause="passage en nginx 1.27" >/dev/null
check "2 ReplicaSets, l'ancien à 0" "[ \$(kubectl get rs -l app=myapp --no-headers | wc -l) -eq 2 ]"
check "rollout history affiche la change-cause" "kubectl rollout history deployment/myapp-deployment | grep -q 'passage en nginx 1.27'"
check "set image vers 1.28" "kubectl set image deployment/myapp-deployment nginx=nginx:1.28 && kubectl rollout status deployment/myapp-deployment --timeout=120s"
kubectl annotate deployment/myapp-deployment kubernetes.io/change-cause="passage en nginx 1.28" --overwrite >/dev/null
kubectl set image deployment/myapp-deployment nginx=nginx:1.99 >/dev/null
check "image 1.99 : la mise à jour bloque, les 3 anciens pods restent prêts" "sleep 30; [ \$(kubectl get deploy myapp-deployment -o jsonpath='{.status.readyReplicas}') -eq 3 ] && kubectl get pods -l app=myapp | grep -qE 'ErrImagePull|ImagePullBackOff'"
check "rollout undo : retour à nginx:1.28" "kubectl rollout undo deployment/myapp-deployment && kubectl rollout status deployment/myapp-deployment --timeout=120s && kubectl get deploy myapp-deployment -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q 'nginx:1.28'"
kubectl apply -f deployment-sans-coupure.yml >/dev/null
check "deployment sans coupure v1 prêt" "kubectl rollout status deployment/myapp --timeout=120s"
kubectl apply -f deployment-sans-coupure-v2.yml >/dev/null
check "v2 jamais prête : 1 pod v2 non prêt, 3 pods v1 prêts" "sleep 40; [ \$(kubectl get pods -l app=myapp-v,version=v2 --no-headers | wc -l) -eq 1 ] && [ \$(kubectl get pods -l app=myapp-v,version=v1 -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | grep -c true) -eq 3 ] && [ \"\$(kubectl get pods -l app=myapp-v,version=v2 -o jsonpath='{.items[0].status.containerStatuses[0].ready}')\" = false ]"
check "rollout undo répare" "kubectl rollout undo deployment/myapp && kubectl rollout status deployment/myapp --timeout=90s"
kubectl delete -f deployment-definition.yml -f deployment-sans-coupure.yml >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 5 — DaemonSet, namespaces et NodePort"; cd "$WORK/tp05-namespaces-nodeport"
kubectl apply -f daemonset.yaml >/dev/null
check "DaemonSet : un pod log-agent par nœud (3)" "kubectl rollout status ds/log-agent -n kube-system --timeout=150s && [ \$(kubectl get pods -n kube-system -l app=log-agent --no-headers | wc -l) -eq 3 ]"
check "k3d node create extra" "k3d node create extra --cluster cesi --wait && kubectl wait --for=condition=Ready node/k3d-extra-0 --timeout=120s"
check "le 4e nœud reçoit son pod log-agent" "wait_for 120 \"[ \\\$(kubectl get pods -n kube-system -l app=log-agent --field-selector=status.phase=Running --no-headers | wc -l) -eq 4 ]\""
check "suppression du nœud extra" "k3d node delete k3d-extra-0 && kubectl delete node k3d-extra-0 --ignore-not-found && [ \$(kubectl get nodes --no-headers | wc -l) -eq 3 ]"
kubectl delete -f daemonset.yaml >/dev/null
check "kube-system contient coredns, traefik, local-path, metrics-server" "kubectl get pods -n kube-system | grep -q coredns && kubectl get pods -n kube-system | grep -q traefik && kubectl get pods -n kube-system | grep -q local-path && kubectl get pods -n kube-system | grep -q metrics-server"
check "namespace team1 et deux pods dedans" "kubectl create -f namespace-definition.yml && kubectl create -f pod-definition.yml --namespace=team1 && kubectl create -f pod-team1.yml && kubectl wait --for=condition=Ready pod --all -n team1 --timeout=90s"
check "kubectl get pods (default) n'affiche pas les pods de team1" "! kubectl get pods --no-headers 2>/dev/null | grep -q myapp-pod"
check "set-context --namespace=team1 puis retour" "kubectl config set-context --current --namespace=team1 && kubectl get pods --no-headers | grep -q myapp-pod && kubectl config set-context --current --namespace=default"
IPPOD=$(kubectl get pod myapp-pod -n team1 -o jsonpath='{.status.podIP}')
check "réseau plat : un pod de default joint l'IP d'un pod de team1" "tmp_pod default -- wget -qO- -T 5 http://$IPPOD | grep -q 'Welcome to nginx'"
kubectl apply -f myapp.yml -f service-definition.yml >/dev/null
kubectl rollout status deploy/myapp --timeout=120s >/dev/null
for IP in $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'); do
  check "NodePort 30008 répond sur le nœud $IP" "wait_for 30 \"curl -s -m 5 http://$IP:30008 | grep -q 'Welcome to nginx'\""
done
UNIP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
sed -i 's/targetPort: 80/targetPort: 8080/' service-definition.yml; kubectl apply -f service-definition.yml >/dev/null
check_fail "targetPort 8080 : plus de réponse" "sleep 3; curl -s -m 5 http://$UNIP:30008 | grep -q 'Welcome to nginx'"
sed -i 's/targetPort: 8080/targetPort: 80/' service-definition.yml; kubectl apply -f service-definition.yml >/dev/null
check "targetPort 80 rétabli" "sleep 3; curl -s -m 5 http://$UNIP:30008 | grep -q 'Welcome to nginx'"
kubectl delete namespace team1 --wait=false >/dev/null; kubectl delete -f myapp.yml -f service-definition.yml >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 6 — ClusterIP"; cd "$WORK/tp06-clusterip"
kubectl apply -f back-end.yml -f service-definition.yml >/dev/null
check "3 pods whoami prêts" "kubectl rollout status deploy/back-end --timeout=120s"
check "Service back-end : ClusterIP, 3 endpoints" "kubectl get svc back-end | grep -q ClusterIP && kubectl describe svc back-end | grep -E '^Endpoints' | grep -o ':80' | wc -l | grep -q 3"
CIP=$(kubectl get svc back-end -o jsonpath='{.spec.clusterIP}')
check "répartition : au moins 2 pods différents répondent sur 6 appels" "tmp_pod default -- sh -c 'for i in 1 2 3 4 5 6; do wget -qO- -T 3 http://$CIP | grep Hostname; done' | sort -u | wc -l | grep -qE '^[2-9]'"
kubectl apply -f back-end-pas-pret.yml >/dev/null
check "le pod pas prêt n'est pas READY" "sleep 20; [ \"\$(pret back-end-pas-pret)\" = false ]"
check "le pod pas prêt est hors des Endpoints" "kubectl get endpoints back-end -o jsonpath='{.subsets[*].notReadyAddresses[*].targetRef.name}' | grep -q back-end-pas-pret && ! kubectl get endpoints back-end -o jsonpath='{.subsets[*].addresses[*].targetRef.name}' | grep -q back-end-pas-pret"
check "il ne répond jamais (12 appels)" "! tmp_pod default -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10 11 12; do wget -qO- -T 3 http://$CIP | grep Hostname; done' | grep -q back-end-pas-pret"
kubectl delete pod -l type=back-end >/dev/null
check "après suppression des pods, la CLUSTER-IP ne change pas" "kubectl rollout status deploy/back-end --timeout=90s && [ \"\$(kubectl get svc back-end -o jsonpath='{.spec.clusterIP}')\" = '$CIP' ]"
kubectl delete -f . --ignore-not-found >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 7 — LoadBalancer et DNS"; cd "$WORK/tp07-loadbalancer-dns"
kubectl apply -f myapp.yml -f service-lb.yml >/dev/null
kubectl rollout status deploy/myapp --timeout=120s >/dev/null
check "LoadBalancer : EXTERNAL-IP attribuée" "wait_for 90 \"kubectl get svc myapp-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q .\""
LBIP=$(kubectl get svc myapp-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
check "EXTERNAL-IP = IP de nœuds" "kubectl get nodes -o wide | grep -q '$LBIP'"
T=$SECONDS
check "curl EXTERNAL-IP:8080 (après démarrage des svclb)" "wait_for 60 \"curl -s -m 5 http://$LBIP:8080 | grep -q 'Welcome to nginx'\""
log "    LoadBalancer joignable après ~$((SECONDS-T))s"
check "le Service LB a aussi un NodePort et une ClusterIP" "kubectl get svc myapp-lb -o jsonpath='{.spec.ports[0].nodePort} {.spec.clusterIP}' | grep -qE '^[0-9]+ [0-9.]+$'"
kubectl apply -f dev.yml >/dev/null
kubectl rollout status deploy/mysql -n dev --timeout=120s >/dev/null
check_fail "DNS depuis default : nom court mysql-service introuvable" "tmp_pod default -- nslookup mysql-service 2>&1 | grep -A2 'Name:' | grep -q mysql-service"
check "DNS depuis default : mysql-service.dev résolu" "tmp_pod default -- nslookup mysql-service.dev 2>&1 | grep -q 'Address.*10\\.43\\.'"
check "DNS depuis default : FQDN résolu" "tmp_pod default -- nslookup mysql-service.dev.svc.cluster.local 2>&1 | grep -q 'Address.*10\\.43\\.'"
check "wget http://mysql-service.dev" "tmp_pod default -- wget -qO- -T 5 http://mysql-service.dev | grep -q Hostname"
check "DNS depuis dev : nom court résolu" "tmp_pod dev -- nslookup mysql-service 2>&1 | grep -q 'Address.*10\\.43\\.'"
check "le DNS renvoie l'IP du Service" "SVC=\$(kubectl get svc mysql-service -n dev -o jsonpath='{.spec.clusterIP}'); tmp_pod default -- nslookup mysql-service.dev.svc.cluster.local | grep -q \"\$SVC\""
kubectl delete -f . --ignore-not-found >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 8 — ConfigMap"; cd "$WORK/tp08-configmap"
kubectl apply -f pod-color.yml >/dev/null
check "webapp-color démarre (image kodekloud/webapp-color)" "kubectl wait --for=condition=Ready pod/webapp-color --timeout=120s"
pf pod/webapp-color 8080:8080
check "la page répond sur 8080" "curl -s -m 5 localhost:8080 > /tmp/color.html && [ -s /tmp/color.html ]"
log "    extrait de la page : $(grep -io 'background[^>]*' /tmp/color.html | head -2)"
pf_stop
check "create configmap app-config" "kubectl create configmap app-config --from-literal=APP_COLOR=blue --from-literal=APP_MODE=prod && kubectl describe configmap app-config | grep -q blue"
kubectl apply -f webapp.yml >/dev/null
check "webapp : APP_COLOR=blue depuis la ConfigMap" "kubectl rollout status deploy/webapp --timeout=120s && kubectl exec deploy/webapp -- printenv APP_COLOR | grep -qx blue"
kubectl apply -f pod-envfrom.yml >/dev/null
check "envFrom : APP_COLOR et APP_MODE dans les logs" "wait_for 60 \"kubectl logs env-check | grep -q APP_MODE=prod\" && kubectl logs env-check | grep -q APP_COLOR=blue"
kubectl apply -f pod-volume.yml >/dev/null
check "volume : /etc/app/APP_COLOR = blue" "kubectl wait --for=condition=Ready pod/config-volume --timeout=60s && sleep 6 && kubectl logs config-volume | grep -q 'APP_COLOR=blue'"
kubectl apply -f config-map.yaml >/dev/null 2>&1
check "volume : passe à green sans redémarrage (≤ 120 s)" "wait_for 120 \"kubectl logs config-volume --tail=1 | grep -q green\" && [ \$(redemarrages config-volume) -eq 0 ]"
check "webapp : la variable reste blue avant le restart" "kubectl exec deploy/webapp -- printenv APP_COLOR | grep -qx blue"
check "rollout restart : la variable passe à green" "kubectl rollout restart deployment/webapp && kubectl rollout status deploy/webapp --timeout=120s && kubectl exec deploy/webapp -- printenv APP_COLOR | grep -qx green"
kubectl delete -f . --ignore-not-found --wait=false >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 9 — Secret"; cd "$WORK/tp09-secret"
check "create secret app-secret" "kubectl create secret generic app-secret --from-literal=DB_Host=mysql --from-literal=DB_User=root --from-literal=DB_Password=paswrd"
check "describe masque les valeurs" "! kubectl describe secret app-secret | grep -q paswrd"
check "-o yaml montre le base64, décodable" "kubectl get secret app-secret -o yaml | grep -q cGFzd3Jk && echo -n cGFzd3Jk | base64 --decode | grep -qx paswrd"
sed -i -e "s#DB_Host: À_COMPLÉTER#DB_Host: $(echo -n postgres | base64)#" -e "s#DB_User: À_COMPLÉTER#DB_User: $(echo -n admin | base64)#" -e "s#DB_Password: À_COMPLÉTER#DB_Password: $(echo -n 'S3cr3t!' | base64)#" secret-data.yaml
check "secret-data.yaml complété accepté" "kubectl apply -f secret-data.yaml && kubectl get secret db-secret -o jsonpath='{.data.DB_Password}' | base64 --decode | grep -qx 'S3cr3t!'"
check "stringData : encodé par Kubernetes" "kubectl apply -f secret-stringdata.yaml && kubectl get secret db-secret-clair -o jsonpath='{.data.DB_User}' | grep -qx YWRtaW4="
kubectl apply -f pod-secret-env.yml -f pod-secret-volume.yml >/dev/null
check "envFrom secret : valeurs décodées dans le conteneur" "wait_for 60 \"kubectl logs secret-env | grep -q DB_Password=paswrd\""
check "volume secret : 3 fichiers, tmpfs" "wait_for 60 \"kubectl logs secret-volume | grep -q 'DB_Password = paswrd'\" && kubectl logs secret-volume | grep -q tmpfs && kubectl logs secret-volume | grep -q DB_User"
kubectl delete -f . --ignore-not-found --wait=false >/dev/null; kubectl delete secret app-secret >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 10 — Ingress"; cd "$WORK/tp10-ingress"
kubectl apply -f apps.yml >/dev/null
check "wear et watch démarrent (image hashicorp/http-echo)" "kubectl rollout status deploy/wear --timeout=120s && kubectl rollout status deploy/watch --timeout=120s"
check "IngressClass traefik présente" "kubectl get ingressclass | grep -q traefik"
IP=$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
check "IP de Traefik récupérée ($IP)" "[ -n '$IP' ]"
kubectl apply -f ingress-wear.yaml >/dev/null
check "defaultBackend : / et /nimporte-quoi → wear" "wait_for 30 \"curl -s -m 5 http://$IP/ | grep -q wear\" && curl -s -m 5 http://$IP/nimporte-quoi | grep -q wear"
kubectl delete -f ingress-wear.yaml >/dev/null; kubectl apply -f ingress-wear-watch.yaml >/dev/null
check "règles par chemin : /wear et /watch" "wait_for 30 \"curl -s -m 5 http://$IP/watch | grep -q watch\" && curl -s -m 5 http://$IP/wear | grep -q wear"
check "/autre → 404" "curl -s -m 5 -o /dev/null -w '%{http_code}' http://$IP/autre | grep -q 404"
check "describe ingress : IP des pods entre parenthèses" "kubectl describe ingress ingress-wear-watch | grep -E 'wear-service:80 \\([0-9.]+:5678\\)'"
pf svc/traefik 8081:80 kube-system
check "port-forward Traefik 8081 : /wear" "curl -s -m 5 localhost:8081/wear | grep -q wear"
pf_stop
kubectl apply -f ingress-hosts.yaml >/dev/null
check "règles par hôte : wear et watch" "wait_for 30 \"curl -s -m 5 -H 'Host: watch.my-online-store.com' http://$IP/ | grep -q watch\" && curl -s -m 5 -H 'Host: wear.my-online-store.com' http://$IP/ | grep -q wear"
check "sans Host connu → 404" "curl -s -m 5 -o /dev/null -w '%{http_code}' http://$IP/ | grep -q 404"
check "bonus TLS : certificat et secret" "openssl req -x509 -nodes -newkey rsa:2048 -days 30 -keyout wear.key -out wear.crt -subj '/CN=wear.my-online-store.com' 2>/dev/null && kubectl create secret tls wear-tls --cert=wear.crt --key=wear.key"
kubectl apply -f ingress-tls.yaml >/dev/null
check "bonus TLS : https://wear.my-online-store.com" "wait_for 30 \"curl -sk -m 5 --resolve wear.my-online-store.com:443:$IP https://wear.my-online-store.com/ | grep -q wear\""
log "    certificat servi : $(echo | openssl s_client -connect $IP:443 -servername wear.my-online-store.com 2>/dev/null | openssl x509 -noout -subject 2>&1)"
check "bonus TLS : le certificat servi est le nôtre (≤ 30 s)" "wait_for 30 \"curl -vk -m 5 --resolve wear.my-online-store.com:443:$IP https://wear.my-online-store.com/ 2>&1 | grep subject | grep -q 'wear.my-online-store.com'\""
kubectl delete -f . --ignore-not-found >/dev/null; kubectl delete secret wear-tls --ignore-not-found >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 11 — Volumes"; cd "$WORK/tp11-volumes"
kubectl apply -f random-number.yml >/dev/null
check "hostPath type: Directory → échec de montage" "wait_for 60 \"kubectl describe pod random-number-generator | grep -qi 'hostPath type check failed'\""
kubectl delete -f random-number.yml --wait >/dev/null
sed -i 's/type: Directory$/type: DirectoryOrCreate/' random-number.yml
NODES=""
for i in 1 2 3; do
  kubectl apply -f random-number.yml >/dev/null
  wait_for 60 "phase random-number-generator | grep -q Succeeded"
  NODES="$NODES $(kubectl get pod random-number-generator -o jsonpath='{.spec.nodeName}')"
  kubectl delete -f random-number.yml --wait >/dev/null
done
log "    nœuds des 3 exécutions : $NODES"
kubectl apply -f lecteur.yml >/dev/null
check "DaemonSet lecteur sur 3 nœuds" "kubectl rollout status ds/lecteur --timeout=120s"
sleep 5
log "$(kubectl logs -l app=lecteur --prefix 2>&1)"
check "le fichier n'existe que sur les nœuds où le pod a tourné" "kubectl logs -l app=lecteur --prefix | grep -q 'pas de fichier' || [ \$(echo $NODES | tr ' ' '\n' | sort -u | wc -l) -eq 3 ]"
kubectl delete -f lecteur.yml >/dev/null
check "PV pv-vol1 Available" "kubectl apply -f pv-definition.yaml && kubectl get pv pv-vol1 | grep -q Available"
check "PVC myclaim Bound à pv-vol1 (1Gi)" "kubectl apply -f pvc-definition.yaml && wait_for 30 \"kubectl get pvc myclaim | grep -q Bound\" && kubectl get pvc myclaim | grep -q 'pv-vol1.*1Gi'"
check "pvc-trop-gros reste Pending" "kubectl apply -f pvc-trop-gros.yaml && sleep 5 && kubectl get pvc pvc-trop-gros | grep -q Pending"
check "delete myclaim → PV Released (Retain)" "kubectl delete pvc myclaim && wait_for 30 \"kubectl get pv pv-vol1 | grep -q Released\" && kubectl get pv pv-vol1 | grep -q Retain"
check "StorageClass local-path par défaut" "kubectl get storageclass | grep -q 'local-path (default)'"
check "data-pvc Pending (WaitForFirstConsumer)" "kubectl apply -f storageclass.yaml && sleep 5 && kubectl get pvc data-pvc | grep -q Pending"
kubectl apply -f pod-journal.yml >/dev/null
check "pod journal : PVC Bound, PV créé automatiquement" "kubectl wait --for=condition=Ready pod/journal --timeout=120s && kubectl get pvc data-pvc | grep -q Bound && kubectl get pv | grep -q default/data-pvc"
kubectl delete -f pod-journal.yml --wait >/dev/null; kubectl apply -f pod-journal.yml >/dev/null
check "les données survivent au pod" "kubectl wait --for=condition=Ready pod/journal --timeout=120s && sleep 2 && kubectl logs journal | grep -q 'démarrage du pod'"
kubectl delete -f . --ignore-not-found >/dev/null
check "reclaimPolicy Delete : le PV de data-pvc disparaît" "wait_for 60 \"! kubectl get pv | grep -q default/data-pvc\""
chrono

#######################################################################
T0=$SECONDS; tp "TP 12 — ServiceAccount et RBAC"; cd "$WORK/tp12-rbac"
kubectl create serviceaccount dashboard-sa >/dev/null
TOKEN=$(kubectl create token dashboard-sa --duration=1h)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
check "jeton créé (JWT)" "echo '$TOKEN' | grep -qE '^eyJ'"
check "appel API sans droit → 403 Forbidden" "curl -sk $APISERVER/api/v1/namespaces/default/pods --header 'Authorization: Bearer $TOKEN' | grep -q 'pods is forbidden'"
kubectl apply -f pod-dashboard.yml -f pod-sans-jeton.yml >/dev/null
kubectl wait --for=condition=Ready pod/dashboard pod/sans-jeton --timeout=90s >/dev/null
check "jeton monté dans le pod (ca.crt namespace token)" "kubectl exec dashboard -- ls /var/run/secrets/kubernetes.io/serviceaccount | grep -q token"
check "serviceAccountName = dashboard-sa" "kubectl get pod dashboard -o jsonpath='{.spec.serviceAccountName}' | grep -qx dashboard-sa"
check_fail "automountServiceAccountToken: false → pas de jeton" "kubectl exec sans-jeton -- ls /var/run/secrets/kubernetes.io/serviceaccount"
kubectl apply -f role-pod-reader.yaml >/dev/null
check "avec le Role : l'API liste les pods" "curl -sk $APISERVER/api/v1/namespaces/default/pods --header 'Authorization: Bearer $TOKEN' | grep -qE '\"name\": ?\"dashboard\"'"
check "can-i list pods → yes" "kubectl auth can-i list pods --as=system:serviceaccount:default:dashboard-sa | grep -qx yes"
check "can-i delete pods → no" "kubectl auth can-i delete pods --as=system:serviceaccount:default:dashboard-sa | grep -qx no"
check "can-i list pods -n kube-system → no" "kubectl auth can-i list pods -n kube-system --as=system:serviceaccount:default:dashboard-sa | grep -qx no"
python3 - <<'EOF'
p='stagiaire.yaml'; s=open(p).read()
s=s.replace('resources: ["À_COMPLÉTER"]','resources: ["pods"]').replace('verbs: ["À_COMPLÉTER", "À_COMPLÉTER"]','verbs: ["get", "list"]')
s=s.replace('- kind: User\n  name: À_COMPLÉTER','- kind: User\n  name: tom').replace('kind: Role\n  name: À_COMPLÉTER','kind: Role\n  name: view-only')
open(p,'w').write(s)
EOF
check "stagiaire.yaml complété accepté" "kubectl apply -f stagiaire.yaml"
check "tom : get pods -n dev → yes" "kubectl auth can-i get pods -n dev --as tom | grep -qx yes"
check "tom : list pods -n dev → yes" "kubectl auth can-i list pods -n dev --as tom | grep -qx yes"
check "tom : delete pods -n dev → no" "kubectl auth can-i delete pods -n dev --as tom | grep -qx no"
check "tom : get pods -n default → no" "kubectl auth can-i get pods -n default --as tom | grep -qx no"
check "tom : get secrets -n dev → no" "kubectl auth can-i get secrets -n dev --as tom | grep -qx no"
check "bonus : list nodes → no, puis yes avec un ClusterRole" "kubectl auth can-i list nodes --as tom | grep -qx no && kubectl create clusterrole node-reader --verb=get,list --resource=nodes && kubectl create clusterrolebinding tom-node-reader --clusterrole=node-reader --user=tom && kubectl auth can-i list nodes --as tom | grep -qx yes"
kubectl delete -f . --ignore-not-found --wait=false >/dev/null; kubectl delete serviceaccount dashboard-sa >/dev/null; kubectl delete clusterrole node-reader >/dev/null; kubectl delete clusterrolebinding tom-node-reader >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 13 — NetworkPolicy"; cd "$WORK/tp13-networkpolicy"
kubectl apply -f boutique.yml >/dev/null
check "boutique : 3 pods prêts" "kubectl wait --for=condition=Ready pod --all -n boutique --timeout=120s"
check "sans policy : front → api OK" "kubectl exec -n boutique front -- wget -qO- -T 3 http://api:8080 | grep -q Hostname"
check "sans policy : front → db OK" "kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432 | grep -q Hostname"
kubectl apply -f default-deny.yaml >/dev/null; sleep 5
check_fail "default-deny : front → api bloqué" "kubectl exec -n boutique front -- wget -qO- -T 3 http://api:8080"
check_fail "default-deny : front → db bloqué" "kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432"
kubectl apply -f api-from-front.yaml >/dev/null; sleep 5
check "api-from-front : front → api OK" "kubectl exec -n boutique front -- wget -qO- -T 3 http://api:8080 | grep -q Hostname"
check_fail "api-from-front : front → db toujours bloqué" "kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432"
sed -i -e '0,/matchLabels: {app: À_COMPLÉTER}/s//matchLabels: {app: db}/' -e 's/matchLabels: {app: À_COMPLÉTER}/matchLabels: {app: api}/' -e 's/port: À_COMPLÉTER/port: 5432/' db-from-api.yaml
kubectl apply -f db-from-api.yaml >/dev/null; sleep 5
kubectl run -n boutique test-api --image=busybox:1.37 --labels=app=api -- sleep 3600 >/dev/null
kubectl wait -n boutique --for=condition=Ready pod/test-api --timeout=60s >/dev/null
check "db-from-api : un pod app=api joint db" "kubectl exec -n boutique test-api -- wget -qO- -T 3 http://db:5432 | grep -q Hostname"
check_fail "db-from-api : front → db toujours bloqué" "kubectl exec -n boutique front -- wget -qO- -T 3 http://db:5432"
kubectl delete namespace boutique --wait=false >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 14 — Sécurité"; cd "$WORK/tp14-securite"
kubectl apply -f pod-root.yml >/dev/null
check "runAsNonRoot + image root → CreateContainerConfigError" "wait_for 60 \"attente pod-root | grep -q CreateContainerConfigError\" && kubectl describe pod pod-root | grep -qi 'runAsNonRoot'"
kubectl apply -f pod-securise.yml >/dev/null
check "pod-securise (nginx-unprivileged, lecture seule) Running" "kubectl wait --for=condition=Ready pod/pod-securise --timeout=120s"
check "id : uid=101, pas root" "kubectl exec pod-securise -- id | grep -q 'uid=101'"
check_fail "écriture dans /etc refusée" "kubectl exec pod-securise -- touch /etc/test"
check "écriture dans /tmp autorisée" "kubectl exec pod-securise -- touch /tmp/test"
pf pod/pod-securise 8090:8080
check "pod-securise sert bien la page nginx" "curl -s -m 5 localhost:8090 | grep -q 'Welcome to nginx'"
pf_stop
kubectl apply -f namespace-restricted.yaml >/dev/null
check_fail "PSA restricted : pod-root refusé" "kubectl apply -f pod-root.yml -n securise"
check "PSA restricted : pod-securise accepté et Running" "kubectl apply -f pod-securise.yml -n securise && kubectl wait --for=condition=Ready pod/pod-securise -n securise --timeout=120s"
check "Trivy : scan de nginx:1.27" "trivy image --quiet --severity CRITICAL nginx:1.27 > /tmp/trivy.txt; [ -s /tmp/trivy.txt ]"
log "$(grep -E 'Total:' /tmp/trivy.txt | head -3)"
check "Trivy config : remarques sur pod-root.yml" "trivy config --quiet . > /tmp/trivy-config.txt; grep -q pod-root.yml /tmp/trivy-config.txt"
kubectl delete -f pod-root.yml -f pod-securise.yml --ignore-not-found >/dev/null; kubectl delete namespace securise --wait=false >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 15 — Requests, limits et HPA"; cd "$WORK/tp15-ressources-hpa"
kubectl apply -f pod-gourmand.yml >/dev/null
check "10 CPU demandés → Pending, FailedScheduling Insufficient cpu" "sleep 8; phase gourmand | grep -q Pending && kubectl describe pod gourmand | grep -q 'Insufficient cpu'"
kubectl delete -f pod-gourmand.yml --wait >/dev/null; sed -i 's/cpu: "10"/cpu: "100m"/' pod-gourmand.yml; kubectl apply -f pod-gourmand.yml >/dev/null
check "100m → Running" "kubectl wait --for=condition=Ready pod/gourmand --timeout=90s"
kubectl apply -f pod-oom.yml >/dev/null
check "dépassement mémoire → OOMKilled (image polinux/stress)" "wait_for 120 \"kubectl get pod oom -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{.status.containerStatuses[0].state.terminated.reason}' | grep -q OOMKilled\""
kubectl apply -f api.yml >/dev/null
check "api (registry.k8s.io/hpa-example) prête" "kubectl rollout status deploy/api --timeout=150s"
check "kubectl top pods (metrics-server)" "wait_for 150 'kubectl top pods | grep -q api'"
kubectl apply -f hpa.yaml >/dev/null
check "HPA : TARGETS mesuré" "wait_for 120 \"kubectl get hpa api -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' | grep -qE '^[0-9]+$'\""
kubectl run load --image=busybox:1.37 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://api; done" >/dev/null
check "sous charge : REPLICAS > 1 en moins de 4 min" "wait_for 240 \"[ \\\$(kubectl get hpa api -o jsonpath='{.status.currentReplicas}') -gt 1 ]\""
log "    HPA : $(kubectl get hpa api --no-headers)"
kubectl delete pod load --wait=false >/dev/null
kubectl delete -f . --ignore-not-found --wait=false >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 16 — CRD"; cd "$WORK/tp16-crd"
check "CRD existantes : traefik.io et helm.cattle.io" "kubectl get crd | grep -q traefik.io && kubectl get crd | grep -q helm.cattle.io"
check "backup-crd.yaml accepté" "kubectl apply -f backup-crd.yaml && kubectl wait --for=condition=Established crd/backups.demo.cesi.fr --timeout=30s"
check "api-resources liste backups" "kubectl api-resources | grep -q backups"
check "db-nightly créé, colonnes Base et Planning" "kubectl apply -f db-nightly.yaml && kubectl get backups | grep -q 'db-nightly.*mysql'"
T=$SECONDS
check "kubectl explain backup.spec (délai de publication mesuré)" "wait_for 60 'kubectl explain backup.spec | grep -q database'"
log "    explain disponible après ~$((SECONDS-T))s"
check_fail "backup-invalide refusé par le schéma" "kubectl apply -f backup-invalide.yaml"
kubectl delete -f backup-crd.yaml >/dev/null
check_fail "CRD supprimée : plus de type backups" "kubectl get backups"
chrono

#######################################################################
T0=$SECONDS; tp "TP 17 — Helm"; cd "$WORK/tp17-helm"
check "helm repo add podinfo + search" "helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update && helm search repo podinfo | grep -q podinfo/podinfo"
check "helm show values : bloc ui" "helm show values podinfo/podinfo | grep -A4 '^ui:' | grep -q color"
check "install podinfo-dev et podinfo-prod" "helm install podinfo-dev podinfo/podinfo -n dev --create-namespace -f values-dev.yaml --wait --timeout 3m && helm install podinfo-prod podinfo/podinfo -n prod --create-namespace -f values-prod.yaml --wait --timeout 3m"
check "1 pod en dev, 3 en prod" "[ \$(kubectl get pods -n dev --no-headers | wc -l) -eq 1 ] && [ \$(kubectl get pods -n prod --no-headers | wc -l) -eq 3 ]"
pf svc/podinfo-prod 9898:9898 prod
check "port-forward 9898 : message PRODUCTION" "curl -s -m 5 localhost:9898 | grep -q 'PRODUCTION'"
pf_stop
check "upgrade --set ui.color : révision 2" "helm upgrade podinfo-prod podinfo/podinfo -n prod -f values-prod.yaml --set ui.color='#d9534f' --wait && helm history podinfo-prod -n prod | grep -c deployed | grep -q 1 && helm history podinfo-prod -n prod --max 5 | tail -1 | grep -q '^2'"
check "rollback 1 : crée la révision 3" "helm rollback podinfo-prod 1 -n prod --wait && helm history podinfo-prod -n prod | tail -1 | grep -q '^3'"
check "historique dans des Secrets owner=helm" "[ \$(kubectl get secrets -n prod -l owner=helm --no-headers | wc -l) -eq 3 ]"
check "helm create + lint + template" "helm create monchart >/dev/null && helm lint monchart && helm template mon-app ./monchart | grep -q 'kind: Deployment'"
sed -i 's/^replicaCount: 1/replicaCount: 2/' monchart/values.yaml
check "install du chart maison : 2 pods" "helm install mon-app ./monchart --wait --timeout 3m && [ \$(kubectl get pods -l app.kubernetes.io/instance=mon-app --no-headers | wc -l) -eq 2 ]"
check "bonus OCI : install depuis ghcr.io" "helm install demo oci://ghcr.io/stefanprodan/charts/podinfo -n demo --create-namespace --wait --timeout 3m"
check "nettoyage : uninstall (avec --ignore-not-found)" "helm uninstall podinfo-dev -n dev && helm uninstall podinfo-prod -n prod && helm uninstall mon-app && helm uninstall demo -n demo --ignore-not-found"
kubectl delete namespace dev prod demo --ignore-not-found --wait=false >/dev/null
chrono

#######################################################################
T0=$SECONDS; tp "TP 18 — Monitoring (optionnel)"; cd "$WORK/tp18-monitoring"
check "events triés et top nodes" "kubectl get events -A --sort-by=.lastTimestamp | tail -3 && kubectl top nodes"
MEM0=$(docker stats --no-stream --format '{{.MemUsage}}' | awk '{print $1}' | tr '\n' ' ')
check "install kube-prometheus-stack (≤ 8 min)" "helm repo add prom https://prometheus-community.github.io/helm-charts && helm repo update && helm install monitoring prom/kube-prometheus-stack -n monitoring --create-namespace --wait --timeout 8m"
check "CRD servicemonitors présente" "kubectl get crd | grep -q servicemonitors.monitoring.coreos.com"
check "mot de passe Grafana récupérable" "kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 --decode | grep -q ."
pf svc/monitoring-grafana 3000:80 monitoring
check "Grafana répond sur 3000" "curl -s -m 5 localhost:3000/api/health | grep -q ok"
pf_stop
log "    mémoire des nœuds k3d avant : $MEM0"
log "    mémoire des nœuds k3d avec la stack : $(docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | tr '\n' ';')"
echo "" >> "$RAPPORT"; echo "Mémoire des conteneurs k3d avec kube-prometheus-stack : $(docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | tr '\n' ';')" >> "$RAPPORT"
helm uninstall monitoring -n monitoring >/dev/null; kubectl delete namespace monitoring --wait=false >/dev/null
chrono

#######################################################################
{
  echo ""
  echo "---"
  echo "**Bilan : $OK vérifications réussies, $KO en échec.** Durée totale : $(( (SECONDS-DEBUT)/60 )) min."
} >> "$RAPPORT"
sed -i "3i\\
**$OK ✅ / $KO ❌**\\
" "$RAPPORT"
log "Bilan : $OK OK, $KO KO"
exit 0
