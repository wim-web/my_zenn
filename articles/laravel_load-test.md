---
title: "負荷試験のふの字も知らないエンジニアが負荷試験をやってみる（Laravel）"
emoji: "😡"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Laravel", "AWS"]
published: true
---

## はじめに

負荷試験をやったことないエンジニアが練習してみた記録です。改善点などがあればコメントいただけると幸いです。

参考にした書籍は以下です。初心者の自分でも読みやすかったのでオススメです。

[Amazon Web Services負荷試験入門](www.amazon.co.jp/dp/B075SV3VN3)

今回使用した環境を簡単に立ち上げられるようにTerraformなどを用意しています。

https://github.com/wim-web/laravel-load-test

## 負荷試験の環境

### Infrastructure

インフラ構成はALBを使用したスタンダードな構成です。

![load-test_figure](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/load-test_figure.svg?raw=true)

初期状態ではWebサーバーは1台で攻撃サーバーと同じサブネットに属しています。サブネット自体はパブリック・プライベートともに3つずつ用意してあります。

### Application

アプリケーションはLaravelで構築してあります。

APIサーバーとして想定していますが、セッションを簡単に使いたいので `api.php` でなく `web.php` にルーティングを記述しています。

機能としては以下になります。

- ヘルスチェック
- ログイン/ログアウト
- 記事
    - CRUD
    - いいねする/いいねを外す
- ユーザー詳細

## 負荷試験やってみる

### 目標値について

具体的な目標値はなく、m5.largeのインスタンスでLaravelの最大値がどれくらいになるかを検証します。

レイテンシについては100ms〜200ms目安としておきます。

### 静的ファイルへの負荷

まずはNginxで静的ファイルを返すだけの負荷試験をします。

Webサーバーに入って自分自身のnginxに対してabを回してみます。

対象PATH: `/status.txt`

|  -c  |  -n  | rps | ms |
| ---- | ---- | --- | -- |
| 10 | 100000 | 23700 | 0.4 |
| 50 | 100000 | 24000 | 2.0 |
| 100 | 100000 | 25000 | 4.0 |
| 150 | 100000 | 25000 | 6.0|

だいだい24000/rpsは出てるみたいです。

次は攻撃サーバーからWebサーバーにPrivateIPを使ってabを回してみます。

対象PATH: `/status.txt`

|  -c  |  -n  | rps | ms |
| ---- | ---- | --- | -- |
| 10 | 100000 | 5600 | 1.7 |
| 50 | 100000 | 6400 | 7.7 |
| 100 | 100000 | 6500 | 15 |
| 150 | 100000 | 5700 | 25 |

結構rpsが落ちてしまいましたが、とりあえずすすめて攻撃サーバーからlocustで負荷を掛けてみます。

対象PATH: `/status.txt`


:::message
`locust -f nginx.py` を打つと `locust.{domain_name}:8089` にアクセスしてGUIで操作できます。
:::


![locust_nginx_1](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/locust_nginx_1.png?raw=true)

|  -user  | rps | ms |
| ------- | ---- | --- |
| 1 | 620 | 2 |
| 10 | 730 | 12 |
| 50 | 710 | 47 |

だいだい700/rpsと落ち込んでしまったのですが、WebサーバーのCPU使用率は10%も使っておらず、攻撃サーバーのCPU使用率が1userから90〜100に張り付いていたので攻撃サーバーがボトルネックになっています。

ここもいったん次に進みます。

### Laravelへの負荷

#### health_check

まずはただ単に `ok` という文字列を返すだけのAPIを検証します。

まずはWebサーバー自身でabを回してみます。

対象PATH: `/health_check`

|  -c  |  -n  | rps | ms | cpu |
| ---- | ---- | --- | -- | --- |
| 2 | 500 | 21 | 93 | 99 |
| 4 | 500 | 21 | 188 | 99 |
| 8 | 500 | 21 | 380 | 99 |

並列数を2から始めたのはphp-fpmのプロセス数を2に設定しているからです。（プロセス数が同時接続数になるため。）

21/rpsぐらいでしょうか。locust->nginxでは700/rpsだったのでnginxがボトルネックではなくLaravelがボトルネックになってそうです。

php-fpmのプロセスは2つに固定していますが、CPUをほぼ使い切っているのでphp-fpmの設定をいじっても意味がなさそうですが一応 `pm.max_children = 4` にしてみます。(`etc/php-fpm.d/www.conf`)

|  -c  |  -n  | rps | ms | cpu |
| ---- | ---- | --- | -- | --- |
| 2 | 500 | 22 | 89 | 98 |
| 4 | 500 | 21 | 189 | 100 |
| 8 | 500 | 21 | 378 | 100 |

とくに変わらなかったのでとりあえず `pm.max_children = 2` で進めてみます。

とくにLaravelをチューニングしていないのでしてみます。設定ファイルのキャッシュやautoloadの最適化などをします。

```
php artisan config:cache
php artisan route:cache
composer install --optimize-autoloader --no-dev
```

Webサーバー自身でabを回してみます。

対象PATH: `/health_check`

|  -c  |  -n  | rps | ms | cpu |
| ---- | ---- | --- | -- | --- |
| 2 | 500 | 25 | 80 | 98 |
| 4 | 500 | 24 | 161 | 99 |
| 8 | 500 | 24 | 325 | 99 |

ほんの若干改善したかなと言う感じです。もう少しrouteやconfigの記述が多くなればより効果が出たりするかもしれません。

Laravelのチューニングはもっとありますが、OPCacheのほうが効果あると思うのでやってみます。

```
yum install -y php-opcache
```

`php.ini` に以下を追記します。

```
[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=16229
opcache.validate_timestamps=0
```

Webサーバー自身でabを回してみます。

対象PATH: `/health_check`

|  -c  |  -n  | rps | ms | cpu |
| ---- | ---- | --- | -- | --- |
| 2 | 2000 | 237 | 8 | 96 |
| 4 | 2000 | 235 | 17 | 96 |
| 8 | 2000 | 223 | 35 | 96 |

rps, msともに大幅に改善しました。

CPUも大体使ってるのでこのまま進めます。

次は攻撃サーバーからabします。

対象PATH: `/health_check`

|  -c  |  -n  | rps | ms | cpu(web) |
| ---- | ---- | --- | -- | --- |
| 2 | 1000 | 232 | 8 | 94 |
| 4 | 1000 | 227 | 17 | 94 |
| 8 | 1000 | 222 | 35 | 95 |

よさそうなのでlocustでリクエストしてみます。

```
locust -f app.py --tags health_check
```

対象PATH: `/health_check`

![locust_health_check](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/locust_health_check.png?raw=true)

| user | rps | ms | cpu(web) | cpu(locust) |
| ---- | --- | -- | -------- | ------------|
| 2 | 200 | 12 | 75 | 40 |
| 4 | 226 | 18 | 94 | 46 |
| 8 | 230 | 36 | 94| 45 |

大体同じくらいでててWebサーバーのCPUも使い切っていてWebサーバーがボトルネックだと判断できます。

#### DB参照系

DBの参照系をやっていきます。

```
locust -f app.py --tags show_articles
```

対象PATH: `GET: /articles/{article}`

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 2 | 55 | 35 | 36 | 13 | 20 |
| 4 | 63 | 64 | 40 | 16 | 21 |
| 8 | 62 | 128 | 40 | 16 | 21 |

web, locust, dbのどのCPUも余裕があります。並列数をあげてもどこの負荷も上がらないのでスケールしようにもボトルネックがわかりません。

![locust_show_articles_db_metrics](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/locust_show_articles_db_metrics.png?raw=true)

DBコネクション数を見る限り2コネクションまでしかありません。php-fpmのプロセスが2つなのでもしやと思い増やしてみることにします。

`pm.max_children = 4`

対象PATH: `GET: /articles/{article}`

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 4 | 93 | 42 | 60 | 20 | 32 |
| 8 | 99 | 80 | 65 | 25 | 33 |

`pm.max_children = 8`

対象PATH: `GET: /articles/{article}`

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 8 | 118 | 67 | 85 | 25 | 41 |
| 16 | 120 | 130 | 86 | 25 | 42 |

`pm.max_children = 16`

対象PATH: `GET: /articles/{article}`

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 16 | 125 | 123 | 88 | 25 | 45 |

`pm.max_children = 32`

対象PATH: `GET: /articles/{article}`

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 32 | 130 | 244 | 92 | 26 | 47 |


`pm.max_children = 32` でWebサーバーのCPU使用率が90%を超えたのでWebサーバーがボトルネックのようです。

おそらくphp-fpmのプロセス数が少ないとDB処理待ちのときにCPUが遊んでしまうのだと思います。

レイテンシを考慮して、いったん `pm.max_children = 8` ですすめます。

#### DB更新系

つぎに更新系を対象にしてやっていきます。

:::message alert
本来はログインをしないと記事を投稿できませんが、ログイン処理まで入ってしまうと複雑になってしまうのでログインしなくても記事を投稿できるAPIを用意してます。
:::

```
locust -f app.py --tags store_article
```

対象PATH: `POST: /articles`

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 8 | 120 | 66 | 80 | 25 | 44 |
| 16 | 125 | 127 | 84 | 25 | 46 |

rps,msともに参照とほぼ変わらず大丈夫そうです。

参照系と同じようにどこのCPUにも余裕があったので `pm.max_children = 64` で負荷をかけたところWebサーバーのCPU使用率が100%、DBサーバーが52%だったのでボトルネックはWebサーバーと判断しました。

#### シナリオを流す

いよいよシナリオを流してみます。API単体だと120/rps前後出ていましたので100/rpsぐらいは出るかなと思ってます。

```
locust -f scenario.py
```

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 8 | 17 | 98 | 8-30 | 6 | 47 |
| 32 | 32 | 628 | 30-50 | 8 | 99 |

rpsが半分以下になってしまいました。

DBのCPUが張り付いてしまったのでDBがボトルネックっぽいですが、あまりにも遅すぎるので計測していないAPIが怪しそうです。

ここでNew RelicのAPMで調べてみます。

![locust_scenario](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/locust_scenario.png?raw=true)

`articles.index` がほぼほぼ占めてます。このAPIを改善できれば大幅に改善できそうです。

発行されてSQLを見てみるとカウントに時間がかかっています。

![article_index_sql](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/article_index_sql.png?raw=true)

Laravelのpaginateメソッドを使用してページネーションをしているのですが、総件数を取得するSQLも発行しているみたいです。

今回の仕様では総件数はいらなかったと仮定してpaginateメソッドの使用をやめて改善します。（改善方法はかなり雑にしてますが大体を知れればいいので大目に見てください。）

もう一度locustでシナリオを流します。

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 8 | 19 | 63 | 8-30 | 6 | 25 |
| 32 | 55 | 200 | 65-90 | 14 | 84 |

rps, msともに改善されてDBのCPU使用率も下がりました。

次にインパクトのおおきいところを改善してみます。（usersテーブルのnameにindexを貼る。）

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 32 | 63 | 144 | 50-80 | 16 | 66 |

レイテンシが200ms以内になり、DBのCPU使用率も60%台に下がりました。

改善の余地はまだまだありますがいったんここを区切りとします。

#### スケールアウトするか

Webサーバーをスケールアウトした場合にきちんとスケールするかを調査してみます。

まずはWebサーバー1台のときのELB経由で `/health_check` に負荷をかけてみます。

```
locust -f app.py --tags health_check
```

対象PATH: `health_check`

さきほどのEC2に直接負荷をかけた結果はこちらです。

| user | rps | ms | cpu(web) | cpu(locust) |
| ---- | --- | -- | -------- | ------------|
| 2 | 200 | 12 | 75 | 40 |
| 8 | 230 | 36 | 94| 45 |

こちらがいま行ったALB経由の結果です。

| user | rps | ms | cpu(web) | cpu(locust) |
| ---- | --- | -- | -------- | ------------|
| 2 | 166 | 12 | 60 | 34 |
| 8 | 220 | 36 | 99| 45 |

ほぼ変わらないのでWebサーバーを2台に増やしてみます。

locustで負荷をかけます。

対象PATH: `health_check`

| user | rps | ms | cpu(web) | cpu(locust) |
| ---- | --- | -- | -------- | ------------|
| 8 | 335 | 23 | 65 | 68 |
| 16 | 425 | 28 | 90 | 85 |

rpsが大体倍になっていい感じです。

単体APIの負荷試験をとばしてシナリオを流してみます。

```
locust -f scenario.py
```

さきほどのEC2に直接負荷をかけた結果はこちらです。

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 32 | 63 | 144 | 50-80 | 16 | 66 |

こちらがいま行ったALB経由の結果です。

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 32 | 34 | 507 | 20 | 10 | 100 |

rps, msともに悪化しており単体APIからやり直しかと思ったのですが、DBのCPU使用率が100%になっていたのでDBのスケールアップをします。

![scale_out_db_cpu](https://github.com/wim-web/my_zenn/blob/master/image/laravel_load-test/scale_out_db_cpu.png?raw=true)


`db.m5.xlarge` にインスタンスをあげましたがそれでもCPU使用率が張り付いてしまっていました。

`db.m5.2xlarge` にあげた結果がこちらです。

| user | rps | ms | cpu(web) | cpu(locust) | cpu(db) |
| ---- | --- | -- | -------- | ----------- | ------- |
| 64 | 120 | 165 | 70 | 26 | 81 |

これでrpsがほぼ倍になり、レイテンシも200ms以下になっています。

DBのスペックを二段階あげたことが気になりますが、スケールアウトの効果は確認できたのでいったん終わりにしたいと思います。

## 余談

今回苦労したのがphp-fpmの設定で `pm.max_children` の数がどれくらいが適正なのかがわからないことでした。

調べてみると大体がメモリ数から算出する方法だったのですが、一部CPUのコア数に合わせるなどもあり正解がわかりませんでした。

メモリ数から算出する方法だとCPUがボトルネックになりやすく性能が落ちてしまい、コア数に合わせるとDB待ちのときに遊んでしまうように見えました。

基本的には負荷試験をやらないと適正な値はわからないように思えました。

このあたり詳しい方がいらっしゃれば教えていただけるとありがたいです。