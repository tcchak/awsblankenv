# awsblankenv

CloudFormation templates for a blank AWS networking foundation in `ap-southeast-1`. Intended as the base for later EC2 provisioning.

**Do not commit AWS credentials.** Configure the AWS CLI locally (`~/.aws/credentials`) instead.

## Layout

```
cloudformation/
  network/
    01-vpc.yaml       # VPC + Internet Gateway
    02-subnets.yaml   # Public + private subnets (different AZs)
    03-routing.yaml   # Route tables, IGW route, NAT Gateway
  security/
    01-security-groups.yaml  # Public + private SGs for future EC2
parameters/            # Sample parameter files (no secrets)
```

Stacks share values with CloudFormation **Exports / Imports** keyed by `EnvironmentName` (default `blankenv`).

## What gets created

| Stack order | Resources |
|-------------|-----------|
| 1. VPC | VPC (`10.0.0.0/16`), IGW, IGW attachment |
| 2. Subnets | Public subnet AZ-0 (`10.0.1.0/24`), private subnet AZ-1 (`10.0.2.0/24`) |
| 3. Routing | Public RT → IGW; NAT Gateway + EIP; private RT → NAT |
| 4. Security | Public SG (SSH); private SG (SSH from public SG only) |

## Deploy order (not run yet)

Use the same `EnvironmentName` on every stack. Example region: `ap-southeast-1`.

```bash
aws cloudformation deploy \
  --stack-name blankenv-vpc \
  --template-file cloudformation/network/01-vpc.yaml \
  --parameter-overrides file://parameters/network-vpc.json \
  --region ap-southeast-1

aws cloudformation deploy \
  --stack-name blankenv-subnets \
  --template-file cloudformation/network/02-subnets.yaml \
  --parameter-overrides file://parameters/network-subnets.json \
  --region ap-southeast-1

aws cloudformation deploy \
  --stack-name blankenv-routing \
  --template-file cloudformation/network/03-routing.yaml \
  --parameter-overrides file://parameters/network-routing.json \
  --region ap-southeast-1

aws cloudformation deploy \
  --stack-name blankenv-security \
  --template-file cloudformation/security/01-security-groups.yaml \
  --parameter-overrides file://parameters/security-groups.json \
  --region ap-southeast-1
```

## Exports for a future EC2 stack

- `blankenv-VpcId`
- `blankenv-PublicSubnetId` / `blankenv-PrivateSubnetId`
- `blankenv-PublicSecurityGroupId` / `blankenv-PrivateSecurityGroupId`
- `blankenv-InternetGatewayId`, `blankenv-NatGatewayId`
