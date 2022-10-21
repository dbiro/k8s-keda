#!/bin/bash
set -e

# ===== HELPERS =====
function WaitForCsv() {
    local csv="$1"
    local ns="$2"
    local retries=30

    until [[ $retries == 0 ]]; do
        new_csv_phase=$(kubectl get csv -n "${ns}" "$csv" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Waiting for CSV to appear")
        if [[ $new_csv_phase != "$csv_phase" ]]; then
            csv_phase=$new_csv_phase
            echo "$csv phase: $csv_phase"
        fi
        if [[ "$new_csv_phase" == "Succeeded" ]]; then
            break
        fi
        sleep 10
        retries=$((retries - 1))
    done

    if [ $retries == 0 ]; then
        echo "CSV \"$csv\" failed to reach phase succeeded"
        return 1
    fi
}

# ==== OLM ====
olmversion="v0.22.0"

echo "Installing OLM ${olmversion}"

kubectl apply --server-side=true -f "operator-lifecycle-manager/$olmversion/crds.yaml"    # https://kubernetes.io/docs/reference/using-api/server-side-apply/#custom-resources
kubectl wait --for=condition=Established -f "operator-lifecycle-manager/$olmversion/crds.yaml"

kubectl apply -f "operator-lifecycle-manager/$olmversion/olm.yaml"

echo "Waiting for OLM and Catalog Operator deployments to be ready"
kubectl rollout status -w deployment/olm-operator --namespace=olm
kubectl rollout status -w deployment/catalog-operator --namespace=olm

echo "Waiting for Package Server CSV"
WaitForCsv packageserver olm
echo "Waiting for Package Server deployment to be ready"
kubectl rollout status -w deployment/packageserver --namespace=olm

echo "Applying OLM configuration"
kubectl apply -f "operator-lifecycle-manager/olm-config.yaml"

# ==== OPERATOR SUBSCRTPIONS ====
#
# JAEGER OPERATOR
#
# echo "Creating subscription for Jaeger Operator"
# kubectl apply -f operator-subscriptions/jaeger-operator-sub.yaml

# echo "Waiting for Jaeger Operator CSV"
# WaitForCsv jaeger-operator.v1.37.0 operators

# echo "Waiting for Jaeger Operator deployment to be ready"
# kubectl rollout status -w deployment/jaeger-operator --namespace=operators

#
# KEDA OPERATOR
#
# echo "Creating subscription for KEDA Operator"
kubectl apply -f operator-subscriptions/keda-operator-sub.yaml

echo "Waiting for KEDA Operator CSV"
WaitForCsv keda.v2.7.1 operators

# echo "Waiting for KEDA Operator deployment to be ready"
kubectl rollout status -w deployment/keda-olm-operator --namespace=operators