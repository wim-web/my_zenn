---
title: "Renovateの基本的な設定方法など"
emoji: "🦁"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Renovate"]
published: true
---

随時更新するかもしれません。

## config:base

`config:base`はRenovateが用意しているプリセットです。`config:js-app`や`config:js-lib`などもあります。

[Renovate Docs: Full Config Presets](https://docs.renovatebot.com/presets-config/)

各プリセットの詳細は以下から確認できます。

[Renovate Docs: Default Presets](https://docs.renovatebot.com/presets-default/)


https://github.com/renovatebot/presets/blob/dda2282e5a53982daea09489d622eedc174243e2/packages/renovate-config-config/package.json#L16-L36

## Dependency Dashboard

[Renovate Docs: Dependency Dashboard](https://docs.renovatebot.com/key-concepts/dashboard/)

設定ファイルに以下の記述をするとDependency Dashboardというissueが立ち使えるようになります。  `config:base`をextendsしている場合は自動的に有効になっています。

```json
{
  "extends": [":dependencyDashboard"]
}
```

or

```json
{
  "dependencyDashboard": true
}
```

![dependency_dashboard](https://github.com/wim-web/my_zenn/blob/master/image/renovate_no_settei_wo_shirabetayo/dependency_dashboard.png?raw=true)


## Managers

[managers](https://docs.renovatebot.com/modules/manager/)という概念があります。managersを使うことによって依存関係を検出できます。

npmやcomposer,cargoなどのよく使われるmanagersはRenovate側で設定してくれています。ほとんどのmanagersはデフォルトで有効になっているためRenovateをセットアップするだけで依存関係の検出が開始されます。

managersが用意されていない場合はregex managerを使うことで柔軟に設定できます。

### regex

[Custom Manager Support using Regex](https://docs.renovatebot.com/modules/manager/regex/)

正規表現にマッチさせることで依存関係を検出します。正規表現の名前付きキャプチャという機能を使うので知っているとスムーズです。

regexの確認は https://regex101.com/ のようなサイトを利用すると便利です。

regexMangersに必須のfieldは`fileMatch`と`matchStrings`です。しかし、正規表現の書き方によってさらにfieldが必要になることもあります。（以下の設定は動きません。）

```json
{ 
    "regexManagers": [
    {
      "fileMatch": ["^Dockerfile$"],
      "matchStrings": ["ENV YARN_VERSION=(?<currentValue>.*?)\\n"],
    }
  ]
}
```

Renovateが依存関係の更新に必要な情報は以下になります。

- dependency's name
- which datasource
- which version scheme
- currentValue

---

#### datasource

[Renovate: Datasources](https://docs.renovatebot.com/modules/datasource/)

datasourceはどこから依存関係などの情報を検索するかを指定します。

たとえば、npmを指定すれば[npm](https://www.npmjs.com/)からで、packagistを指定すると[packagist](https://packagist.org/)から検索をします。

#### dependency's name

datasourceでどのような名前で検索するかを指定します。(≒ パッケージ名)

たとえば[zennのcli](https://www.npmjs.com/package/zenn-cli)を更新対象にしたい場合は、datasourceをnpmとして、dependency's nameをzenn-cliとします。

#### version scheme

[Renovate: supported-versioning](https://docs.renovatebot.com/modules/versioning/#supported-versioning)

どのような形式でバージョンを指定するかの設定です。デフォルトはsemverです。

#### currentValue

現在指定しているバージョンです。

```
ENV DOCKER_VERSION=19.03.1
```

現在のバージョンの`19.03.1`を更新する必要があるかどうかを判定します。

---

以上をRenovateが解釈できるように設定するのですが、正規表現で抜き出すパターンとテンプレートでfieldとして指定するやり方があります。

#### matchStringsで抜き出す場合

以下を名前付きキャプチャで抜き出します。（versioningはデフォルトでsemverなので必須ではない。）

- depName
- datasource
- versioning
- currentValue

```json
{
  "regexManagers": [
    {
      "fileMatch": ["^Dockerfile$"],
      "matchStrings": [
        "datasource=(?<datasource>.*?) depName=(?<depName>.*?)( versioning=(?<versioning>.*?))?\\sENV .*?_VERSION=(?<currentValue>.*)\\s"
      ]
    }
  ]
}
```

この設定は以下のようなテキストにマッチします。

```
# renovate: datasource=docker depName=docker versioning=docker
ENV DOCKER_VERSION=19.03.1
```

#### テンプレートで指定する場合

以下のfieldを指定します。
（currentValueは正規表現のみです。）
（versioningはデフォルトでsemverなので必須ではない。）

- depNameTemplate
- datasourceTemplate
- versioningTemplate

```json
{
  "regexManagers": [
    {
      "fileMatch": ["^Dockerfile$"],
      "matchStrings": ["zenn-cli@(?<currentValue>.*)"],
      "depNameTemplate": "zenn-cli",
      "datasourceTemplate": "npm"
    }
  ]
}
```

matchStringsでdepNameだけ抜き出して、datasourceはテンプレートで指定などの設定も可能です。

#### depNameとpackageNameの違い

depNameを使ってdatasourceから検索すると書きましたが正確には異なります。

本来はpackageNameを使うのですが、packageNameを指定していない場合はdepNameがpackageNameとして使われます。depNameはPRのタイトルなどに使われるのでパッケージ名が長い場合などに指定するのがよさそうです。

## 補完

以下を設定ファイルに追記すると補完がある程度効くようになります。(VSCodeだけ？)

```json
{
    "$schema": "https://docs.renovatebot.com/renovate-schema.json"
}
```
