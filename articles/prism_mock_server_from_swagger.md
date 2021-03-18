---
title: "OpenAPI(Swagger)からモックサーバーを作成できるPrismまとめ"
emoji: "🐳"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["OpenAPI", "Swagger"]
published: true
---

## はじめに

PrismとはStoplightがオープンソースとして提供しているOpenAPIからモックサーバーを立ち上げたりできるものです。

https://github.com/stoplightio/prism

SaaSとしても提供しているのでとりあえず触ってみたい人は使ってみるといいかもしれないです。

https://stoplight.io/api-mocking/

Prismをモックサーバーとして使用するときにちょっと詰まったところなどをまとめました。PrismはDockerで利用する想定です。

## 複数のファイルからサーバーを作成したい

PrismをDockerで起動するときのコマンドが以下になるのですが、 `api.oas2.yml` のように単一のファイルしか指定できません。

```bash
docker run --init -p 4010:4010 stoplight/prism:4 mock -h 0.0.0.0 api.oas2.yml
```

バージョン毎にファイルを分けている場合など複数のファイルをもとにモックサーバーを立てたい場合はおとなしくその分だけコンテナを立てるしかありません。

公式で紹介されているようにdocker-composeでproxyサーバー毎立ててしまうのが一番楽だと思います。(caddyはnginxなどでも大丈夫です)

https://meta.stoplight.io/docs/prism/docs/guides/multiple-documents.md

## レスポンスを出し分けたい

同じAPIでも正常系と異常系、同じ正常系でも中身が違うレスポンスが欲しくなると思います。

`-d` オプションでスキーマ定義に沿ったダミーデータを返してくれるものもありますが細かい制御はできません。

モックサーバーのAPIを叩くときに `Prefer` ヘッダーで値を指定することでそれなりにレスポンスを指定することができます。

### レスポンスコードを指定したい

たとえが以下のように200と400が定義されたAPIがあるとします。

```yaml
paths:
  /pets:
    get:
      summary: List all pets
      responses:
        '200':
          content:
            application/json:
              schema:
                type: object
                properties:
                  name:
                    type: string
        '404':
          content:
            application/json:
              schema:
                type: object
                properties:
                  type:
                    type: string
```

これで `/pets` を叩くと200のレスポンスが固定で返ってきて404は返ってきません。

ヘッダーに `Prefer: code=404` と付与して `/pets` を叩くことによって404のステータスコードのレスポンスが返ってきます。

### examplesを指定したい

固定レスポンスとしてexamplesを複数定義している場合もPreferヘッダーで指定できます。

```yaml
paths:
  /pets:
    get:
      summary: List all pets
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  name:
                    type: string
              examples:
                example-1:
                  value:
                    name: this is example 1
                example-2:
                  value:
                    name: this is example 2
```

ヘッダーに `Prefer: example=example-2` と付与して `/pets` を叩くことによってexample-2のレスポンスが返ってきます。

```json
{
    "name": "this is example 2"
}
```

注意点としては、exampleだけの指定だと200レスポンス内のexamplesしか探してくれないので、違うレスポンスコードのexamplesを指定したい場合はcodeも指定してあげないと意図した挙動になりません。

```bash
# 404のexample-2を指定
curl --location --request GET 'http://0.0.0.0:4010/pets' \
--header 'Prefer: code=404' \
--header 'Prefer: example=example-2'
```

### dynamicレスポンスを指定したい

`-d` オプションを指定して立ち上げることでダミーデータを返しくれるようになりますが、立ち上げ時に指定しなくてもPreferヘッダーで特定のAPIだけdynamicにすることもできます。

```bash
curl --location --request GET 'http://0.0.0.0:4010/pets' \
--header 'Prefer: dynamic=true'
```

同時にexampleを指定した場合はexampleが優先されるので注意してください。

レスポンス決定フローはこちらの画像が参考になります。

![response_flow](https://github.com/stoplightio/prism/blob/master/packages/http/docs/images/mock-server-dfd.png?raw=true)