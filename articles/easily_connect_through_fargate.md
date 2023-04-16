---
title: "ECS on Fargateで簡単にRDSへ接続する"
emoji: "🐾"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS"]
published: true
---

FargateのSSMエージェントのバージョンが3.1.1732.0より新しくなったため、リモートホストへのポートフォワーディングが出来るようになりました。
https://aws.amazon.com/jp/about-aws/whats-new/2022/05/aws-systems-manager-support-port-forwarding-remote-hosts-using-session-manager/

しかしFargateを使ってRDSに接続するために必要なECS周りを構築しようとすると地味に面倒ですよね。
ECSクラスター、サービス、タスク定義、それらに必要なロール、ECS Execの有効化などなど。

そこでRDSのエンドポイントを指定すれば自動的に踏み台用のFargateを立ち上げてくれるCLIを作成しました。

https://github.com/wim-web/xpx

以下のコマンドを打つだけで指定したホストにフォワードしてくれる環境が構築されます。

```
xpx tunnel --host hoge.ap-northeast-1.rds.amazonaws.com
```

![test](https://github.com/wim-web/xpx/raw/main/img/demo_.gif)

終了させると構築したリソースもお掃除してくれます。べんりですね。

踏み台Fargateはすでに立っていて `aws ssm start-session --target ${target} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters ${parameters} --region ${REGION}` を実行しているのであればこちらのCLIが使えます。

https://github.com/wim-web/tonneeeeel

インタラクティブにECSクラスターやコンテナなどを選択するだけでフォワードやECS Execができます。

似たようなCLIでecstaがありますがfuzzy finder的に絞り込みたかったのでtonneeeeelを作成しました。
が、ecstaではfilter_commandオプションをpecoなどを指定することで同様のことが実現できました😲。

https://github.com/fujiwara/ecsta
