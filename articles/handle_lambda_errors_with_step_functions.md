---
title: "LambdaのエラーをStep Functionsでハンドリングする"
emoji: "🎣"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS"]
published: true
---

# はじめに

Lambdaのエラー処理と書きましたが対象はもともと非同期で呼ばれる前提のLambdaのお話です。同期的に呼ぶLambdaであれば呼び出し元でエラーハンドリングしましょう。

# Lambdaのみのエラー処理

Lambdaでエラー時の挙動を変更するにはイベントの最大有効期間か再試行の回数を変えるくらいしかありません。


![load-test_figure](https://github.com/wim-web/my_zenn/blob/master/image/handle_lambda_errors_with_step_functions/async_setting.png?raw=true)

2つの違いは以下になります。

- イベントの最大有効期間

Lambdaがスロットルされるか、Lambda自体がエラーを返したとき(呼び出せなかった)はいったんキューに戻されるが、そのときにどれだけキューに保持するか。

再試行間隔は1回目が1秒で、その後最大5分まで指数関数的に増加します。

- 再試行

Lambda内のコードがエラーを返したときに何回再試行するか。

再試行間隔は1回目が1分間で、2回目が2分間と固定となっています。


上記の設定した回数再試行してもLambdaが成功しなかった場合はDLQ or 失敗時送信先で設定されたサービスに情報が渡されます。現時点で指定できるのはSNS, SQS, Lambda, Event Bridgeになります。

ここまで説明したようにそこまでエラーハンドリングに柔軟性があるわけではありません。たとえば、関数のエラーの種類によって再試行するかどうかを決定できません。

# Step Functionsでエラー処理

公式にもあるとおりStep FunctionsでLambdaを起動することによりエラー処理を行うことができます。

[Step Functionsのユースケース](https://docs.aws.amazon.com/ja_jp/step-functions/latest/dg/welcome.html#application)

Step FunctionsはWorkflow Studioを使って視覚的に構築できますが、個人的にコードで書いたほうがわかりやすいのでコードで説明します。([Step Functionsの定義](https://docs.aws.amazon.com/ja_jp/step-functions/latest/dg/concepts-states.html))

![load-test_figure](https://github.com/wim-web/my_zenn/blob/master/image/handle_lambda_errors_with_step_functions/workflow_studio.png?raw=true)

## try-catch

`Catch` を指定することでエラーをキャッチして特定の処理をすることが可能になります。`Resource` で対象のLambdaを指定しています。

ここで注意するのはここのLambdaの呼び出しは同期的だということです。非同期にしてしまうとStep Functionsでエラー処理できないためです。なので、Lambda側でDLQなどの非同期時の設定していても動作しません。

```json
{
  "Comment": "This is Example",
  "StartAt": "First",
  "States": {
    "First": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:error",
      "End": true,
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "Next": "Handle"
        }
      ]
    },
    "Handle": {
      "Type": "Pass",
      "End": true
    }
  }
}
```

`ErrorEquals` でリトライしたいエラーを定義できます。 `States.ALL` はすべてのエラーを表します。以下のようにエラーの種類によって動作を変えることができます。

```json
"Catch": [ {
   "ErrorEquals": [ "SomeError" ],
   "Next": "Handle"
}, {
   "ErrorEquals": [ "States.ALL" ],
   "Next": "EndState"
} ]
```

## Lambdaのリトライ処理をする

以下がLambdaを起動しつつエラー処理するStep Functionsの例です。`Retry` でリトライ時の挙動を定義しています。


```json
{
  "Comment": "This is Example",
  "StartAt": "First",
  "States": {
    "First": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:error",
      "End": true,
      "Retry": [
        {
          "ErrorEquals": [ "States.ALL" ],
          "IntervalSeconds": 2,
          "MaxAttempts": 2,
          "BackoffRate": 3
        }
      ]
    }
  }
}
```

`Retry` も `Catch` のようにエラーの種類によって動作を変更できます。

```json
"Retry": [ {
    "ErrorEquals": [ "ErrorA", "ErrorB" ],
    "IntervalSeconds": 1,
    "BackoffRate": 2.0,
    "MaxAttempts": 2
}, {
    "ErrorEquals": [ "ErrorC" ],
    "IntervalSeconds": 5
} ]
```

`IntervalSeconds`, `MaxAttempts`, `BackoffRate` がリトライ回数・間隔の設定になります。

n回目のリトライ時のインターバルは以下になります。

```
// 1 <= n <= MaxAttempts
IntervalSeconds * (BackoffRate)^(n-1)
```

これらを組み合わせることでリトライ処理もある程度柔軟に対応できます。(ちなみにMaxAttemptsの上限は99999999です。)

[Error handling in Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html)

## Lambdaのリトライしつつなにか処理をする

上記でLambdaのエラー時にリトライする方法を紹介しましたが、エラーになったらSNSにputしつつリトライするといったようなことはできません。

主に2通りのやり方があります。


### Step Functionsをネストする

Step Functionsは他のStep Functionsを呼び出すことができるのでそれを利用する方法です。
 
`.sync` を付けて同期的に呼び出しエラーがあればリトライするといったことが可能になります。

```json
{
  "Comment": "This is Example",
  "StartAt": "First",
  "States": {
    "First": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution.sync",
      "Parameters": {
        "StateMachineArn": "arn:aws:states:us-east-1:000000000000:stateMachine:SomeStatemachine",
        "Input": {
          "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$": "$$.Execution.Id"
        }
      },
      "End": true,
      "Retry": [
        {
          "ErrorEquals": ["States.ALL"],
          "IntervalSeconds": 2,
          "MaxAttempts": 4,
          "BackoffRate": 4
        }
      ]
    }
  }
}
```

デメリットとしてはStep Functionsを呼び出すのに多少時間がかかる場合があるので、そこまで複雑でない処理の場合は次の例でもよいかもしれません。

### Parallelを使う

Parallelは本来並列に処理するためのものなのですが、中身を1つだけにすることでTaskをネストさせているのと同じようなことができます。


```json
{
  "Comment": "This is Example",
  "StartAt": "First",
  "States": {
    "First": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "Nest1",
          "States": {
            "Nest1": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:us-east-1:000000000000:function:error",
              "Catch": [
                  {
                    "ErrorEquals": ["SomeError"],
                    "Next": "SNS"
                  }
               ],
              "End": true
            },
            "SNS": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                  "TopicArn": "arn:aws:sns:us-east-1:000000000000:sns",
                  "Message.$": "$"
                },
              "Next": "Raise"
            },
            "Raise": {
              "Type": "Fail",
                "Error": "SomeError"
            }
          }
        }
      ],
      "End": true,
      "Retry": [
        {
          "ErrorEquals": ["States.ALL"],
          "IntervalSeconds": 2,
          "MaxAttempts": 4,
          "BackoffRate": 4
        }
      ]
    }
  }
}
```

# まとめ

Step Functionsを使用することでLambdaのエラーを柔軟に処理できます。

しかし、デフォルトのクオータが150/sであることと、コスト的には決して安くはないので本当にStep Functionsでやるのかどうかはきちんと検討しましょう。
