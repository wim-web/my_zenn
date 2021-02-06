---
title: "なにもしてないのに壊れた？Terraformのデバッグ方法"
emoji: "🤯"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform"]
published: true
---

## Terraformが突然壊れた？

インフラをTerraform化して使わないときはdestroyして使っていました。

ある日、環境を立てたくなったのでapplyするとなぜかエラーになって立ち上がりません。

コミット履歴を見てもとくに変更点もなく、Terraformのバージョンを上げたなどもしていません。

以下がコードの抜粋とエラーメッセージです。


```hcl
resource "aws_instance" "web" {
  count                       = 1
  instance_type               = "m5.large"
  ami                         = data.aws_ami.web.id
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.id
}

resource "aws_instance" "batch" {
  count                       = 1
  instance_type               = "t2.small"
  ami                         = data.aws_ami.batch.id
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.batch.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.id
}
```

```
Error: Error launching source instance: InvalidParameterValue: Value (ec2) for parameter iamInstanceProfile.name is invalid. Invalid IAM Instance Profile name
        status code: 400, request id: xxxx-xxxxxx
```

こんな感じでiam_instance_profileを使いまわして異なるEC2を立てているのですが、奇妙なことに片方のEC2だけ立ち上がらなくなる現象に見舞われました。

とくにiam_instance_profileを変更したわけでもなく、まさになにもしてないのに壊れた状態となってしまいました。

Googleに聞いても再度実行すればいけたとか時間をおけばいけたとか書いてありましたがなかなか直らず。

## Terraformのデバッグ

Terraformの実行ログを吐き出して見てみることにしました。

`TF_LOG` と `TF_LOG_PATH` の環境変数に値をセットすればログを見れます。

[Debugging - Terraform by HashiCorp](https://www.terraform.io/docs/internals/debugging.html)

(以下fish)

```
set -x TF_LOG TRACE
set -x TF_LOG_PATH hoge.txt
```

環境変数をセットしてapplyを実行してログを眺めてみてみるとエラーメッセージが残っていました。

```
<Response><Errors><Error><Code>InsufficientInstanceCapacity</Code><Message>Insufficient capacity for instance type m5.large</Message></Error></Errors><RequestID>00eac3ec-cb1e-4fd3-9149-0ece31a4f625</RequestID></Response>
```

立てようとしたAZで特定のインスタンスタイプのAWS側の容量が足らずエラーになってたようです。

これなら片方だけエラーになるのも、Googleに聞いて出てきた時間をおけば解決するというのにも納得です。

とりあえずAZを変更して事なきを得ました。

Terraformが突然壊れたらログを出力してみましょう。