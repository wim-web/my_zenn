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

AsRefを実装した構造体からTの参照を取得できるようにします。

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

