---
title: "M1 Macでlimaを使ってDockerを使う"
emoji: "🐳"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Docker", "Lima", "macOS"]
published: true
---

# はじめに

M1のMacBook Airを買ったので、せっかくならとlimaを使ってDockerを動かしてみようとやってみました。

<https://github.com/lima-vm/lima>

環境はM1でIntel版で同じようにできるかは検証していません。

## Install lima

公式の[README](https://github.com/lima-vm/lima#getting-started)を参考にbrewでインストールすれば特に苦もなく入るはずです。

自分は[aqua](https://github.com/aquaproj/aqua)というツールを使っており、aquaでインストールができるのでaquaを使ってインストールしました。

:::details aquaでのインストール

依存ツールのqemuのインストール

```sh
brew install qemu
```

aquaのyml

```yml
# aqua - Declarative CLI Version Manager
# https://aquaproj.github.io/
registries:
  - type: standard
    ref: v2.22.0 # renovate: depName=aquaproj/aqua-registry
packages:
  - name: lima-vm/lima@v0.11.0
```

:::

`limactl --version`でインストールができたか試してみてください。

## VMを立ち上げる

設定ファイルは自動で吐き出してくれるのでとりあえず立ち上げてみます。

`limactl start`を実行すると対話形式になるので以下の順で進めます。

- Choose another example
- docker
- Proceed with the current configuration

limaの実行が完了すると、`~/.lima/docker/lima.yaml` が作成されて、VMインスタンスが作成されます。

ちなみに作成されたyamlのテンプレートは <https://github.com/lima-vm/lima/blob/master/examples/docker.yaml> にあります。

作成されているインスタンスの一覧は`limactl ls`で表示ができます。

```sh
NAME      STATUS     SSH                ARCH       CPUS    MEMORY    DISK      DIR
docker    Running    127.0.0.1:54249    aarch64    4       4GiB      100GiB    /Users/wim/.lima/docker
```

インスタンスに対してなにか操作を行いたいときはNAMEを引数に渡して実行します。
たとえばdockerインスタンスにログインする場合は`limactl shell docker`になります。

### limaコマンド

`limactl`以外に`lima`というコマンドがあります。

> limactl shell <INSTANCE> <COMMAND>: launch <COMMAND> on Linux.
>
> For the "default" instance, this command can be shortened as lima <COMMAND>. The lima command also accepts the instance name as the environment variable $LIMA_INSTANCE.

要するに`lima <COMMAND>`は`limactl shell <INSTANCE> <COMMAND>`のショートハンドになります。(<INSTANCE>はdefaultになります。)
<INSTANCE>を変更したい場合は、`LIMA_INSTANCE`環境変数にインスタンス名を設定します。

```sh
# limactl shell dockerと等しい
LIMA_INSTANCE=docker lima
```

以降はLIMA_INSTANCE=dockerが設定されている前提とします。

## ホスト側との接続

`limactl start`が終わったときに出てくる以下のメッセージ通りに行えばホスト側から操作が可能になります。

```sh
# unix socketの場所は各環境で異なるのでメッセージを確認してください
docker context create lima --docker "host=unix:///Users/wim/.lima/docker/sock/docker.sock"
docker context use lima
docker run hello-world
```

`docker compose`もそのまま動くはずです。<https://github.com/docker/awesome-compose> から適当なディレクトリをcloneして試してみてください。

## docker-composeのインストール

Docker Desktop for macだとdocker-composeは一緒になっているのでインストールする必要はないですが、CLIのdockerだけインストールした場合は別途インストールする必要があります。

```sh
mkdir -p ~/.docker/cli-plugins/
curl -SL <url> -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
```

<url>の部分は <https://github.com/docker/compose/releases> からOSやバージョンによって適切なURLを取得してください。

## limaの設定

limaの設定はyamlファイルで書き、yamlファイルの名前でインスタンス名が決まります。（maybe）

`limactl start hoge.yml`でインスタンスを立ち上げるとhogeという名前のインスタンスができ、`~/.lima/hoge`という設定用のディレクトリができます。

### チューニングする

どのような設定があるかは <https://github.com/lima-vm/lima/blob/master/examples/default.yaml> を参照してください。

この記事で作成したdockerインスタンスはいくつか修正したほうが良い箇所があります。
たとえばファイルのマウントは以下のようになっています。

```yml
mounts:
- location: "~"
- location: "/tmp/lima"
  writable: true
```

ホスト側の`~`をマウントしている箇所はwritableになっておらずread-onlyになっているためwritableをtrueにしないと書き込みができません。

またメモリがデフォルトだと4Gibになっているので増やしたほうがいいでしょう。

```yml
memory: "8Gib"
```
