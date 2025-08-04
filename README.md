# 🏢 Multi-Account Landing Zone - Enterprise AWS Setup

[![AWS](https://img.shields.io/badge/AWS-Organizations%20%7C%20Control%20Tower%20%7C%20SCPs-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-Infrastructure-7B42BC?style=for-the-badge&logo=terraform)](https://terraform.io/)

Enterprise-grade AWS multi-account setup using AWS Organizations, Control Tower, and Service Catalog. Implements security, compliance, and governance automation for large-scale AWS environments.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Management      │    │   Security      │    │   Shared        │
│ Account         │───▶│   Account       │───▶│   Services      │
│ (Organizations) │    │ (Audit/Logging) │    │   Account       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                      │
         ▼                        ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Production    │    │    Staging      │    │  Development    │
│   Workloads     │    │   Workloads     │    │   Workloads     │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## ✨ Features

### 🔐 **Security & Compliance**
- **AWS Organizations**: Centralized account management
- **Control Tower**: Automated governance and compliance
- **Service Control Policies**: Granular permission boundaries
- **Config Rules**: Continuous compliance monitoring
- **CloudTrail**: Centralized audit logging

### 💰 **Cost Management**
- **Consolidated Billing**: Single billing for all accounts
- **Cost Allocation Tags**: Resource-level cost tracking
- **Budgets & Alerts**: Proactive cost management
- **Reserved Instances**: Shared RI benefits across accounts

### 🔄 **Automation & Governance**
- **Account Vending Machine**: Automated account provisioning
- **Service Catalog**: Pre-approved infrastructure templates
- **AWS Config**: Configuration compliance automation
- **CloudFormation StackSets**: Multi-account deployments

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with Organization management permissions
- Terraform >= 1.8
- Control Tower enabled in management account

### Basic Setup

```bash
# Clone the repository
git clone https://github.com/melorga-portfolio/multi-account-landing-zone.git
cd multi-account-landing-zone

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your organization details

# Deploy the landing zone
terraform init
terraform plan
terraform apply
```

## 📊 **Account Structure**

| Account Type | Purpose | Security Level |
|--------------|---------|----------------|
| Management | AWS Organizations, billing | High |
| Security | Audit, logging, monitoring | Critical |
| Shared Services | DNS, AD, shared resources | Medium |
| Production | Live workloads | High |
| Staging | Pre-production testing | Medium |
| Development | Development workloads | Low |
| Sandbox | Experimentation | Low |

## 🔐 **Service Control Policies**

### Production Account SCP
- Prevent root user access
- Enforce encryption in transit/rest
- Restrict instance types to approved list
- Require MFA for sensitive operations

### Development Account SCP
- Allow broader permissions for development
- Restrict expensive resources
- Prevent production data access
- Time-based access restrictions

## 💰 **Cost Optimization**

**Expected Monthly Costs**:
- **Control Tower**: ~$3.00 per account
- **Config Rules**: ~$2.00 per account
- **CloudTrail**: ~$2.10 per account
- **Total Base Cost**: ~$7-10 per account/month

*Scales efficiently with proper governance and automation*

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

> **"This landing zone demonstrates enterprise-grade AWS account management with automated governance, security, and compliance controls suitable for large organizations."**
