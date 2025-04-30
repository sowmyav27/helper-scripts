#!/bin/bash
VCLUSTER_NAME=$(terraform output -raw vcluster_name)
terraform destroy -auto-approve
kubectl delete ns "$VCLUSTER_NAME"
