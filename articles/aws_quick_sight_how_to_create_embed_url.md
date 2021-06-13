---
title: "AWS QuickSightで埋め込みURLを生成する方法"
emoji: "✂️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS"]
published: true
---

## はじめに

QuickSightは他のサービスと違って独自にユーザーを作成しないといけないので、IAMをちゃんと設定しているのに埋め込みURLが生成できないなど罠にハマりやすいです。

いくつかの種類の生成方法を見ていきQuickSightでの埋め込みURLを理解していきます。

この記事でとりあげるのは以下の三種類でSAMLやADに関しては触れませんが根本的な権限周りなどは参考になると思います。

- ANONYMOUS
- QUICKSIGHT
- IAM

## IAMとQuickSightとの関係

これが一番重要で基本的にQuickSight側でユーザーを作成しないと使えません。

IAMはあくまでQuickSightへの権限があるかどうかで、権限があってもQuickSight側にユーザーがいなければ埋め込みURLは発行できません。
(IAMとQuick Sightのユーザーを紐付けることは可能)

ここを混同してしまうとIAMで適切にポリシーなどをアタッチしてるのにエラーが発生してしまうといった状況になります。

## dashboardを作成

まずは公開したいdashboardを作成してIDを控えておきます。
URLの末尾にある文字列がIDになります。

![dashboard_id](https://github.com/wim-web/my_zenn/blob/master/image/aws_quick_sight_how_to_create_embed_url/dashboard_id.png?raw=true)

## Anonymousとして発行

[QuickSight データダッシュボードをすべてのユーザーに埋め込む - Amazon QuickSight](https://docs.aws.amazon.com/ja_jp/quicksight/latest/user/embedded-analytics-dashboards-for-everyone.html)

基本的にQuickSight側にユーザーを作成しないと埋め込みURLを発行できないと書きましたが、ユーザー数が多すぎるなどの理由でいちいちユーザーを作成してられない向けの発行のやり方がAnonymousとなります。

Anonymousは匿名という意味なのでその名のとおりですね。

前提として以下の権限が必要になります。
公式ではassume roleしていますが権限が付与されればassume roleでなくても大丈夫です。
aws-cliでやるなら実行するIAMに以下のポリシーを直接アタッチでも構いません。

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "quicksight:GetDashboardEmbedUrl",
              "quickSight:GetAnonymousUserEmbedUrl"
            ],
            "Resource": "*"
        }
    ]
}
```

そうしたら以下のコマンドでURLが発行できます。(`<>`には自分の環境にあう値を代入してください。)

```
aws quicksight get-dashboard-embed-url --aws-account-id <> --dashboard-id <> --identity-type ANONYMOUS --namespace default
```

ポイントは `--identity-type ANONYMOUS` を指定することと、`--namespace default` を指定することです。
namespaceの詳細は説明しませんがなにもしていなければdefaultになっています。

:::message
`Unknown options: --namespace` というエラーが出る場合は1系,2系に関わらずaws-cliのバージョンが古い可能性があります
:::

なおAnonymousはQuickSightのプランがセッションキャパシティーでないとエラーになります。
不特定多数のユーザーに公開するのでユーザー数でなくセッションという概念で料金が計算されるということです。

```
An error occurred (UnsupportedPricingPlanException) when calling the GetDashboardEmbedUrl operation: ANONYMOUS identity type is supported only when the account has an active Capacity Pricing plan
```

## QUICKSIGHTとして発行

[認証済みユーザー向けの QuickSight データダッシュボードの埋め込み - Amazon QuickSight](https://docs.aws.amazon.com/ja_jp/quicksight/latest/user/embedded-analytics-dashboards-for-authenticated-users.html)

これはQuickSightに登録されているユーザーを使って埋め込みURLを取得するといったものになります。
なので事前にQuickSight側でユーザーを作成する必要があります。(最初に登録されているユーザでも可能です。)

IAMユーザーは「はい・いいえ」どちらでも構いません。

![create_quick_user](https://github.com/wim-web/my_zenn/blob/master/image/aws_quick_sight_how_to_create_embed_url/create_quick_user.png?raw=true)

今回は以下の権限が前提となります。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "quicksight:GetDashboardEmbedUrl",
        "quicksight:GetAuthCode"
      ],
      "Resource": "*"
    }
  ]
}
```

QuickSightに登録したユーザーにはQuickSight用のArnが付与されるのでそれを確認します。

```
aws quicksight list-users --aws-account-id <> --namespace default
```

発行したいユーザーのArnを確認できたら `--user-arn` にそのArnを指定して以下のコマンドを実行します。

```
aws quicksight get-dashboard-embed-url --aws-account-id <> --dashboard-id <> --identity-type QUICKSIGHT --user-arn <>
```

これでQuickSightのユーザーとして埋め込みURLを発行できます。

## IAMとして発行

これが一番ややこしいのですが単にIAMユーザーを作成するだけではだめです。そのIAMとQuickSightのユーザーを紐付けする必要があります。

ユーザー名にIAMユーザー名をいれてIAMユーザーを「はい」にします。

![create_quick_iam_user](https://github.com/wim-web/my_zenn/blob/master/image/aws_quick_sight_how_to_create_embed_url/create_quick_iam_user.png?raw=true)

権限は以下が前提です。

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "quicksight:GetDashboardEmbedUrl"
            ],
            "Resource": "*"
        }
    ]
}
```

今回はIMAをQuickSightのユーザーに紐づけているのでArnを調べる必要がなく以下のコマンドで発行できます。(紐付けたIAMの情報をつかってCLIを操作してください。)

```
aws quicksight get-dashboard-embed-url --aws-account-id <> --dashboard-id <> --identity-type IAM
```

QUICKSIGHTと違う点は `--user-arn` を指定しなくてもいい点です。

## get-session-embed-url

いままではダッシュボードの共有でしたがQuickSightのトップ画面を共有することもできます。

![session_top](https://github.com/wim-web/my_zenn/blob/master/image/aws_quick_sight_how_to_create_embed_url/session_top.png?raw=true)

ダッシュボードの埋め込みURL共有でいうAnonymous的なことはできず、QuickSightに紐付いているIAMで実行するか、 `--user-arn` を指定して実行するかになります。

```
aws quicksight get-session-embed-url --aws-account-id <> --user-arn <>
```
