---
title: "Terraform Cloudのtfstateを修正する"
emoji: "🌩"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform", "Terraform Cloud"]
published: true
---

## はじめに

Terraform Cloudはリモート実行環境(Execution ModeでいうRemote)として使用している場合においてtfstateに差分が出てしまったときの対処法です。

よくあるパターンとしてはすでにapplyしたリソースをmodule化した場合などでしょうか。

### 参考

[Migrating State from Local Terraform - Terraform Cloud and Terraform Enterprise - Terraform by HashiCorp](https://www.terraform.io/docs/cloud/migrate/index.html)

## stateファイルを修正する

ローカルで修正するためにTerraformのインストールが必要です。

Terraform Cloudにあるstateファイルをコピペ or Downloadで手元のルートディレクトリの `terraform.tfstate` にコピーします。

`terraform state mv` などでstateファイルを修正します。

その後、tfファイルに以下を追記します。(organization, workspaceは自分自身の環境に合わせて設定してください)

```
terraform {
 backend "remote" {
    hostname = "app.terraform.io"
    organization = "example"

    workspaces {
      name = "example"
    }
  }
}
```

`terraform login` でログインしたあと `terraform init` してyesで上書きします。

対象のWorkspaceのStatesタブでNew stateとあれば成功です。

![new_state](https://github.com/wim-web/my_zenn/blob/master/image/terraform_cloud_fix_state/new_state.png?raw=true)

ちなみにGitHubにpushする必要はないので今回追記した内容やTerraform実行でできたファイルなどは破棄して問題ありません。