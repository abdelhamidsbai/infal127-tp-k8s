# Fonctions communes aux scénarios de test des TP.
# Chaque vérification est notée dans rapport.md (✅ / ❌) ; le détail va dans journal.log.

RAPPORT="${RAPPORT:-$PWD/rapport.md}"
JOURNAL="${JOURNAL:-$PWD/journal.log}"
OK=0
KO=0

log() { echo "$*" | tee -a "$JOURNAL"; }

tp() {
  log ""
  log "## $1"
  echo "" >> "$RAPPORT"
  echo "## $1" >> "$RAPPORT"
  echo "" >> "$RAPPORT"
}

# check "description" 'commande shell qui doit réussir'
check() {
  local desc="$1" cmd="$2" out
  out=$(bash -c "$cmd" 2>&1)
  local rc=$?
  { echo "--- $desc"; echo "\$ $cmd"; echo "$out" | tail -20; } >> "$JOURNAL"
  if [ $rc -eq 0 ]; then
    OK=$((OK+1)); echo "- ✅ $desc" >> "$RAPPORT"; echo "  ✅ $desc"
  else
    KO=$((KO+1)); echo "- ❌ $desc" >> "$RAPPORT"
    echo '  ```' >> "$RAPPORT"; echo "$out" | tail -6 | sed 's/^/  /' >> "$RAPPORT"; echo '  ```' >> "$RAPPORT"
    echo "  ❌ $desc"; echo "$out" | tail -6
  fi
}

# check_fail "description" 'commande qui doit échouer'
check_fail() { check "$1" "! { $2 ; }"; }

# attendre jusqu'à N secondes qu'une commande réussisse
wait_for() {
  local timeout=$1; shift
  local end=$((SECONDS+timeout))
  until bash -c "$*" >/dev/null 2>&1; do
    [ $SECONDS -ge $end ] && return 1
    sleep 3
  done
}
export -f wait_for

# raccourcis jsonpath
phase()    { kubectl get pod "$@" -o jsonpath='{.status.phase}'; }
attente()  { kubectl get pod "$@" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'; }
pret()     { kubectl get pod "$@" -o jsonpath='{.status.containerStatuses[0].ready}'; }
redemarrages() { kubectl get pod "$@" -o jsonpath='{.status.containerStatuses[0].restartCount}'; }
export -f phase attente pret redemarrages

# port-forward en arrière-plan : pf <ressource> <port> [namespace]
pf() {
  local ns=${3:-default}
  kubectl port-forward -n "$ns" "$1" "$2" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 4
}
pf_stop() { kill "$PF_PID" 2>/dev/null; wait "$PF_PID" 2>/dev/null; }

# pod temporaire non interactif (équivalent de kubectl run -it --rm)
tmp_pod() {
  local ns=$1; shift
  kubectl run "tmp-$RANDOM" -n "$ns" --image=busybox:1.37 --restart=Never --rm -i --quiet "$@"
}
export -f tmp_pod
