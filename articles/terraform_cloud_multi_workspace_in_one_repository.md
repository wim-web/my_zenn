---
title: "Terraform Cloudで1つのリポジトリ内のtfstateを分離する方法"
emoji: "☁"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform", "Terraform Cloud"]
published: true
---

## はじめに

この記事ではTerraform Cloudを使っていて、1つのGitHubリポジトリ内でtfstateを分ける方法を説明します。

### 注意

Terraform Cloudはリモート実行環境として使用しています。(Execution ModeでいうRemote)

Terraform Cloudをstate管理のみとして使用した場合の本記事の検証は行っていませんのでご了承ください。

## Workspaceを作成する

Terraform CloudではWorkspaceの単位でtfstateを管理するのでその分だけWorkspaceを作ってあげれば簡単にtfstateを分離できます。

```
├── hoge1
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
└── hoge2
    ├── main.tf
    ├── outputs.tf
    └── variables.tf
```

たとえば上記の構成でstateを分離する場合、Terraform Cloudでそれぞれに対してWorkspaceを作成します。

Workspaceを作成したあとGeneral SettingsのTerraform Working Directoryをそれぞれ設定してあげます。（`hoge1` と `hoge2`）

こうすることでstate管理もわけることができますし、 `hoge1/` 以下が変更された場合はhoge1用のWorkspaceしかplan&applyされません。

## 他のWorkspaceのstateを参照する

他のWorkspaceのstateを参照する方法も用意されています。

```
data "terraform_remote_state" "vpc" {
  backend = "remote"
  config = {
    organization = "example_corp"
    workspaces = {
      name = "vpc-prod"
    }
  }
}

resource "aws_instance" "redis_server" {
  # Terraform 0.12 syntax: use the "outputs.<OUTPUT NAME>" attribute
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_id

  # Terraform 0.11 syntax: use the "<OUTPUT NAME>" attribute
  subnet_id = "${data.terraform_remote_state.vpc.subnet_id}"
}
```

dataソースを使用してorganizationとworkspaceを指定してあげれば、指定したWorkspaceのstateを参照できます。

ただし参照できるのは同じorganization内だけでorganizationが違う場合は参照できないので注意してください。

[Terraform State in Terraform Cloud](https://www.terraform.io/docs/cloud/workspaces/state.html)
