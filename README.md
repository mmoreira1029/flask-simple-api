# flask-simple-api

## Description

This project deploys a Python Flask application on an EKS cluster in AWS, using Terraform and EKSCTL.

The deployed infrastructure includes one VPC, three public subnets, and three private subnets, along with Internet and NAT Gateways for the respective subnet groups. The subnets are distributed across different Availability Zones.

This setup uses the default configuration provided by EKSCTL, which eliminates the need for manual networking configuration. It’s a straightforward approach that aligns with production architecture standards — albeit a simplified version. Additionally, it's fully automated, making the cluster setup faster and more efficient. For more details, see [EKSCTL - VPC Networking](https://eksctl.io/usage/vpc-networking/).

The Kubernetes setup includes two NodeGroups, each with a desired capacity of two nodes. EKSCTL also enables autoscaling for the cluster nodes by default.

The Horizontal Pod Autoscaler is configured to scale pods based on CPU and memory utilization.

This setup also includes an AWS Application Load Balancer, which handles both Ingress and Service resources. For more information, refer to the following links:

* [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
* [Route internet traffic with AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

## Setup

In this project, Terraform is used for partial automation, provisioning resources outside of EKS, such as IAM policies, ECR repositories, DynamoDB and user groups.

The EKS cluster is deployed with EKSCTL via the `deploy.sh` script located in the root directory.

## Requirements

Before you start, make sure you have the following tools installed:

- [Docker](https://docs.docker.com/engine/install/)
- [Kubernetes CLI (kubectl)](https://kubernetes.io/docs/tasks/tools/)
- [EKSCTL](https://eksctl.io/installation/)
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

And that you have configured:

- [AWS CLI Credentials](https://docs.aws.amazon.com/cli/v1/userguide/cli-chap-configure.html)
- [EKSCTL Credentials](https://eksctl.io/getting-started/)

You will also need to export the following environment variables:

```bash
export TF_VAR_aws_secret_key=<AWS_SECRET_KEY>
export TF_VAR_aws_access_key=<AWS_ACCESS_KEY>
export ACCOUNT_ID=<AWS_ACCOUNT_ID>
export REGION='eu-north-1' 
```


## Build and Deploy

To provision the AWS infrastructure with Terraform, initialize Terraform with:
```
cd terraform/ && terraform init
```

If you want to preview the resources to be created:
```
terraform plan
```

To apply the resource provisioning in AWS:

```
terraform apply
```

This will create the base infrastructure for the EKS cluster in AWS.

Next, set up the EKS cluster for the Flask API:

```
cd ../ && ./deploy.sh
```

The first step in the process is to tag and push the necessary images to the ECR repositories created by Terraform. Some images (like cert-manager and aws-loadbalancer) are pulled from quay.io, which the cluster nodes cannot access directly. AWS recommends adding these images to ECR.

After this, EKSCTL will set up the cluster and required resources.

It should take around 20-30 minutes to provision and deploy the entire structure. After the deploy script finishes, it's a good idea to wait about 5 minutes for all resources to be running as expected.

Once completed, navigate to the AWS console > EC2 > Load Balancers and look for the load balancer. The app should be accessible through the load balancer's DNS address:

```
curl http://<LB_DNS>/view/newpage
```

## Future Improvements

**Observability**

- Add Prometheus for metrics collection and Grafana for visualization.
  - [Query using Grafana running in an Amazon EKS cluster](https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-query-grafana-7.3.html)
- Consider adding the OpenTelemetry K8s operator to collect and process different data signals (metrics, traces, logs) and/or instrument the application code.
  - [Opentelemetry - Kubernetes Demo](https://opentelemetry.io/docs/demo/kubernetes-deployment/)

**AutoScaling**

- Implement Vertical Pod Autoscaling to dynamically adjust the application’s resources as needed.
  - [Adjust pod resources with Vertical Pod Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/vertical-pod-autoscaler.html)
