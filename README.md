# awsblankenv

Reusable CloudFormation IaC for AWS networking, plus disposable compute stacks that import those exports. Region: `ap-southeast-1`.

**Do not commit AWS credentials.** Configure the AWS CLI locally (`~/.aws/credentials`) instead.

## Layout (reusable vs disposable)

```
cloudformation/
  network/                 # REUSABLE — keep across workloads
    01-vpc.yaml            # VPC + Internet Gateway
    02-subnets.yaml        # Public + private subnets (different AZs)
    03-routing.yaml        # Route tables, IGW route, NAT Gateway
  security/                # REUSABLE baseline SGs (optional for other apps)
    01-security-groups.yaml
  satellite/               # DISPOSABLE — delete without touching network
    01-ec2.yaml            # 2x EC2, EBS, EIP, SGs, Route53 A+PTR
parameters/
```

| Layer | Stacks | Delete impact |
|-------|--------|---------------|
| Network | `blankenv-vpc`, `blankenv-subnets`, `blankenv-routing` | Removes shared VPC/subnets/IGW/NAT |
| Baseline SG | `blankenv-security` | Removes only baseline SGs |
| Satellite | `blankenv-satellite` | Removes EC2, EBS, EIP, satellite SG, A/PTR, reverse zone only |

Stacks share values via CloudFormation **Exports / Imports** keyed by `EnvironmentName` (default `blankenv`).

## Network (reusable)

| Stack | Resources |
|-------|-----------|
| VPC | VPC (`10.0.0.0/16`), IGW, attachment |
| Subnets | Public AZ-0 (`10.0.1.0/24`), private AZ-1 (`10.0.2.0/24`) |
| Routing | Public RT → IGW; NAT + EIP; private RT → NAT |

## Satellite compute (disposable)

`cloudformation/satellite/01-ec2.yaml` creates:

- **connected-satellite** — RHEL 9.6, `m5.2xlarge` (8 vCPU / 32 GiB), public subnet, Elastic IP (IGW path), 200 GiB root gp3 EBS
- **disconnected-satellite** — RHEL 9.6, same size, private subnet (no IGW route), 200 GiB root gp3 EBS
- Default AMI: `ami-0551e945da9a6e2de` (RHEL-9.6.0 Access2 GP3, ap-southeast-1)
- **Security group** (stack-scoped): TCP/22 and TCP/443 from `0.0.0.0/0`, all traffic between both instances (port only; no HTTPS app installed by this stack)
- **Route53 A** in hosted zone `Z1MDL14EQV30CO` / `sandbox699.opentlc.com`
- **Route53 PTR** in a private reverse zone `0.10.in-addr.arpa` associated with the VPC
- Optional auto-created key pair (SSM private key) when `KeyName` is empty

Delete only this workload:

```bash
aws cloudformation delete-stack --stack-name blankenv-satellite --region ap-southeast-1
```

## Deploy

### 1) Network (once)

```bash
aws cloudformation deploy --stack-name blankenv-vpc \
  --template-file cloudformation/network/01-vpc.yaml \
  --parameter-overrides file://parameters/network-vpc.json --region ap-southeast-1

aws cloudformation deploy --stack-name blankenv-subnets \
  --template-file cloudformation/network/02-subnets.yaml \
  --parameter-overrides file://parameters/network-subnets.json --region ap-southeast-1

aws cloudformation deploy --stack-name blankenv-routing \
  --template-file cloudformation/network/03-routing.yaml \
  --parameter-overrides file://parameters/network-routing.json --region ap-southeast-1

aws cloudformation deploy --stack-name blankenv-security \
  --template-file cloudformation/security/01-security-groups.yaml \
  --parameter-overrides file://parameters/security-groups.json --region ap-southeast-1
```

### 2) Satellite (repeatable / deletable)

```bash
aws cloudformation deploy --stack-name blankenv-satellite \
  --template-file cloudformation/satellite/01-ec2.yaml \
  --parameter-overrides file://parameters/satellite-ec2.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-southeast-1
```

## Useful exports

**Network:** `blankenv-VpcId`, `blankenv-PublicSubnetId`, `blankenv-PrivateSubnetId`, `blankenv-InternetGatewayId`, `blankenv-NatGatewayId`

**Satellite:** `blankenv-ConnectedSatellitePublicIp`, `blankenv-ConnectedSatelliteFqdn`, `blankenv-DisconnectedSatelliteFqdn`, `blankenv-SatelliteSecurityGroupId`
