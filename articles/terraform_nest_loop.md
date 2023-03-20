---
title: "Terraformでネストしたloopを書く"
emoji: "👻"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform"]
published: true
---

## 環境

```bash
$ terraform -v
Terraform v1.4.2
on darwin_arm64
```

## 例題

[aws_ssoadmin_account_assignment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment)を例に考えてみます。

aws_ssoadmin_account_assignmentリソースはAWSアカウントとSSOグループと許可セットを紐付けるものです。

あるAWSアカウントに複数のグループに複数の許可セットを紐付けようとすると単純にfor_eachで回せないことに気づきます。



```hcl
locals {
  groups = {
    "GROUP_A" = {
      permission_set_arns = [
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c",
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7b"
      ]
    }
    "GROUP_B" = {
      permission_set_arns = [
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c"
      ]
    }
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each           = local.groups
  instance_arn       = "instance_arn"
  # ここは文字列を期待しているのでpermission_set_arnsを渡せない
  # かといってforやfor_eachを使えない...
  permission_set_arn = each.value.permission_sets
  principal_id       = each.key
  principal_type     = "GROUP"
  target_id          = "123456789012"
  target_type        = "AWS_ACCOUNT"
}
```

以上からわかるようにterraformのfor_eachでは1重のloopしか表現できないことがわかります。

```
# これは表現できる
for {
    # todo
}

# これは表現できない
for {
    for {
        # todo
    }
}
```

terraformでネストしたloopを表現するにはいくつか方法があります。

## moduleを使う

リソースをmoduleに移動して、moduleとresourceでfor_eachを使うことでネストしたloopを表現します。

```hcl
# main.tf
locals {
  groups = {
    "GROUP_A" = {
      permission_set_arns = [
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c",
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7b"
      ]
    }
    "GROUP_B" = {
      permission_set_arns = [
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c"
      ]
    }
  }
}


module "group_permissions" {
  # ここでloop
  for_each            = local.groups
  source              = "./modules/group_permissions/"
  permission_set_arns = each.value.permission_set_arns
  group_id            = each.key
  aws_account_id      = "123456789012"
}
```

```hcl
# module
variable "permission_set_arns" {
  type = set(string)
}

variable "group_id" {
  type = string
}

variable "aws_account_id" {
  type = string
}

resource "aws_ssoadmin_account_assignment" "this" {
  # ここでさらにloop
  for_each           = var.permission_set_arns
  instance_arn       = "instance_arn"
  permission_set_arn = each.value
  principal_id       = var.group_id
  principal_type     = "GROUP"
  target_id          = var.aws_account_id
  target_type        = "AWS_ACCOUNT"
}
```

moduleにわけるやり方が一番直感的にわかりやすいと思います。  
module内でさらにmoduleをつくることで何重のloopにも対応可能です。

## flattenする

for_eachで回す変数が多次元であることが悪いので、flattenで一次元化してあげてそれをfor_eachで回します。

```hcl
locals {
  groups = {
    "GROUP_A" = {
      permision_set_arns = [
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c",
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7b"
      ]
    }
    "GROUP_B" = {
      permision_set_arns = [
        "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c"
      ]
    }
  }
}

locals {
  flatten_groups = flatten([
    for group, ps in local.groups : [
      for p in ps.permision_set_arns : {
        group_id      = group
        permission_id = p
      }
    ]
  ])
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each           = { for f in local.flatten_groups : "${f.group_id}_${f.permission_id}" => f }
  instance_arn       = "instance_arn"
  permission_set_arn = each.value.permission_id
  principal_id       = each.value.group_id
  principal_type     = "GROUP"
  target_id          = "123456789012"
  target_type        = "AWS_ACCOUNT"
}
```

flatten_groupsの中身は以下のようになっています。

```hcl
flatten_groups = [
    {
        group_id      = "GROUP_A"
        permission_id = "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c"
    },
    {
        group_id      = "GROUP_A"
        permission_id = "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7b"
    },
    {
        group_id      = "GROUP_B"
        permission_id = "arn:aws:sso:::permissionSet/ssoins-12345e7cccc04b03/bs-6bdaf3a33d689a7c"
    },
]
```
