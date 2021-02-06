---
title: "Terraformでのloop処理の書き方（for, for_each, count）"
emoji: "👻"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform"]
published: true
---

## はじめに

Terraformで繰り返し処理がしたくて調べていると以下のようなコードを見つけました。

```
resource "aws_route53_record" "this" {
  for_each = {
    for d in var.domains : d.domain_name => {
      name   = d.resource_record_name
      record = d.resource_record_value
      type   = d.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 100
  type            = each.value.type
  zone_id         = var.zone_id
}
```

for_eachとforを同時に使っていたり、`=>` など見たことないものも現れ、さっぱりわかりませんでした。

とりあえずコピペしていじればいいやと適当にやるもTerraformに怒られまくったので泣く泣く調査することにしました。

## forとfor_each(とcount)

まずforはExpression(式)であり、for_eachとcountはMeta-Argument(?)という明確な違いがあります。

forは式なので値を返しますが、for_eachは返しません。

for_eachはresourceやmoduleでしか書けず、イメージとしてはresourceブロックごと繰り返すという感じになります。

```
# これは書ける
resource "aws_instance" "name" {
  for_each = []
}

# これは書けない
resource "aws_instance" "name2" {
  for = []
}
```

なのでforのみを使って複数リソースを作ることはできません。

## for式

mapとlistをforで回せるのでそれぞれ見ていきます。

### listをforで回してみる

まずは単純に配列の文字列をすべて大文字にしてみます。

```
locals {
  list = [
    "hoge",
    "fuga"
  ]
}

output "output_list" {
  value = [for l in local.list : upper(l)]
}
```

```
Changes to Outputs:
  + output_list = [
      + "HOGE",
      + "FUGA",
    ]
```

ifを使ってフィルタリングもできます。

```
locals {
  list = [
    "hoge",
    "fuga"
  ]
}

output "output_list" {
  value = [for l in local.list : upper(l) if l != "fuga"]
}
```

```
Changes to Outputs:
  + output_list = [
      + "HOGE",
    ]
```

indexが欲しい場合はこうします。

```
locals {
  list = [
    "hoge",
    "fuga"
  ]
}

output "output_list" {
  value = [for i, l in local.list : "${i}_${l}"]
}
```

```
Changes to Outputs:
  + output_list = [
      + "0_hoge",
      + "1_fuga",
    ]
```

listからmapを生成することもできます。

```
locals {
  list = [
    "hoge",
    "fuga"
  ]
}

output "output_map" {
  # value = {} の形になっている
  value = {for i, l in local.list : i => l}
}
```

```
Changes to Outputs:
  + output_map = {
      + 0 = "hoge"
      + 1 = "fuga"
    }
```

keyが同じになるものをまとめることもできます。（使い所はわかりません。）

```
locals {
  list = [
    "hoge",
    "fuga",
    "fuga"
  ]
}

output "output_map" {
  value = {for l in local.list : l => l...}
}
```

```
Changes to Outputs:
  + output_map = {
      + fuga = [
          + "fuga",
          + "fuga",
        ]
      + hoge = [
          + "hoge",
        ]
    }
```

### mapをforで回してみる

key, valueともに大文字にしてみます。

```
locals {
  map = {
    a = "about"
    b = "blow"
  }
}

output "output_map" {
  value = {for k, v in local.map : upper(k) => upper(v)}
}
```

```
Changes to Outputs:
  + output_map = {
      + A = "ABOUT"
      + B = "BLOW"
    }
```

mapでもifが使えます。

```
locals {
  map = {
    a = "about"
    b = "blow"
  }
}

output "output_map" {
  value = {for k, v in local.map : upper(k) => upper(v) if v != "blow"}
}
```

```
Changes to Outputs:
  + output_map = {
      + A = "ABOUT"
    }
```

mapからlistを生成することもできます。

```
locals {
  map = {
    a: "about"
    b: "blow"
  }
}

output "output_list" {
  value = [for k, v in local.map : v]
}
```

```
Changes to Outputs:
  + output_map = [
      + "about",
      + "blow",
    ]
```

### forまとめ

listやmapを繰り返し処理して新たなlistやmapを作成できます。

## count

v0.13からresource, moduleの両方で使えます。それ以前のバージョンではresourceのみです。

> Tip: Terraform 0.13 supports count on both resource and module blocks. Prior versions only supported it on resource blocks.


resourceブロックに `count = 数値` を指定することで指定した数値分のリソースを作成できます。
`count.index` でインデックスを取得できます。

```
resource "aws_iam_user" "example" {
  count = 2
  name = "user_${count.index}"
}

output "user_ids" {
  value = aws_iam_user.example.*.id
}
```

```
Outputs:

users = [
  "user_0",
  "user_1",
]
```

これだけだとインデックスでしか名前などを変更できないので、基本的にはlistと組み合わせて使う感じになると思います。

```
locals {
  names = [
    "hoge_user",
    "fuga_user"
  ]
}

resource "aws_iam_user" "example" {
  count = length(local.names)
  name = local.names[count.index]
}
```

こうすることで名前などもある程度自由に指定できます。

## for_each

for_eachはv0.12.6で追加されて、moduleでも使えるようになったのでv0.13のようです。

> Version note: for_each was added in Terraform 0.12.6. Module support for for_each was added in Terraform 0.13, and previous versions can only use it with resources.

### listをfor_eachで回してみる

count + listで行っていたことと同様のことがfor_eachでもできます。
値を取り出すときにインデックスを指定しなくてよくなるのでシンプルに書けます。

```
locals {
  names = [
    "hoge_user",
    "fuga_user"
  ]
}

resource "aws_iam_user" "example" {
  for_each = toset(local.names)
  name = each.key # each.value でも可
}
```

for_eachはmapか文字列のsetしか受け付けないためlistをそのまま使えず `toset()` を使ってsetにする必要があります。
`each.key` や `each.value` でkey-valueを参照でき、setの場合はどちらも同じ値になります。

:::message
あとからでてくるdynamic block内では文字列以外のsetも使えるようです。
:::

### mapをfor_eachで回してみる

mapを使うことでkeyとvalueのそれぞれを参照できるようになり、より柔軟にリソースの設定が行なえます。

```
locals {
  users = {
    hoge_user = "/hoge/",
    fuga_user = "/fuga/"
  }
}

resource "aws_iam_user" "example" {
  for_each = local.users
  name = each.key
  path = each.value
}
```

### dynamic blockとfor_each

特定のリソースでは繰り返し可能な設定があります。

```
resource "aws_autoscaling_group" "example" {
  # ...

  tag {
    key                 = "Name"
    value               = "example-asg-name"
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = "user-service"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }
}
```

これらをfor_eachを使って書くことができます。

```
locals {
  standard_tags = {
    Name        = "example-asg-name"
    Component   = "user-service"
    Environment = "production"
  }
}

resource "aws_autoscaling_group" "example" {
  
  min_size = 0
  max_size = 0

  dynamic "tag" {
    for_each = local.standard_tags
		
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
```

いままでのfor_eachだと `each.key` で参照できていましたが、 dynamic blockだと `tag.key` のように `block名.key` でないと参照できません。

## forとfor_eachの組み合わせ

forは式でlistやmapを返すのでfor_eachと組み合わせることができます。

```
locals {
  names = [
    "hoge",
    "fuga"
  ]
}

resource "aws_iam_user" "example" {
  for_each = {for name in local.names : name => upper(name) }
  name = each.key
  tags = {
    "Name" = each.value
  }
}
```

## まとめ

forは式なので値を返すことができます。
resourceを繰り返したい場合はfor_eachかcountを使用します。
forとfor_eachは組み合わせることができます。