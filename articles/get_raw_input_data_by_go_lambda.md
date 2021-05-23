---
title: "lambdaのインプットデータを生でほしいとき(golang)"
emoji: "😊"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Go", "AWS", "lambda"]
published: true
---

## golangでのlambdaの書き方

lambdaをgolangで書くときは `lambda.Start()` をmain関数に書いて処理を書いていくのがだいたいお決まりだと思います。

```go
package main

import (
        "fmt"
        "context"
        "github.com/aws/aws-lambda-go/lambda"
)

type MyEvent struct {
        Name string `json:"name"`
}

func HandleRequest(ctx context.Context, name MyEvent) (string, error) {
        return fmt.Sprintf("Hello %s!", name.Name ), nil
}

func main() {
        lambda.Start(HandleRequest)
}
```

lambdaに渡したいデータがあればjsonで渡してあげて、golangのコードでは構造体を定義してあげてハンドラーの引数にしてあげればよしなにしてくれます。

## 生データほしくない...?

のっぴきならぬ事情でlambdaに渡したjsonをそのまま別のなにかに投げつけたい場合に、いちいち構造体に変換してもらわなくていいので生のデータが欲しくなります。

そのようなときは `lambda.StartHandler()` を使えば解決です。

```go
func StartHandler(handler Handler) {
	StartHandlerWithContext(context.Background(), handler)
}
```

```go
type Handler interface {
	Invoke(ctx context.Context, payload []byte) ([]byte, error)
}
```

`lambda.StartHandler()` はHandlerインターフェイスを引数に持ちます。`Invoke`メソッドのpayloadに生データが入ってくるのでそれを使えば生データが取得できます。

```go
package main

import (
	"context"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
)

type RawHandler struct {
}

func (h *RawHandler) Invoke(ctx context.Context, payload []byte) ([]byte, error) {
	log.Println("---payload start---")
	log.Println(string(payload))
	log.Println("--- payload end ---")
	return []byte("completed"), nil
}

func main() {
	lambda.StartHandler(&RawHandler{})
}
```

こんな感じで使えばOKです。

`lambda.Start()` の実装が書いてあるlambdaパッケージの `entry.go` や `handler.go` は記述量も少ないので見てみるのもオススメです。