#!/bin/bash

CLUSTER_NAME="flask-api"
REGION="eu-north-1"
CONFIG_FILE="eksctl/cluster-config.yaml"
ACCOUNT_ID="$ACCOUNT_ID"

echo "Preparing docker images..."

echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Building Docker Image for app..."
echo ""

docker build -t "flask-api:latest" .
echo "Tagging and Pushing Image to ECR..."
docker tag "flask-api:latest" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/flask-api:latest"
docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/flask-api:latest"

echo "Started to set up Cluster"
echo ""

echo "Add docker images dependencies"
echo ""

REPOSITORIES=(
  "cert-manager-cainjector"
  "cert-manager-controller"
  "cert-manager-webhook"
  "cert-manager-acmesolver"
)

VERSION="v1.13.5"

echo "Checking if Cert-Manager repos exist in ECR"

for REPO_NAME in "${REPOSITORIES[@]}"; do
  if aws ecr describe-repositories --region $REGION --repository-names "$REPO_NAME" > /dev/null 2>&1; then
    echo "Repository $REPO_NAME exists."
    echo ""
    echo "Pull, Tag qne Push $REPO_NAME to ECR"

    if docker images | grep "quay.io/jetstack/${REPO_NAME}" > /dev/null 2>&1; then
        
        echo "Tagging quay.io/jetstack/${REPO_NAME} for ECR..."
        docker tag "quay.io/jetstack/${REPO_NAME}:${VERSION}" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION}"

        echo "Pushing..."
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION}"
    
    else
        #pull image if not found in docker images
        echo "Pulling quay.io/jetstack/${REPO_NAME}..."
        docker pull "quay.io/jetstack/${REPO_NAME}:${VERSION}"

        echo "Tagging quay.io/jetstack/${REPO_NAME} for ECR..."
        docker tag "quay.io/jetstack/${REPO_NAME}:${VERSION}" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION}"

        echo "Pushing..."
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION}"
    fi
    
  else
    echo "$REPO_NAME repository not found in ECr."
  fi
done


echo "Checking if aws-load-balancer-controller repo exist in ECR"

if aws ecr describe-repositories --region $REGION --repository-names "aws-load-balancer-controller" > /dev/null 2>&1; then
    echo "Repository 'aws-load-balancer-controller' exists."
    
    echo "Pull, Tag and Push 'aws-load-balancer-controller' to ECR"

    if docker images | grep "public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2" > /dev/null 2>&1; then
        
        echo "Tagging public.ecr.aws/eks/aws-load-balancer-controller for ECR..."
        docker tag "public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aws-load-balancer-controller:v2.7.2"

        echo "Pushing.."
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aws-load-balancer-controller:v2.7.2"

    else
        #pull image if not found in docker images
        echo "Pulling 'aws-load-balancer-controller'"
        docker pull "public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2"

        echo "Tagging 'aws-load-balancer-controller' for ECR"
        docker tag "public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aws-load-balancer-controller:v2.7.2"

        echo "Pushing"
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aws-load-balancer-controller:v2.7.2"
    fi
  else
    echo "'aws-load-balancer-controller' repository not found in ECr."
  fi


echo "Creating EKS cluster with eksctl..."
eksctl create cluster -f $CONFIG_FILE

# echo "Getting OIDC_ID"
# OIDC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.identity.oidc.issuer" --output text | awk -F '/' '{print $NF}')

echo "Create IAM service account and attaching IAM policies"
eksctl create iamserviceaccount --cluster=$CLUSTER_NAME --namespace=kube-system --name=aws-load-balancer-controller --role-name AmazonEKSLoadBalancerControllerRole --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --approve --region=$REGION --override-existing-serviceaccounts

echo "Associating IAM OIDC provider to cluster"
eksctl utils associate-iam-oidc-provider --region=$REGION --cluster=$CLUSTER_NAME  --approve

echo "Installing Cert-Manager"
sed -i '' '5365s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com|'${ACCOUNT_ID}'.dkr.ecr.'${REGION}'.amazonaws.com|' eksctl/cert-manager/cert-manager.yaml
sed -i '' '5423s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com|'${ACCOUNT_ID}'.dkr.ecr.'${REGION}'.amazonaws.com|' eksctl/cert-manager/cert-manager.yaml
sed -i '' '5429s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com|'${ACCOUNT_ID}'.dkr.ecr.'${REGION}'.amazonaws.com|' eksctl/cert-manager/cert-manager.yaml
sed -i '' '5487s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com|'${ACCOUNT_ID}'.dkr.ecr.'${REGION}'.amazonaws.com|' eksctl/cert-manager/cert-manager.yaml

kubectl apply --validate=false -f ./eksctl/cert-manager/cert-manager.yaml

echo "Installing Application Load Balancer..."

echo "Applying CRDs..."
kubectl apply --validate=false -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

sed -i '' '880s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com|'${ACCOUNT_ID}'.dkr.ecr.'${REGION}'.amazonaws.com|' eksctl/alb/v2_7_2_full.yaml
kubectl apply -f ./eksctl/alb

echo "Installing Metrics Server"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Deploying application"
sed -i '' '24s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com|'${ACCOUNT_ID}'.dkr.ecr.'${REGION}'.amazonaws.com|' config/deployment.yaml
kubectl apply -f ./config/
