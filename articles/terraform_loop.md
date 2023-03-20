---
title: "Terraformでのloop処理の書き方（for, for_each, count）"
emoji: "👻"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform"]
published: true
---

## 環境

```bash
$ terrraform -v
Terraform v1.4.2
on darwin_arm64
```

## for, for_each, countの違い

まず[for](https://developer.hashicorp.com/terraform/language/expressions/for)はExpression(式)であり、[for_each](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)と[count](https://developer.hashicorp.com/terraform/language/meta-arguments/count)はMeta-Argumentといった明確な違いがあります。  
forは式なので値を返しますが、for_eachとcountは返しません。  
for_eachはresourceやmoduleでしか書けず、イメージとしてはresourceブロックごと繰り返すという感じになります。  

```hcl
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

## forの使い方

forは他のプログラミング言語のforと同じ感じで回せます。Pythonのリスト内包表記に似ています。
mapとlistをforで回せるのでそれぞれ見ていきます。

### listをforで回してみる

まずは単純に配列の文字列をすべて大文字にしてみます。

```hcl
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

```hcl
Changes to Outputs:
  + output_list = [
      + "HOGE",
      + "FUGA",
    ]
```

ifを使ってフィルタリングもできます。

```hcl
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

```hcl
Changes to Outputs:
  + output_list = [
      + "HOGE",
    ]
```

indexが欲しい場合はこうします。

```hcl
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

```hcl
Changes to Outputs:
  + output_list = [
      + "0_hoge",
      + "1_fuga",
    ]
```

listからmapを生成することもできます。

```hcl
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

```hcl
Changes to Outputs:
  + output_map = {
      + 0 = "hoge"
      + 1 = "fuga"
    }
```

forで回すと辞書順にソートされます。なのでforで生成されるのはsetでなくlistになります。
厳密にはmapやobjectの場合はキーや属性名で要素がソートされ、文字列のsetの場合はその値でソートされます。  
その他の型のsetの場合は任意の順序付けになりますが将来のバージョンで変更される可能性があります。

```hcl
locals {
  set = toset(["b", "a", "c", "fjpoe"])
}

output "list" {
  value = [for v in local.set : v]
}
```

```hcl
Changes to Outputs:
  + list = [
      + "a",
      + "b",
      + "c",
      + "fjpoe",
    ]
```

### mapをforで回してみる

key, valueともに大文字にしてみます。

```hcl
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

```hcl
Changes to Outputs:
  + output_map = {
      + A = "ABOUT"
      + B = "BLOW"
    }
```

mapでもifが使えます。

```hcl
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

```hcl
Changes to Outputs:
  + output_map = {
      + A = "ABOUT"
    }
```

mapからlistを生成することもできます。

```hcl
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

```hcl
Changes to Outputs:
  + output_map = [
      + "about",
      + "blow",
    ]
```

forで回してmapを作成するときはキーが重複できない制約があります。

```hcl
locals {
  users = {
    Mike = {
      role = "Admin"
    }
    Bob = {
      role = "Admin"
    }
    Alice = {
      role = "Developer"
    }
  }
}

output "role_user" {
  # Adminが重複するのでエラーになる
  value = { for name, user in local.users : user.role => name }
}
```

その場合は結果をグループ化できます。

```hcl
output "role_user" {
  # name -> name...
  value = { for name, user in local.users : user.role => name... }
}
```

```hcl
Changes to Outputs:
  + list = {
      + Admin     = [
          + "Bob",
          + "Mike",
        ]
      + Developer = [
          + "Alice",
        ]
    }
```

### forまとめ

listやmapを繰り返し処理して新たなlistやmapを作成できます。

## count

v0.13からresource, moduleの両方で使えます。それ以前のバージョンではresourceのみです。

> Tip: Terraform 0.13 supports count on both resource and module blocks. Prior versions only supported it on resource blocks.


resourceブロックに `count = 数値` を指定することで指定した数値分のリソースを作成できます。
`count.index` でインデックスを取得できます。

```hcl
resource "aws_iam_user" "example" {
  count = 2
  name = "user_${count.index}"
}

output "user_ids" {
  value = aws_iam_user.example.*.id
}
```

```hcl
Outputs:

users = [
  "user_0",
  "user_1",
]
```

これだけだと数値インデックスしか変数が使えないので、基本的にはlistと組み合わせて使います。

```hcl
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

## for_each

for_eachはv0.12.6で追加されて、moduleでも使えるようになったのでv0.13のようです。

> Version note: for_each was added in Terraform 0.12.6. Module support for for_each was added in Terraform 0.13, and previous versions can only use it with resources.

### listをfor_eachで回してみる

count + listで行っていたことと同様のことがfor_eachでもできます。
値を取り出すときにインデックスを指定しなくてよくなるのでシンプルに書けます。

```hcl
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

```hcl
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

```hcl
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

```hcl
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

```hcl
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

## loopをネストさせたい

[Terraformでネストしたloopを書く](https://zenn.dev/wim/articles/terraform_nest_loop)

## まとめ

forは式なので値を返すことができます。  
resourceを繰り返したい場合はfor_eachかcountを使用します。  
forとfor_eachは組み合わせることができます。  
