---
title: "VSCodeでGoのメソッド引数の補完が効かないときの対処法"
emoji: "😢"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["go", "vscode"]
published: true
---

## はじめに

VSCodeでGoを書いているのですが、以下の画像のようにメソッドを補完で入力した後に引数を入力しようとしても変数などの補完が一切出ない状態になっていました。

![補完されない](https://storage.googleapis.com/zenn-user-upload/7hg2kkbiyd1gc4ia6ufublw967cn)

調べてもなかなか原因がわからずEscキーを1回押すことでなんとかしていましたが、1ステップ増えてしまうのがどうしてもストレスなので頑張って調べてみました。

## 原因

いろいろ調べたところ関連issueを見つけました。

[x/tools/gopls: Autocompletion not working when typing function parameters](https://github.com/golang/go/issues/41845)

ざっくりいうとVSCodeの補完周りの機能がコンフリクトしてうまく補完がでなくなっているようでした。

## 対処法

VSCodeのsetting.jsonに以下を追加することで補完が出るようです。

```
"editor.suggest.snippetsPreventQuickSuggestions": false,
```

![補完される](https://storage.googleapis.com/zenn-user-upload/5c3ekgleypj60ut4jdpw828m84rb)

