#!/usr/bin/env bash
# Installe les outils du TP. Le cluster n'est PAS créé ici :
# c'est l'objet du TP 0 (« la course au cluster »).
set -euo pipefail

# k3d (version épinglée : même environnement pour tous les étudiants)
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.9.0 bash

# Trivy (TP 14)
curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# openssl (TP 10, certificat de test)
command -v openssl >/dev/null || { sudo apt-get update -qq && sudo apt-get install -y -qq openssl; }

# Confort shell : complétion kubectl et alias k
{
  echo 'source <(kubectl completion bash)'
  echo 'alias k=kubectl'
  echo 'complete -o default -F __start_kubectl k'
} >> ~/.bashrc

echo "Outils prêts :"
k3d version
kubectl version --client
helm version --short
trivy --version | head -1