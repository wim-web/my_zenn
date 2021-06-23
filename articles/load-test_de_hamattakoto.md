---
title: "実際のプロダクトで負荷試験を行ってハマったこと"
emoji: "🕳"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS", "Laravel"]
published: true
---

## はじめに

AWS上にLaravelで構築されたプロダクトに対して負荷試験を行いました。今回ハマった部分はLaravelとは関係ありません。

構成としてはALB配下にWebサーバーがあり、RDS(Aurora)とElastiCache(Redis)を使用しています。

## 大きいインスタンスタイプのEC2が建てられない

本番環境でc5.9xlargeを使用していたので同じインスタンスを建てようとするとエラーになり建てられませんでした。

AWSアカウントではインスタンスタイプ毎に一度に建てられるvCPUの制限があり、建てようとしたアカウントでは32の制限がかかったおり、c5.9xlarge(36)だと制限に引っかかってしまいました。

環境毎にAWSアカウントを作成しているのでアカウントが作りたてで制限が低かったようです。

もし同じように運用していたら早めに作成して上限緩和申請などを行っておきましょう。

## 負荷をかけつづけるとRPSが急激に落ち込む

1つのサーバーに対して負荷をかけつづけていたところ、RPSが急激に下がった後にまた回復するという現象が起きました。

![rps_down](https://github.com/wim-web/my_zenn/blob/master/image/load-test_de_hamattakoto/rps_down.png?raw=true)
*RPSのグラフ*

RPSが落ち込んだときにエラーを吐いていたのでそれが原因のようでした。

```
'Predis_ClientException' with message 'Cannot assign requested address' 
```

PredisというのはPHPでRedisと接続するときに使用するもので、要はRedisと接続しようとしたけどなにかだめだったと言ってます。

原因としてはTCPのTIME_WAIT状態のコネクションが溜まってエフェメラルポートの上限まで使ってしまっていたことでした。

解決方法はいろいろあるのですが今回は `net.ipv4.tcp_tw_reuse=1` を指定して解決しました。

※以下の資料を見る限りPredisに問題がある気がしますがそこまで調べられていないです

[TIME_WAITに関する話](https://www.slideshare.net/takanorisejima/timewait)

## 一部のレスポンスタイムが異常

負荷試験では処理性能を超える負荷をかけると一気にレスポンスタイムが悪化するのですが、あくまで全体的に悪化するのであって一部が悪化することはありません。

ですが、DB更新系である一定負荷を超えると95percentileのレスポンスタイムが異常なまでに大きくなる現象が起きました。

![rps_down](https://github.com/wim-web/my_zenn/blob/master/image/load-test_de_hamattakoto/yabai.png?raw=true)
*Response Timeのグラフ*

さきほどのRedisのようにエラーがでておらず、New Relicで確認したところどうやらPostgresとの接続に時間がかかっているようでした。

まずはじめにRDSを疑いましたが、db.r5.4xlarge * 3 といった構成でそんな貧弱なわけないだろうと思いました。(200RPS程度だったので)

RDSのCPUや最大接続数を調べても特に異常な点は見当たりませんでした。

次にさきほどと同じようにエフェメラルポートの枯渇を調べましたがこちらも特に異常なしでした。

いろいろ調べているとPostgresとの接続を永続化するというオプションがあったのでこちらを使用したところ改善しました！

そんな喜びも束の間、PHPの公式で[持続的データベース接続](https://www.php.net/manual/ja/features.persistent-connections.php)についてこのような記述がありました。

> 一つは持続的接続でテーブルをロックする場合にスクリプト が何らかの理由でロックを外し損ねると、それ以降に実行されるスクリプト がその接続を使用すると永久にブロックしつづけてしまい、ウェブサーバーか データベースサーバーを再起動しなければならなくなるということです。

どうやらこれはRDBの整合性を犠牲にしつつ、パフォーマンスをあげるもののようです。流石にこれは使えないと思ったのと、根本的な原因がわかっていないため調査を続けることにしました。

次に試したことはRDSとの接続にドメイン名を使用していたのでそれをIPアドレスに変えてみました。

さすがに関係ないだろうと思っていましたがなんとこれで改善してしまいました！この結果から名前解決辺りが怪しいと調べてみると、[EC2における単位時間あたりの名前解決制限の対応](https://devblog.thebase.in/entry/2019/12/02/123000)という記事を見つけました。

これなら一部のレスポンスだけ異常に遅い理由もわかります。（まさかAWSの制限だったとは）

## まとめ

あらためて負荷試験をやってみないとわからないことがたくさんあると知れました。

1台のサーバーの処理性能をあげようとするといろいろな制限に引っかかってしまうので、スケールアウトの方向で全体的な処理性能をあげるほうが無難なのかなと思いました。