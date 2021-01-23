---
title: "AWS SSOを利用してTerraformを実行する"
emoji: "😎"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS", "Terraform"]
published: true
---

## 追記

2021/1/23 aws-vaultで突如credentialsエラーになり使えなくなったときの対処

## 前提

今回検証した各ツールのバージョンは以下です。

- macOS
- aws-cli/2.1.2 
- Terraform/0.14.0
- aws-vault/6.2.0

## AWS SSOを利用してTerraformを実行する

### AWS CLI

AWS CLIではSSOのプロファイルを設定できるので下記コマンドで設定します。

```
aws configure sso
```

途中でSSOのログイン画面があるのでログインします。

設定が完了したらきちんと設定できたか適当なコマンドで試してみてください。

```
aws s3 ls --profile <profile-name>
```

### aws-vault

インストールしていない場合はhomebrewでインストールできます。

```
brew install aws-vault
```

GitHubから直接インストールする場合は、6.0.0-beta5以上のバージョンをインストールしてください。（SSO対応バージョン）

aws-vaultもちゃんと動くか試してみましょう。

```
aws-vault exec <profile-name> -- aws s3 ls
```

※aws-vaultをはじめて使用する場合、keychainのパスワードを設定する必要があります。

### Terraform

ためしに以下の内容で `main.tf` を作成してみます。

```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.20.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}
```

`terraform init` でproviderをインストールしてplanをしてみます。

```
aws-vault exec <profile-name> -- terraform plan
```

これでplan内容が表示されれば完了です。

## aws-vaultで突如credentialsエラーになって使えなくなった

すべてのプロファイルで以下のエラーが出て使えなくなってしまいました。

```
aws-vault: error: exec: Failed to get credentials for hoge: : Session token not found or invalid
        status code: 401, request id: 
```

直接AWS CLIを叩くと動くためaws-vaultがおかしくなったみたいです。

対処法としては `~/Library/Keychains/aws-vault.keychain-db` のファイルを消して再度実行すると動くようになりました。
（念の為バックアップをとっておいてください。）
