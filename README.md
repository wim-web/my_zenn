# For Zenn

Zennとの連携用Repository

[my articles in zenn](https://zenn.dev/wim)

## required

- Docker
- [cargo-make](https://github.com/sagiegurari/cargo-make)

## how to start

```sh
makers welcome
makers preview
```

you see at <http://localhost:8888>

### write article

```sh
makers article -- --slug <arg>
```

### run text-lint

```sh
makers tl
```

### execute zenn command

```sh
makers zenn <arg>
```
