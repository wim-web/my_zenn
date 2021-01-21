---
title: "AWS Systems ManagerでAnsibleを実行する"
emoji: "⚙"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS", "Ansible"]
published: true
---

## はじめに

ローカルでAnsibleを実行してEC2をセットアップしようとするとSSH-Keyを作成する必要があります。

サービスごとにそれぞれ作成しては管理が大変なのでどうにかならないかと調べたら、Systems Mangerでなんとかできそうだったので試してみることにしました。

## 前提条件

- EC2を立ち上げ済み
- SSMがEC2に接続できる（https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-getting-started.html）
- GitHubのリポジトリにAnsibleのファイルを置いておく

## Systems ManagerのRun Command

Ansibleの実行にRun Commandという機能を使っていきます。

いろいろなコマンドを実行できるのですが、ansibleで検索すると2つ候補が出てきました。

![ansible_command](https://github.com/wim-web/my_zenn/blob/master/image/run_ansible_on_system_managers/ansible-command.png?raw=true)

- ApplyAnsiblePlaybooks

複雑なplaybookを実行できる。

対象のEC2にあらかじめAnsibleをインストールしなくても実行前にインストールしてくれるオプションがある。

- RunAnsiblePlaybook

簡単なplaybookを実行できる。（roleなど使えない？）

対象のEC2にあらかじめAnsibleをインストールする必要がある。

ドキュメントにも以下のとおり書いてあるので `AWS-ApplyAnsiblePlaybooks` のコマンドを使用します。

> Systems Manager には、Ansible プレイブックを実行する ステートマネージャー 関連付けを作成できる 2 つの SSM ドキュメント AWS-RunAnsiblePlaybook と AWS-ApplyAnsiblePlaybooks が含まれています。AWS-RunAnsiblePlaybook ドキュメントは廃止されました。レガシーの目的で Systems Manager で使用できます。ここで説明する機能強化のため、AWS-ApplyAnsiblePlaybooks ドキュメントを使用することをお勧めします。

コマンドのパラメーターを入力します。

![ansible_command](https://github.com/wim-web/my_zenn/blob/master/image/run_ansible_on_system_managers/command_parameter.png?raw=true)

- SourceType

今回はGitHubを選択します。

- Source Info

こんな感じで指定します。

リポジトリがprivateな場合、アクセストークンを発行しシークレットマネージャーに登録して参照します。

https://docs.aws.amazon.com/systems-manager/latest/userguide/integration-github-ansible.html

```
{
    "owner": "owner",
    "repository": "repo-name",
    "path": "ansible",
    "tokenInfo": "{{ssm-secure:hogehoge}}"
}
```

- Install Dependencies

EC2にAnsibleなど必要なものをインストールするか指定します。

- Playbook File

リポジトリ内でのplaybookへのpathを指定します。


あとはターゲットを指定して実行ボタンをクリックするとAnsibleが実行されます。

Run Command自体も出力結果を表示してくれますが、文字数制限がありエラー時にはほとんど役に立たないのでS3かCloud Watch Logsを指定しておくと楽になります。


## コマンドの中身

パラメーターなどの指定がどう対応しているか知りたい場合は、コマンドの中身を見れるのでそれを見るとわかりやすいかもしれません。

[ApplyAnsiblePlaybooks](https://console.aws.amazon.com/systems-manager/documents/AWS-ApplyAnsiblePlaybooks/content?region=us-east-1)

[RunAnsiblePlaybook](https://console.aws.amazon.com/systems-manager/documents/AWS-RunAnsiblePlaybook/content?region=us-east-1)

中身を見てもらえればわかるのですが、 `RunShellScript` をラップしているだけなので複雑なことをしたければ `RunShellScript` でがんばるという手もあります。