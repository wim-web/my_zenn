---
title: "Locustでカスタムクライアントを作成する"
emoji: "🧞"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Python", "Locust"]
published: true
---

# はじめに

Locustで使えるクライアントはHTTPクライアントしか用意されておらず、AWS CLIでLambdaをinvokeしたものも計測したいなと思ったのでクライアントをカスタムする方法を調べました。

[HttpUser class](https://docs.locust.io/en/stable/writing-a-locustfile.html#httpuser-class)


# Lambdaクライアントを作成

[Testing non-HTTP systems](https://docs.locust.io/en/stable/testing-other-systems.html) に例が載っていますが重要なのは `request_meta` になります。

以下がboto3を使ってLambdaをinvokeしつつLocustで計測するコードになります。

```py
from locust import task, HttpUser, constant
import boto3
import time
import json


class LambdaClient:
    def __init__(self, request_event) -> None:
        self._request_event = request_event

    def start(self, host):
        start_time = time.perf_counter()
        request_meta = {
            "request_type": "lambda",
            "name": "lambda",
            "response_length": 0,
            "response": None,
            "context": {},
            "exception": None,
        }
        try:
            request_meta["response"] = boto3.client("lambda").invoke(
                FunctionName=host, InvocationType="RequestResponse", Payload=json.dumps({'name': 'bob'}))
        except Exception as e:
            request_meta["exception"] = e
        request_meta["response_time"] = (
            time.perf_counter() - start_time) * 1000
        self._request_event.fire(**request_meta)
        return request_meta["response"]


class LambdaUser(HttpUser):
    abstract = True

    def __init__(self, environment):
        super().__init__(environment)
        self.client = LambdaClient(request_event=environment.events.request)


class MyUser(LambdaUser):

    wait_time = constant(1)

    @task
    def some_lambda(self):
        self.client.start(self.host)

```

`User` や `HttpUser` を継承したクラスの `__init__` に `environment` が渡ってくるので、その中の `events.request` を使うことが重要になります。

Clientで `request_meta` で定義されているdictに実際のレスポンスの内容や、計測したtimeを格納して、イベントさせるときに引数として渡すことでGUIのグラフなどに情報を渡すことができ表示されます。

公式のドキュメントでは `__getattr__` 経由でイベントを発火させていますが、とくに経由させる必要はなく、必要な情報をrequest metaとしてイベント発火時に渡すだけで大丈夫です。
