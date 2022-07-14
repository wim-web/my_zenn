---
title: "Rustの基本的なトレイト"
emoji: "🦔"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Rust"]
published: false
---

## Deref, DerefMut

参照外し演算子(`*`)の振る舞いをカスタムできます。

```rs
use std::ops::{Deref, DerefMut};

struct Wrapper {
    count: i32,
}

impl Deref for Wrapper {
    type Target = i32;

    fn deref(&self) -> &Self::Target {
        &self.count
    }
}

impl DerefMut for Wrapper {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.count
    }
}

fn main() {
    let mut w = Wrapper { count: 0 };
    *w += 30;
    assert_eq!(30, *w);
}
```

上の例だと有り難みがわかりませんが、`Box<T>`や`RC<T>`などのスマートポインタが普通の参照のように扱えるのはDerefトレイトのおかげです。

また参照解決型変換といって暗黙的に変換を行ってくれます。

```rs
fn main() {
    let b = Box::new("hoge");
    // &strを要求しているところに&Box<&str>を渡している
    assert_eq!(4, str_len(&b));
}

fn str_len(s: &str) -> usize {
    s.len()
}
```

## Default

`new`のように使えます。`..`を使うことで一部のフィールドは指定しつつ残りはデフォルトで埋めることもできます。

```rs
struct Component {
    v: Vec<u32>,
    name: String,
    enabled: bool,
}

impl Default for Component {
    fn default() -> Self {
        Self {
            v: Vec::default(),
            name: "default".to_string(),
            enabled: true,
        }
    }
}

fn main() {
    let c = Component::default();

    assert_eq!("default", c.name);
    assert!(c.enabled);
    assert!(c.v.is_empty());
    
    let c = Component {
        name: "mike".to_string(),
        ..Default::default()
    };

    assert_eq!("mike", c.name);
    assert!(c.enabled);
    assert!(c.v.is_empty());
}
```

## AsRef, AsMut

AsRef<T>を実装しているなら、その型から &Tを効率的に借用できます。

```rs
struct Any {
    text: String,
}

impl AsRef<String> for Any {
    fn as_ref(&self) -> &String {
        &self.text
    }
}

fn main() {
    let a = Any {
        text: "test".to_string(),
    };

    assert_eq!(b"test", string2byte(&a));
}

fn string2byte<'a, T: 'a + AsRef<String>>(s: &'a T) -> &'a [u8] {
    s.as_ref().as_bytes()
}
```

関数の引数に`AsRef<T>`の境界を設定することで柔軟に引数をとれます。

## Borrow, BorrowMut

Borrow<T>を実装しているなら、&Tを効率的に借用することができます。

```rs
use std::borrow::{Borrow, BorrowMut};

struct Counter {
    count: u32,
}

impl Borrow<u32> for Counter {
    fn borrow(&self) -> &u32 {
        &self.count
    }
}

impl BorrowMut<u32> for Counter {
    fn borrow_mut(&mut self) -> &mut u32 {
        &mut self.count
    }
}

fn main() {
    let mut c = Counter { count: 0 };

    increment(&mut c);

    assert_eq!(1, c.count);
}

fn increment<T: BorrowMut<u32>>(s: &mut T) {
    *s.borrow_mut() += 1;
}
```

これだけだとAsRefと一緒ですが（定義も一緒）、[Borrowのドキュメント](https://doc.rust-lang.org/std/borrow/trait.Borrow.html)に以下のように書いてあります。

> it needs to be considered whether they should behave identical to those of the underlying type as a consequence of acting as a representation of that underlying type.

要するにTとborrowで借用した&Tは同じ振る舞いをするべきだと書いてあります。書いてあるだけなので実装で強制することはできません。

[String](https://doc.rust-lang.org/std/string/struct.String.html)を見てもらえればわかるのですが、Borrowトレイトは`Borrow<str>`のみ実装されており、AsRefトレイトは`AsRef<[u8]>`, `AsRef<OsStr>`, `AsRef<Path>`, `AsRef<str>`が実装されています。

同じ振る舞いの一つにHashが等価かどうかがあります。元のStringと同じHashになるのはstrだけなのでBorrowには`Borrow<str>`しか実装されていません。

```rs
fn main() {
    let x = "hello".to_string();

    let mut hasher1 = DefaultHasher::default();
    let mut hasher2 = DefaultHasher::default();

    // borrow
    <std::string::String as Borrow<str>>::borrow(&x).hash(&mut hasher1);
    x.hash(&mut hasher2);

    assert_eq!(hasher1.finish(), hasher2.finish());

    // as_ref
    <std::string::String as AsRef<[u8]>>::as_ref(&x).hash(&mut hasher1);
    x.hash(&mut hasher2);

    assert_ne!(hasher1.finish(), hasher2.finish());
}
```

これのなにが嬉しいかというとHashMapはgetなどの関数のキーに`Borrow<Q>`の境界を設定してます。

```rs
pub fn get<Q: ?Sized>(&self, k: &Q) -> Option<&V>
where
    K: Borrow<Q>,
    Q: Hash + Eq, 
```

これによってキーをStringに設定した場合、&Stringと&strのどちらでも呼び出せることになります。AsRefにしてしまうとHashが等価でない`AsRef<[u8]>`なども渡せてしまうことになります。
