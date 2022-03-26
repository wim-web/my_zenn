---
title: "PHP_CodeSnifferのルールを作ってみる"
emoji: "👶"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["PHP"]
published: true
---

## はじめに

CodeSnifferを導入するときにはプリセットのルールやWeb上で公開されているルールを使うことがほとんどだと思います。

しかしいい感じのルールがなくて困ってつくろうとしてもどうやっていいかわからないと思います。

簡単なルールなら自分で作れるようにしてしまいましょう。

この記事ではアロー関数のルールを作成します。fnキーワードのあとに空白をいれるとエラーにします。

```php
// OK
fn() => 1;
// NG
fn () => 2;
```

(PSRにアロー関数のコーディング規約がなく自作しようと思ったのがきっかけです。)

公式でチュートリアル的な記事もあるのでそちらを踏襲しながら進めたいと思います。

https://github.com/squizlabs/PHP_CodeSniffer/wiki/Coding-Standard-Tutorial

GitHubに成果物をあげてます。

https://github.com/wim-web/my_code_sniffer

## 自作してみる

### ディレクトリ構成

`MyStandard/` にファイルなどを配置します。 `MyStandard` の名前はなんでも大丈夫です。

```
MyStandard
├── Sniffs
│     └── ArrowFunction
│            └── DisallowSpaceAfterFnKeywordSniff.php
└── ruleset.xml
```

`MyStandard/` 直下に `ruleset.xml` ファイルと `Sniffs` ディレクトリがあり必須になります。

`Sniffs` 直下にPHPファイルを置くこともできますが、カテゴライズのためにディレクトリを切って(今回でいう `ArrowFunction` ディレクトリ) 配置するほうがいいとおもいます。

### ruleset.xml

今回作成するルールセットの設定を書きます。

必要最低限のルールセットの名前と説明だけになっています。

```xml
<?xml version="1.0"?>
<ruleset name="MyStandard">
  <description>A custom coding standard.</description>
</ruleset>
```

### Sniffファイル

`DisallowSpaceAfterFnKeywordSniff.php` が実際に処理を行うファイルになります。

```php
<?php

/**
 *
 * PHP version 5
 *
 * @category  PHP
 * @package   PHP_CodeSniffer
 */

namespace Wim\Sniffs\ArrowFunction;

use PHP_CodeSniffer\Sniffs\Sniff;
use PHP_CodeSniffer\Files\File;

class DisallowSpaceAfterFnKeywordSniff implements Sniff
{
    /**
     * @return array(int)
     */
    public function register()
    {
        return array(T_FN);
    }

    public function process(File $phpcsFile, $stackPtr)
    {
        $tokens = $phpcsFile->getTokens();
        $nextToken = $tokens[$stackPtr + 1];

        if ($nextToken['content'] !== '(') {
            $error = 'Disallow space after fn';
            $fix = $phpcsFile->addFixableError($error, $stackPtr + 1, 'Found');

            if ($fix) {
                $phpcsFile->fixer->replaceToken($stackPtr + 1, '');
            }
        }
    }
}
```

`PHP_CodeSniffer\Sniffs\Sniff` をimplementsしなければいけません。このインターフェイスには `register` と `process` メソッドを持っています。

`register` メソッドに処理したいトークンを登録します([パーサトークンの一覧](https://www.php.net/manual/ja/tokens.php))。この登録したトークンがファイル内で見つかったときに `process` メソッドが実行されます。

今回はfnキーワードに対するトークンを登録しています。こうすることでCodeSnifferがファイルを解析したときにfnキーワードがあると `process` メソッドを実行してくれます。

`process` メソッド内の解説をします。

`$tokens = $phpcsFile->getTokens();` で解析中のファイルの全トークンを取得できます。

`$stackPtr` に現在のトークンのindexが入っているので、 `$tokens[$stackPtr]` で現在のトークンを取得できます。


```php
array(14) {
  ["code"]=>
  int(346)
  ["type"]=>
  string(4) "T_FN"
  ["content"]=>
  string(2) "fn"
  ["line"]=>
  int(2)
  ["column"]=>
  int(10)
  ["length"]=>
  int(2)
  ["level"]=>
  int(0)
  ["conditions"]=>
  array(0) {
  }
  ["scope_condition"]=>
  int(5)
  ["scope_opener"]=>
  int(10)
  ["scope_closer"]=>
  int(13)
  ["parenthesis_owner"]=>
  int(5)
  ["parenthesis_opener"]=>
  int(6)
  ["parenthesis_closer"]=>
  int(8)
}
```

`register` でfnトークン時に `process` が実行されるので、現在のトークンはfnを表すものになっています。

今回の目的はfnキーワードと括弧の間になにもいれたくないので次のトークンが `(` であるかどうかを判断すればよさそうです。

```php
// OK
fn() => 1;
// NG
fn () => 2;
```

if文でfnの次のトークンが `(` 以外だった場合エラーにする処理を書きます。

```php
if ($nextToken['content'] !== '(') {
    $error = 'Disallow space after fn';
    $fix = $phpcsFile->addFixableError($error, $stackPtr + 1, 'Found');

    if ($fix) {
        $phpcsFile->fixer->replaceToken($stackPtr + 1, '');
    }
}
```

`$phpcsFile->addError()` メソッドをつかってエラーメッセージを追加します。

今回使用しているメソッドは `$phpcsFile->addFixableError()` で、こちらのメソッドを使用すると `phpcbf` で自動修正できるようになります。

第一引数にエラーメッセージ、第二引数にエラーの箇所、第三引数は()内のメッセージの最後にくっつきます。

```
-------------------------------------------------------------------------------
FOUND 1 ERROR AFFECTING 1 LINE
-------------------------------------------------------------------------------
 18 | ERROR | [x] Disallow space after fn
    |       |     (Wim.ArrowFunction.DisallowSpaceAfterFnKeyword.Found)
-------------------------------------------------------------------------------
PHPCBF CAN FIX THE 1 MARKED SNIFF VIOLATIONS AUTOMATICALLY
-------------------------------------------------------------------------------
```

`addFixableError` の返り値で `phpcs` or `phpcbf` を判定しているので、 `true` のときに自動整形の処理を書きます。

```php
if ($fix) {
    $phpcsFile->fixer->replaceToken($stackPtr + 1, '');
}
```

今回はシンプルに次のトークン(空白想定)を空に置き換えています。こうすることで自動整形時に空白が取り除かれます。

以上でルールを自作できたのでルールを指定して実行すればルールが適用されるはずです。

```bash
phpcs --standard=MyStandard/ruleset.xml <対象ファイル>
```

## あとがき

ルールを自作する際はすでにある近いルールを参考にするのがいいです。

ルールが複雑になるほど処理も複雑になるのでできれば自分で書かずに済ませたいですね。