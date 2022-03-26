---
title: "TerraformでAWSのマルチアカウント環境を整備する"
emoji: "🐙"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS", "Terraform"]
published: true
---

## Landing Zoneに沿ってマルチアカウント環境をつくる

AWSではマルチアカウントに対してのソリューションとしてLanding Zoneを提唱しています。

今回はLanding Zoneにある程度沿ったものを作成します。

具体的にはLog, Securityアカウントの作成、AWS Config, GuardDuty, Security Hub, CloudTrailをOrganizationと統合します。

下図にあるShared Service AccountやCodePipelineあたりは実装しません。

![landing zone](https://d1.awsstatic.com/Solutions/Solutions%20Category%20Template%20Draft/Solution%20Architecture%20Diagrams/aws-landing-zone-architecture.9e2c5d3a070d008e01a4a020e6ccf0d7bfe6904c.png)

IaCとしてTerraformを使用します。

## Organizationsの作成

まずはOrganizationsを作成しないと始まりませんのでOrganizationsを作成します。

[Resource: aws_organizations_organization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization)

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    # 信頼されたアクセス
  ]
  feature_set = "ALL"
}
```

 Organizationsを利用することで他のサービスと統合して便利になるサービスがあります。利用したい場合は都度 `aws_service_access_principals` に追加していく形になります。

 `feature_set` は基本的にALLで問題ありません。
  
## OU, アカウントの作成

### Log, Security

LogとSecurityアカウントはCore OU配下に作成します。

```hcl
resource "aws_organizations_organizational_unit" "core" {
  name = "core"
  parent_id = aws_organizations_organization.org.roots[0].id
}
```

```hcl
resource "aws_organizations_account" "log" {
  name = "log"
  email = "log@example.com"
  parent_id = aws_organizations_organizational_unit.core.id
} 
```

```hcl
resource "aws_organizations_account" "security" {
  name = "security"
  email = "security@example.com"
  parent_id = aws_organizations_organizational_unit.core.id
} 
```

### Service OU

実際のプロダクトを構築するアカウントはService OU配下に作成する想定ですのでService OUを作成しておきます。

```hcl
resource "aws_organizations_organizational_unit" "service" {
  name = "service"
  parent_id = aws_organizations_organization.org.roots[0].id
}
```

## SSOを有効化する

Organizationsのaws_service_access_principalsに `"sso.amazonaws.com"` を追加するだけでSSOを有効化できます。

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "sso.amazonaws.com"
  ]
  feature_set = "ALL"
}
```

SSOの設定は解説しませんがOrganizationsと連携することでユーザーと権限を設定するだけで済むので簡単に設定できます。

## CloudTrailの有効化

**できること**

- メンバーアカウントでの自動有効化

**できないこと**

- メンバーアカウントへの委任
- 結果の集約

### CloudTrail用のS3

まず前提として証跡のログを残す用のS3をLogアカウントで作成します。

```hcl
resource "aws_s3_bucket" "for_cloudtrail" {
  bucket = "cloudtrail"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "cloud_trail_bucket_policy" {
  bucket = aws_s3_bucket.for_cloudtrail.name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::ins-cloud-trail/*",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            }
        },
        {
            "Effect": "Allow",
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.for_cloudtrail.arn}",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            }
        }
    ]
}
EOF
}
```

### CloudTrailを有効化する

Organizationsのaws_organizations_organizationに `"cloudtrail.amazonaws.com"` を追加します。

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com"
  ]
  feature_set = "ALL"
} 
```

マスターアカウントにCloudTrailを作成します。

```hcl
resource "aws_cloudtrail" "cloudtrail" {
  name = "cloudtrail"
  s3_bucket_name = # Logアカウントで作ったS3
  include_global_service_events = true
  is_multi_region_trail = true
  enable_logging = true
  enable_log_file_validation = true
  is_organization_trail = true
}
```

ここで設定した内容はメンバーアカウントに引き継がれて自動でCloudTrailが有効になります。

CloudTrailはCloudWatchLogsにもログを流すことができるので、そこからCloudWatchAlarmで通知できます。ただしすべてのアカウントに適用したい場合は各アカウントで設定する必要があります。

## AWS Configの有効化

**できること**

- メンバーアカウントへの委任
- 結果の集約

**できないこと**

- メンバーアカウントでの自動有効化

### Config用のS3

まずConfig用のS3をLogアカウントで作成します。

```hcl
resource "aws_s3_bucket" "for_config" {
  bucket = "config"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.for_config.name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "${arn}/AWSLogs/*/Config/*",
            "Principal": {
                "Service": "config.amazonaws.com"
            }
        },
        {
            "Effect": "Allow",
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.for_config.arn}",
            "Principal": {
                "Service": "config.amazonaws.com"
            }
        }
    ]
}
EOF
}
```

### 有効化

Organizationsのaws_organizations_organizationに `"config.amazonaws.com"` と `"config-multiaccountsetup.amazonaws.com"` を追加します。

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com"
  ]
  feature_set = "ALL"
} 
```

ConfigはOrganizationsを使ってもメンバーアカウントで自動有効化されないので、すべてのアカウントでConfigを作成します。

moduleなどをして再利用するのがいいとおもいます。

```hcl
resource "aws_iam_service_linked_role" "config_role" {
  aws_service_name = "config.amazonaws.com"
}

resource "aws_config_configuration_recorder" "default" {
  name = "default"
  role_arn = aws_iam_service_linked_role.config_role.arn
  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "default" {
  name = aws_config_configuration_recorder.default.name
  s3_bucket_name = # Logアカウントで作成したS3
  depends_on = [aws_config_configuration_recorder.default]
}

resource "aws_config_configuration_recorder_status" "default" {
  name = aws_config_configuration_recorder.default.name
  is_enabled = true
  depends_on = [ aws_config_delivery_channel.default ]
} 
```

次にSecurityアカウントに委任します。

委任 -> Configの作成 ではなく Configの作成 -> 委任 の順番でないとだめなので注意しましょう。

Terraformで委任用のリソースが提供されていないのでAWS CLIで行っています。

```hcl
resource "null_resource" "config_delegated" {  
  provisioner "local-exec" {
    command = "aws organizations register-delegated-administrator --account-id ${aws_organizations_account.security.id} --service-principal config.amazonaws.com"
    on_failure = fail
  }
}

resource "null_resource" "config_multi_setup_delegated" {  
  provisioner "local-exec" {
    command = "aws organizations register-delegated-administrator --account-id ${aws_organizations_account.security.id} --service-principal config-multiaccountsetup.amazonaws.com"
    on_failure = fail
  }
  depends_on = [ null_resource.config_delegated ]
}
```

これでSecurityアカウントに委任ができたはずです。

委任先のSecurityアカウントでAggregatorの作成をします。

```hcl
resource "aws_config_configuration_aggregator" "organization" {
  depends_on = [aws_iam_role_policy_attachment.organization]

  name = "example" # Required

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.organization.arn
  }
}

resource "aws_iam_role" "organization" {
  name = "example"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "organization" {
  role       = aws_iam_role.organization.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}
```

SecurityアカウントでメンバーアカウントのConfigの情報を見ることができます。

メンバーアカウントへのConfig Rulesの適用は [Resource: aws_config_organization_managed_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_organization_managed_rule) と [Resource: aws_config_organization_custom_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_organization_custom_rule) で一斉に適用できます。

## GuardDutyの有効化

**できること**

- メンバーアカウントへの委任
- メンバーアカウントでの自動有効化
- 結果の集約

### 有効化

Organizationsのaws_organizations_organizationに `"guardduty.amazonaws.com"` を追加します。

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com"
  ]
  feature_set = "ALL"
} 
```

マスターアカウントでGuardDutyを作成しつつ委任します。

```hcl
resource "aws_guardduty_organization_admin_account" "org_gd" {
  depends_on = [ aws_organizations_organization.org ]
  admin_account_id = aws_organizations_account.security.id
}

resource "aws_guardduty_detector" "this" {
  enable = true
}
```

これでSecurityアカウントに委任できたのでメンバーアカウントが追加されたときの自動有効化をオンにします。

```hcl
resource "aws_guardduty_organization_configuration" "this" {
  auto_enable = true 
  detector_id = data.aws_guardduty_detector.this.id
}

data "aws_guardduty_detector" "this" {}
```

ちなみに自分の環境では既存のアカウントに自動追加されなかったので、SecurityアカウントのGuardDuty/設定/アカウントから手作業で有効化しました。

## Security Hub

**できること**

- メンバーアカウントへの委任
- メンバーアカウントでの自動有効化
- 結果の集約

### 有効化

Organizationsのaws_organizations_organizationに `"securityhub.amazonaws.com"` を追加します。

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com"
  ]
  feature_set = "ALL"
} 
```

マスターアカウントでSecurity Hubを作成しつつ委任します。Security Hubの委任もTerraformにないのでAWS CLIで行います。

```hcl
resource "null_resource" "delegete_security_hub" {
  provisioner "local-exec" {
    command = "aws securityhub enable-organization-admin-account --admin-account-id ${aws_organizations_account.security.id}"
    on_failure = fail
  }
}

resource "aws_securityhub_account" "this" {
  # 特に属性がないので空で大丈夫です
} 
```

これでSecurityアカウントに委任できました。

## SCOで設定変更を防ぐ

上記の設定すればメンバーアカウントを追加したときに自動的に各サービスが有効化されます。

しかし、一部のサービスでは無効化できたり設定を変更できたりするので、変更されたくない場合はSCPを使用して権限を絞ってあげましょう。

SCPを有効化するにはenabled_policy_typesを指定してあげます。

```hcl
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com"
  ]
  enabled_policy_types = [ "SERVICE_CONTROL_POLICY" ]
  feature_set = "ALL"
}
```

あとはIAMのようにポリシーを作成してOU単位でアタッチします。（アカウントにアタッチできますが基本はOUになります。）

```hcl
resource "aws_organizations_policy" "some_role" {
  name = "deny_access_to_role"
  content = file("./some_policy.json")
}

resource "aws_organizations_policy_attachment" "attach_some_role" {
  policy_id = aws_organizations_policy.some_role.id
  target_id = aws_organizations_organization.org.roots[0].id
}
```

## さいごに

これで基本的なLanding Zoneの実装ができました。

これだけではとくに通知の設定などもしていないのでなにか起こった時に発見できません。

CloudWatchAlarmやEventBridge、AWS Chatbotなどを駆使してSlackなどへ通知する体制を整えることになるでしょう。
