#!/bin/bash
set -e

# ==== DEPLOY OLM ====
echo '== Depploying OLM =='
cd OLM || exit 1

chmod +x ./deploy_olm.sh
./deploy_olm.sh

cd ..

# ==== DEPLOY KEDA ====
echo '== Depploying KEDA =='
kubectl apply -k KEDA
kubectl -n keda rollout status deployment/keda-operator --timeout=3m 
kubectl -n keda rollout status deployment/keda-metrics-apiserver --timeout=3m 

# ==== DEPLOY APPS ====
echo '== Depploying Apps =='
kubectl apply -k Apps

kubectl -n php-apache rollout status deployment/php-apache --timeout=3m 