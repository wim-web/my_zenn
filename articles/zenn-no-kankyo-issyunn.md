---
title: "zenn-cli + reviewdog + textlint + GitHub Actions を爆速で作成"
emoji: "🏃"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["zenn", "githubactions"]
published: true
---

## はじめに

こちらの記事は [zenn-cli + reviewdog + textlint + GitHub Actions で執筆体験を最高にする](https://zenn.dev/serima/articles/4dac7baf0b9377b0b58b) を読んで環境を構築してみた記事です。

[zenn-docker](https://github.com/wim-web/zenn-docker) を使用することで爆速で環境と構築できるようにしました。

## セットアップ

タスクランナーに[cargo-make](https://github.com/sagiegurari/cargo-make)を使用していますので、インストールしておくと爆速で環境を構築できます。cargo-makeがなくても構築できますが当記事ではcargo-make前提で書いていきます。

まずは[zenn-docker](https://github.com/wim-web/zenn-docker)を任意のディレクトリにcloneします。

```
git clone git@github.com:wim-web/zenn-docker.git .
```

cloneが完了したら初期化をします。

```
makers welcome
```

これでdockerのビルドと、npmのインストール、zenn-cliの初期化が完了します。

zenn-cliのpreviewを立ち上げます。

```
makers preview
```

http://localhost:8888 にアクセスをしてプレビューが表示されれば完了です！

これでブランチを切り、PRを作成することでtextlint + reviewdogが走るようになっているはずです。

## textlint

リポジトリにあるtextlintのルールは基本的なものしか入っていません。

textlintのルールは `.textlintrc` を編集することで変更できます。また、違うルールを使用したい場合は `npm` でインストールすることで使用できます。