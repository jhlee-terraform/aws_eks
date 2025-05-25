# AWS EKS 인프라 구축

## 개요
Terraform Cloud와 OIDC 기반 인증을 활용하여 AWS EKS 인프라를 코드로 안전하게 프로비저닝하는 코드입니다.
모든 인프라 코드는 디렉토리별로 역할을 분리하여 관리하며, 민감 정보는 `.gitignore`로 안전하게 관리합니다.

## 디렉토리 구조 및 역할

| 디렉토리              | 역할 요약                                                         |
|----------------------|-------------------------------------------------------------------|
| 01.aws_oidc_provider | Terraform Cloud에서 AWS 리소스 접근을 위한 OIDC Provider 및 IAM Role 생성 |
| 02.hcp_terraform     | Terraform Cloud의 Project, Workspace, VCS(GitHub) 연동 등 구조 및 자동화 관리  |
| 03.aws_eks           | 실제 AWS EKS 클러스터 및 네트워크 등 주요 인프라 리소스 생성            |
| 04.aws_eks_addon     | EKS Addon(AWS Load Balancer Controller, ExternalDNS, EBS CSI Driver) 등) 및 리소스 설치 코드                      |

---

## 1. Terraform Cloud·OIDC 기반 AWS 리소스 프로비저닝 환경 세팅

Terraform Cloud를 통해 모든 AWS 리소스를 선언적 방식으로 관리하며, OIDC를 통해 AWS IAM Role을 안전하게 연동합니다.

- 이 세팅은 추후 AWS 리소스 생성을 위한 Terraform Cloud(OIDC) 기반의 사전 작업입니다.
- 환경세팅 TF코드는 로컬 환경에서 `terraform apply`를 실행하여 상태 파일 및 민감 정보가 로컬에만 존재합니다.
- `.gitignore`를 통해 `terraform.tfstate`, `terraform.tfvars` 등 민감 정보 및 상태 파일이 GitHub 저장소에 포함되지 않도록 안전하게 관리합니다.

**구성 흐름:**

1. [01.aws_oidc_provider](https://github.com/jhlee-terraform/aws_eks/tree/main/01.aws_oidc_provider) 에서 Terraform Cloud가 AWS의 리소스를 생성할 수 있도록 OIDC Provider 및 IAM Role을 생성합니다.

   ![OIDC Provider 및 IAM Role](images/01.oidc-provider.png)

   ![IAM Role 신뢰관계 정책](images/02.hcp-terraform-role.png)

2. [02.hcp_terraform](https://github.com/jhlee-terraform/aws_eks/tree/main/02.hcp_terraform) 에서 위에서 생성한 Role을 실제로 활용할 수 있도록 Terraform Cloud의 Project, Workspace, VCS(GitHub) 연동을 선언적으로 관리하고 세팅합니다.
   - [terraform_remote_state](https://github.com/jhlee-terraform/aws_eks/blob/main/02.hcp_terraform/variables.tf) 데이터 소스를 통해 `01.aws_oidc_provider`에서 생성한 Role의 ARN을 참조하여 Terraform Cloud에 Variable Set으로 등록될 수 있도록 세팅합니다.
   - Terraform Cloud에서 실제로 설정되는 주요 항목
     - **Project**: 인프라를 논리적으로 구분하는 단위 (예: 서비스별, 프로젝트별)
     - **Workspace**: 환경별 또는 서비스별로 IaC 실행을 분리하는 단위 (예: dev, prod, eks, eks_addon 등)

       ![Terraform Cloud Project/Workspace 구성](images/03.tfc_pj_wp.png)

     - **VCS Provider**: GitHub 저장소(VCS)와 연결

       ![Terraform Cloud GitHub 연동 구성](images/05.tfc_vcs_provider.png)

     - **Variable Set**: Terraform Cloud에서 Variable Set을 통해 AWS로 OIDC 기반 AssumeRole이 가능하도록 설정

       ![Terraform Cloud Variable Set 구성](images/04.tfc_var_set.png)

---

## 2. VPC 및 네트워크 구성

---

## 3. EKS 클러스터 구성

---

## 4. addon 구성

---

## 5. 테스트용 애플리케이션 배포
