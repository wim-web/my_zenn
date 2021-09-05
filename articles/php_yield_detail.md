---
title: "PHPのyieldで生成されるGeneratorをコードを読んで理解してみる"
emoji: "🐷"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["PHP"]
published: true
---

## はじめに

yieldの使い方を調べていて実際に動かしてみたりしたのですが、主にsendメソッドの挙動がよくわからなかったのでPHPのコードを読んで調べてみました。

C言語はやったことがないので雰囲気でふんわり理解するのが目標でガチガチに調べているわけではありません。（それでもマニュアル以上の情報は得られたと思います。）

## 環境

PHP 8.2

## Generatorクラスの構造

Generatorクラスは `zend_generators.h` ファイルで以下のように定義されています。

```c
struct _zend_generator {
	zend_object std;

	/* The suspended execution context. */
    /* 多分クロージャがはいってる */
	zend_execute_data *execute_data;

	/* Frozen call stack for "yield" used in context of other calls */
	zend_execute_data *frozen_call_stack;

	/* yieldで返却する値 */
	zval value;
	/* yieldで返却するキー */
	zval key;
	/* returnで返却する値 */
	zval retval;
	/* sendした値をコピーする変数のポインタ */
	zval *send_target;
	/* Largest used integer key for auto-incrementing keys */
	zend_long largest_used_integer_key;

	/* Values specified by "yield from" to yield from this generator.
	 * This is only used for arrays or non-generator Traversables.
	 * This zval also uses the u2 structure in the same way as
	 * by-value foreach. */
	zval values;

	/* Node of waiting generators when multiple "yield from" expressions
	 * are nested. */
	zend_generator_node node;

	/* Fake execute_data for stacktraces */
	zend_execute_data execute_fake;

	/* ZEND_GENERATOR_* flags */
	zend_uchar flags;
};
```

## currentメソッド

currentメソッドは現在のyieldした値を取得します。  
なんど呼ばれてもジェネレーターが再開することはありません。

```php
$f = function () {
    yield 'hoge' => 9;
    yield 'fuga' => 8;
};

$g = $f();

echo $g->current(); // 9
echo $g->current(); // 9
```

`zend_generators.c` で以下のように実装されています。

```c
ZEND_METHOD(Generator, current)
{
	zend_generator *generator, *root;

	ZEND_PARSE_PARAMETERS_NONE();
    
    /* PHPでいう$thisを取得 */
	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

	zend_generator_ensure_initialized(generator);

	root = zend_generator_get_current(generator);
	if (EXPECTED(generator->execute_data != NULL && Z_TYPE(root->value) != IS_UNDEF)) {
		RETURN_COPY_DEREF(&root->value);
	}
}
```

:::message
ZEND_METHODはzim_##classname##_##nameで関数名を定義するので、
breakpointを貼りたい場合はzim_Generator_currentという名前で貼れます。
:::

ここで重要なのが `zend_generator_ensure_initialized(generator)` というメソッドです。名前のとおり初期化するメソッドです。

```c
static inline void zend_generator_ensure_initialized(zend_generator *generator)
{
	if (UNEXPECTED(Z_TYPE(generator->value) == IS_UNDEF) && EXPECTED(generator->execute_data) && EXPECTED(generator->node.parent == NULL)) {
		zend_generator_resume(generator);
		generator->flags |= ZEND_GENERATOR_AT_FIRST_YIELD;
	}
}
```

if文の中で初期化されているかどうかを判定しており、初期化されていなければ `zend_generator_resume(generator)` が呼ばれます。(2度目のcurrentメソッド以降は呼ばれない)

zend_generator_resumeはジェネレーターを再開するメソッドで、currentだけでなく他のメソッドでも頻繁に呼ばれるメソッドです。  
簡単に説明すると、次のyieldまで処理をすすめyieldしている値があればgenerator構造体のvalueやkeyに値をセットする処理をしています。

zend_generator_ensure_initializedによる初期化が終わるとgeneratorに処理結果が格納されているので `RETURN_COPY_DEREF(&root->value);` でyieldした値を呼び出しもとに返却します。  
なので、例の `$g->current()` の返り値は `9` になりechoで9が表示されます。

ここでの注意点ですが返却されるのはvalueだけでkeyは返却されないのでcurrentメソッドでkeyは取得できないことです。keyを取得したい場合はkeyメソッドを使用するか、[iteratorのように扱う](https://www.php.net/manual/ja/language.generators.syntax.php#control-structures.yield.associative)かになります。

:::message
keyメソッドはcurrentメソッドとほぼ同じで、最後にkey or valueを返却するかどうかの違いしかありません。
:::

## nextメソッド

nextメソッドはジェネレーターを再開します。currentメソッドだけではジェネレーターを進められないのでnextメソッドと組み合わせて使います。

> Generator::next() のコールは、 null を引数として Generator::send() をコールすることと同じ効果があります。

以下のように実装されています。currentメソッドと似ていますが初期化のあとにresumeしている点と値を返却しない点が主な違いです。

```c
ZEND_METHOD(Generator, next)
{
	zend_generator *generator;

	ZEND_PARSE_PARAMETERS_NONE();

	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

	zend_generator_ensure_initialized(generator);

	zend_generator_resume(generator);
}
```

最初にnextメソッドを呼ぶと初期化内でzend_generator_resumeが呼ばれ、そのあとにもう一度zend_generator_resumeが呼ばれるので注意が必要です。

```php
$f = function () {
    yield 9;
    yield 8;
};

$g = $f();

$g->next();
echo $g->current(); // 8
```

最初にnextメソッドを呼ぶのは分かりにくい（と思う）ので、currentメソッドを呼んだあとに使うのが直感的だと思います。

```php
$f = function () {
    yield 9;
    yield 8;
};

$g = $f();

echo $g->current(); // 9
$g->next();
echo $g->current(); // 8
```

## sendメソッド

sendメソッドは呼び出し元からジェネレーターに値を送ることができます。nextメソッドにも書きましたがnullを引数に渡すとnextメソッドと同様の挙動になります。

> Generator::next() のコールは、 null を引数として Generator::send() をコールすることと同じ効果があります。

```php
$f = function () {
    $str = yield 9;
    yield 'hoge' . $str;
};

$g = $f();

echo $g->current(); // 9
echo $g->send('send'); // hogesend
```

`zend_generators.c` で以下のように実装されています。

```c
ZEND_METHOD(Generator, send)
{
	zval *value;
	zend_generator *generator, *root;

    /* sendメソッドの実引数を取得 */
	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ZVAL(value)
	ZEND_PARSE_PARAMETERS_END();

	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

    /* 初期化 */
	zend_generator_ensure_initialized(generator);

	/* The generator is already closed, thus can't send anything */
	if (UNEXPECTED(!generator->execute_data)) {
		return;
	}

	root = zend_generator_get_current(generator);
	/* Put sent value in the target VAR slot, if it is used */
	/* ここで変数に値をコピーしている */
	if (root->send_target) {
		ZVAL_COPY(root->send_target, value);
	}

	zend_generator_resume(generator);

	root = zend_generator_get_current(generator);
	if (EXPECTED(generator->execute_data)) {
		RETURN_COPY_DEREF(&root->value);
	}
}
```

重要なところだけ抜き出して簡略化するとこんな感じです。

```c
ZEND_METHOD(Generator, send)
{
    /* 初期化 */
	zend_generator_ensure_initialized(generator);

	root = zend_generator_get_current(generator);
    /* 変数へのコピー */
    ZVAL_COPY(root->send_target, value);

    /* 再開 */
	zend_generator_resume(generator);

	root = zend_generator_get_current(generator);
    /* yieldした値の返却 */
    RETURN_COPY_DEREF(&root->value);
}
```

上のPHPでの例と合わせて説明すると、最初にcurrentメソッドが呼ばれているため初期化ではなにも行われずにジェネレーターは `$str = yield 9;` の部分を指したままになります。  
`root->sent_target` は `$str` 変数を指すのでそこに値をコピーすることでsendに渡した引数を `$str` にわたすことができます。  
コピーしたあとにresumeするので次のyieldまですすみ処理された結果が最終的にsendメソッドの返り値になります。

nextメソッド同様に最初に呼ばれた場合は初期化内でresumeが呼ばれるためわかりにくい挙動になります。

```php
$f = function () {
    $str = yield 9;
    yield 'hoge' . $str;
};

$g = $f();

echo $g->send('send'); // hogesend
```

```php
$f = function () {
    $str = yield 9;
    yield 'hoge' . $str;
};

$g = $f();

echo $g->current(); // 9
echo $g->send('send'); // hogesend
```

## rewindメソッド

rewindと名前がついていますがnextしてすすめたものを巻き戻せるわけではないです。  
使いみちはよくわからないです。

```c
ZEND_METHOD(Generator, rewind)
{
	zend_generator *generator;

	ZEND_PARSE_PARAMETERS_NONE();

	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

	zend_generator_rewind(generator);
}
```

`zend_generator_rewind()` は以下のように実装されています。

```c
static inline void zend_generator_rewind(zend_generator *generator)
{
	zend_generator_ensure_initialized(generator);

	if (!(generator->flags & ZEND_GENERATOR_AT_FIRST_YIELD)) {
		zend_throw_exception(NULL, "Cannot rewind a generator that was already run", 0);
	}
}
```

flagsでジェネレーターの状態を管理しており、`ZEND_GENERATOR_AT_FIRST_YIELD` 以外だとエラーを吐きます。そのフラグはどこで立てているかというと `zend_generator_ensure_initialized()` で立てています。

```c
static inline void zend_generator_ensure_initialized(zend_generator *generator)
{
	if (UNEXPECTED(Z_TYPE(generator->value) == IS_UNDEF) && EXPECTED(generator->execute_data) && EXPECTED(generator->node.parent == NULL)) {
		zend_generator_resume(generator);
		generator->flags |= ZEND_GENERATOR_AT_FIRST_YIELD;
	}
}
```

`ZEND_GENERATOR_AT_FIRST_YIELD` フラグは `zend_generator_resume()` 内でドロップされます。

```php
$f = function () {
    yield 1;
    yield 2;
};

$g = $f();

echo $g->current(); // 1
$g->rewind();
$g->next(); // firstフラグがドロップする
$g->rewind(); // throw error
```

## getReturnメソッド

ジェネレーターはreturn文で値を返せるがgetReturnメソッドを使って取得する必要があります。ジェネレーターが終了していなかったり、return文に到達していなかったりする場合に使用するとエラーになります。

```php
$f = function () {
    yield 1;
    return 'test';
};

$g = $f();

echo $g->current(); // 1
$g->next();
echo $g->getReturn(); // test
```

実装はこのような感じで `retval` にreturn文の値がセットされるのでセットされていればそれを返します。return文がない場合はnullがセットされます。

```c
ZEND_METHOD(Generator, getReturn)
{
	zend_generator *generator;

	ZEND_PARSE_PARAMETERS_NONE();

	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

	zend_generator_ensure_initialized(generator);
	if (UNEXPECTED(EG(exception))) {
		return;
	}

	if (Z_ISUNDEF(generator->retval)) {
		/* Generator hasn't returned yet -> error! */
		zend_throw_exception(NULL,
			"Cannot get return value of a generator that hasn't returned", 0);
		return;
	}

	ZVAL_COPY(return_value, &generator->retval);
}
```

:::message
retvalをセットしている箇所はzend_vm_execute.hのZEND_GENERATOR_RETURN_SPEC_CONST_HANDLERメソッドです
:::



## validメソッド

ジェネレーターが終了しているかどうかを判定できます。

```php
$f = function () {
    yield 'hoge';
    return 'finish';
};

$g = $f();

var_dump($g->valid()); // true
var_dump($g->current()); // hoge
var_dump($g->valid()); // true
$g->next();
var_dumo($g->current()); // NULL
var_dumo($g->valid()); // false
```

実装は以下の感じで `execute_data` で判定しています。

```c
ZEND_METHOD(Generator, valid)
{
	zend_generator *generator;

	ZEND_PARSE_PARAMETERS_NONE();

	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

	zend_generator_ensure_initialized(generator);

	zend_generator_get_current(generator);

	RETURN_BOOL(EXPECTED(generator->execute_data != NULL));
}
```

エラーがスローされたジェネレーターなども終了扱いになります。

```php
$f = function () {
    throw new Exception();
    yield;
};

$g = $f();

try {
    $g->current();
} catch (Exception $e) {
    // 握りつぶす
}

var_dump($g->valid()); // false
```

## throwメソッド

> 例外をジェネレータにスローして、ジェネレータを続行します。 この振る舞いは、現在の yield 式の部分を throw $exception 文に置き換えたのと同じになります。

```php
$f = function () {
    try {
        yield 1;
        yield 2;
    } catch (Exception $e) {
        yield $e->getMessage();
        yield 3;
    }
};

$g = $f();

echo $g->current(); // 1
echo $g->throw(new Exception('hoge')); // hoge
$g->next();
echo $g->current(); // 3
```

実装は以下のようになっており `zend_generator_throw_exception()` したあとに `zend_generator_resume()` しています。  
catch句でyieldをしていればそのままジェネレーターとして扱うこともできます。

```c
ZEND_METHOD(Generator, throw)
{
	zval *exception;
	zend_generator *generator;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_OBJECT_OF_CLASS(exception, zend_ce_throwable);
	ZEND_PARSE_PARAMETERS_END();

	Z_TRY_ADDREF_P(exception);

	generator = (zend_generator *) Z_OBJ_P(ZEND_THIS);

	zend_generator_ensure_initialized(generator);
    
    /* ジェネレータが閉じてないかの判定 */
	if (generator->execute_data) {
		zend_generator *root = zend_generator_get_current(generator);

        /* 呼び出し元から渡されたexceptionをthrowする */
		zend_generator_throw_exception(root, exception);

        /* catch句でyieldしてれば正常に再開できる */
		zend_generator_resume(generator);

		root = zend_generator_get_current(generator);
        /* catch句でyieldしてれば */
		if (generator->execute_data) {
			RETURN_COPY_DEREF(&root->value);
		}
	} else {
		/* If the generator is already closed throw the exception in the
		 * current context */
		zend_throw_exception_object(exception);
	}
}
```
