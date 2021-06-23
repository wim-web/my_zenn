---
title: "Laravelのサービスプロバイダーが読み込まれるまで"
emoji: "💬"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Laravel"]
published: true
---

# 環境

laravel  7.30.4

# サービスプロバイダーが読み込まれるまで

laravelでは `index.php` を起点にしてリクエストを処理します。

```php
$response = $kernel->handle(
    $request = Illuminate\Http\Request::capture()
);
```

`$kernel->handle()` から順に処理を追っていくと `sendRequestThroughRouter()` 内の `$this->bootstrap()` で必要な初期化処理をしています。

```php
public function bootstrap()
{
    if (! $this->app->hasBeenBootstrapped()) {
        $this->app->bootstrapWith($this->bootstrappers());
    }
}
```

`$this->bootstrappers()` の返り値は `$bootstrappers` プロパティなので以下の配列になります。

```php
protected $bootstrappers = [
    \Illuminate\Foundation\Bootstrap\LoadEnvironmentVariables::class,
    \Illuminate\Foundation\Bootstrap\LoadConfiguration::class,
    \Illuminate\Foundation\Bootstrap\HandleExceptions::class,
    \Illuminate\Foundation\Bootstrap\RegisterFacades::class,
    \Illuminate\Foundation\Bootstrap\RegisterProviders::class,
    \Illuminate\Foundation\Bootstrap\BootProviders::class,
];
```

`bootstrapWith()` は渡された配列の中身を順にインスタンス化して、そのインスタンスの `bootstrap()` を呼んでいます。

```php
public function bootstrapWith(array $bootstrappers)
{
    $this->hasBeenBootstrapped = true;

    foreach ($bootstrappers as $bootstrapper) {
        $this['events']->dispatch('bootstrapping: '.$bootstrapper, [$this]);

        $this->make($bootstrapper)->bootstrap($this);

        $this['events']->dispatch('bootstrapped: '.$bootstrapper, [$this]);
    }
}
```

関係ありそうなものだけ見ていきます。


## RegisterProviders

`RegisterProviders::bootstrap()` は以下のようになっています。

```php
public function bootstrap(Application $app)
{
    $app->registerConfiguredProviders();
}

public function registerConfiguredProviders()
{
    $providers = Collection::make($this->config['app.providers'])
                    ->partition(function ($provider) {
                        return strpos($provider, 'Illuminate\\') === 0;
                    });

    $providers->splice(1, 0, [$this->make(PackageManifest::class)->providers()]);

    (new ProviderRepository($this, new Filesystem, $this->getCachedServicesPath()))
                ->load($providers->collapse()->toArray());
}
```

`app.providers` の配列を `'Illuminate\\'` から始まるかどうかでわけています。

```php
$providers = [
    [/* Illuminateから始まる */],
    [/* それ以外 */]
]
```

`PackageManifest` はcomposerでいれたライブラリに関するクラスでライブラリのサービスプロバイダーを読み込んでいます。`splice()` でコレクションの中身にねじ込んでいます。

```php
$providers = [
    [/* Illuminateから始まる */],
    [/* ライブラリ */],
    [/* それ以外 */]
]
```

この順番になっている意味としては、先頭から順に処理されるのであとから上書きできるように自作のサービスプロバイダーが一番後ろになるように調整されています。

`ProviderRepository::load()` に1次元配列として渡されていきます。

```php
public function load(array $providers)
{
    // bootstrap/cache/services.php にサービスプロバイダーの情報が
    // キャッシュとして保存しているのであればそれを読み込む
    $manifest = $this->loadManifest();

    if ($this->shouldRecompile($manifest, $providers)) {
        $manifest = $this->compileManifest($providers);
    }

    //...

    foreach ($manifest['eager'] as $provider) {
        $this->app->register($provider);
    }

    $this->app->addDeferredServices($manifest['deferred']);
}
```

キャッシュがない想定で `$this->compileManifest($providers)` を見ていきます。

```php
protected function compileManifest($providers)
{
    $manifest = $this->freshManifest($providers);

    foreach ($providers as $provider) {
        $instance = $this->createProvider($provider);

        if ($instance->isDeferred()) {
            foreach ($instance->provides() as $service) {
                $manifest['deferred'][$service] = $provider;
            }

            $manifest['when'][$provider] = $instance->when();
        }

        else {
            $manifest['eager'][] = $provider;
        }
    }

    return $this->writeManifest($manifest);
}
```

`freshManifest` は以下のように配列を作成しているだけです。

```php
    protected function freshManifest(array $providers)
    {
        return ['providers' => $providers, 'eager' => [], 'deferred' => []];
    }
```

`$instance->isDeferred()` で遅延プロバイダーかどうかで処理をわけています。`Illuminate\Contracts\Support\DeferrableProvider` インターフェイスを実装していれば遅延プロバイダーとして処理されます。(laravelのバージョンによって判定方法が違います)

`$this->writeManifest($manifest);` でキャッシュとしてファイルに書き込みます。

`load()` に戻って `$this->app->register($provider)` で実際にサービスプロバイダーを登録していく処理を見ていきます。

```php
public function register($provider, $force = false)
{
    // すでに登録済みなら早期リターンする
    if (($registered = $this->getProvider($provider)) && ! $force) {
        return $registered;
    }

    if (is_string($provider)) {
        $provider = $this->resolveProvider($provider);
    }

    $provider->register();

    if (property_exists($provider, 'bindings')) {
        foreach ($provider->bindings as $key => $value) {
            $this->bind($key, $value);
        }
    }

    if (property_exists($provider, 'singletons')) {
        foreach ($provider->singletons as $key => $value) {
            $this->singleton($key, $value);
        }
    }

    $this->markAsRegistered($provider);

    if ($this->isBooted()) {
        $this->bootProvider($provider);
    }

    return $provider;
}
```

`$provider->register()` で各サービスプロバイダーの `register()` を呼んで処理をします。(コンテナーへの登録など)

`$bindings` や `$singletons` プロパティがあればよしなにしてくれるようです。

`$this->isBooted()` は `Application::$booted` を見て判定しています。最初の場合は `false` なので実行されません。

これでサービスプロバイダーの登録が終わったので `load()` に戻って遅延プロバイダーの処理を見ていきます。

```php
public function addDeferredServices(array $services)
{
    $this->deferredServices = array_merge($this->deferredServices, $services);
}
```

`$deferredServices` プロパティに遅延プロバイダー名の配列をセットしているだけのようです。なので、遅延プロバイダーは `register()` が呼ばれないので内部の処理もされない(遅延される)ことになります。

## BootProviders

`RegisterProviders` でサービスプロバイダーの `register()` は処理されましたが、 `boot()` は未だ処理されていない状態です。

`BootProviders` でその処理をします。

```php
public function bootstrap(Application $app)
{
    $app->boot();
}

// Application Class
public function boot()
{
    if ($this->isBooted()) {
        return;
    }

    $this->fireAppCallbacks($this->bootingCallbacks);

    array_walk($this->serviceProviders, function ($p) {
        $this->bootProvider($p);
    });

    $this->booted = true;

    $this->fireAppCallbacks($this->bootedCallbacks);
}
```

`array_walk()` の箇所で各サービスプロバイダーの `boot()` が呼ばれていきます。(遅延プロバイダー除く)

`$this->fireAppCallbacks()` で処理を挟み込めるようになっているようです。

## サービスプロバイダー読み込みまとめ

- サービスプロバイダーの `register()`,  `boot()` が処理される
- 遅延サービスプロバイダーは処理されず、`Application#$deferredServices` に格納されている

# 遅延サービスプロバイダーの読み込み

遅延サービスプロバイダーはコンテナーで対象のインスタンスを解決しようとしたときに読み込まれるので、`Application::make()` を見てみましょう。

```php
public function make($abstract, array $parameters = [])
{
    $this->loadDeferredProviderIfNeeded($abstract = $this->getAlias($abstract));

    return parent::make($abstract, $parameters);
}
```

`$this->getAlias()` でエイリアスの解決をしていますが、まだサービスプロバイダーは読み込まれてないので変換されずに返却されます。

```php
protected function loadDeferredProviderIfNeeded($abstract)
{
    if ($this->isDeferredService($abstract) && ! isset($this->instances[$abstract])) {
        $this->loadDeferredProvider($abstract);
    }
}

public function loadDeferredProvider($service)
{
    if (! $this->isDeferredService($service)) {
        return;
    }

    $provider = $this->deferredServices[$service];

    if (! isset($this->loadedProviders[$provider])) {
        $this->registerDeferredProvider($provider, $service);
    }
}
```

`$this->registerDeferredProvider()` で通常のサービスプロバイダーとおなじように `register()`, `boot()` が呼ばれて処理されます。


# サービスプロバイダー読み込み順

1. 通常のサービスプロバイダー(Illuminate)
1. 通常のサービスプロバイダー(Library)
1. 通常のサービスプロバイダー(Own)
1. 遅延サービスプロバイダー(Illuminate)
1. 遅延サービスプロバイダー(Library)
1. 遅延サービスプロバイダー(Own)

サービスプロバイダーの読み込み順は上の順番なので、同じkey名でコンテナーに登録した場合は後のサービスプロバイダーに上書きされます。

ただ `app()->instance()` でバインドしているものは後の遅延サービスプロバイダーで上書きできません。

```php
protected function loadDeferredProviderIfNeeded($abstract)
{
    if ($this->isDeferredService($abstract) && ! isset($this->instances[$abstract])) {
        $this->loadDeferredProvider($abstract);
    }
}
```

`! isset($this->instances[$abstract]` の部分が `false` になってしまい対象の遅延サービスプロバイダーが読み込まれません。
