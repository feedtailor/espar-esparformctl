# esparformctl

espar-form をコマンドラインから操作する CLI です。

バイナリは本リポジトリの [Releases](https://github.com/feedtailor/espar-esparformctl/releases) で配布しています。

## インストール / アップデート

### 前提

- `curl` と `tar` が使えること

### スクリプトでインストール（macOS / Linux）

```sh
curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh | sh
```

スクリプトは OS と CPU アーキテクチャを自動判定して配置します。

バージョンやインストール先を変えたい場合:

```sh
ESPARFORMCTL_VERSION=v0.1.0 INSTALL_DIR=$HOME/.local/bin \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh)"
```

- `ESPARFORMCTL_VERSION`: 既定は `latest`。`v0.1.0` のように指定します（先頭の `v` は省略しても構いません）。
- `INSTALL_DIR`: 既定は macOS が `~/.local/bin`、Linux が `/usr/local/bin`。`~/.local/bin` が PATH に無い場合は、インストール後に表示される案内に従って PATH へ追加してください。

### アップデート

最新版に更新するには、インストールと同じスクリプトを再実行してください（既存のバイナリを上書きします）。

```sh
curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh | sh
```

### 手動インストール

[Releases](https://github.com/feedtailor/espar-esparformctl/releases) から
`esparformctl_<version>_<os>_<arch>.tar.gz`（Windows は `.zip`）を取得し、
展開して PATH の通ったディレクトリに置いてください。

### Windows

インストールスクリプトは Windows に対応していません。手動でインストールしてください。

1. [Releases](https://github.com/feedtailor/espar-esparformctl/releases) から
   `esparformctl_<version>_windows_amd64.zip`（Arm の場合は `_windows_arm64.zip`）を取得する
2. 展開して `esparformctl.exe` を取り出す
3. PATH の通ったフォルダに置く（または置いたフォルダを PATH に追加する）
4. PowerShell またはコマンドプロンプトで動作確認する

```powershell
esparformctl.exe --version
```

### 動作確認

```sh
esparformctl --version
esparformctl --help
```

## 使い方

```sh
# ログイン（アクセストークンを取得して保存します。--hostname を省略すると対話的に入力できます）
esparformctl login --hostname <あなたの hostname>

# formID・API キーの取得
esparformctl form list
esparformctl form get <formID>

# メールテンプレートの取得・更新（TOML）
esparformctl mail get <formID> > mail.toml       # 取得（編集してそのまま update に渡せます）
esparformctl mail update <formID> --mail-file mail.toml

# フォーム設定の取得・変更
esparformctl setting get <formID>
esparformctl setting set <formID> --allow-http=false
```

- 各コマンドは `--json` で機械可読な出力、`--yes` で確認のスキップに対応します。
- 書き込み系（`mail update` / `setting set`）は、適用前に変更内容を表示して確認します。
- アクセストークンは hostname ごとに分けて安全に保存し、出力やログには一切表示しません。

## profile（複数 hostname の切り替え）

複数の hostname のアクセストークンを同時に保持し、`--profile <name>` で切り替えられます。
使用する profile は次の順で決まります: `--profile` フラグ > 環境変数 `ESPARFORMCTL_PROFILE` > 設定の既定 profile > `default`。

```sh
esparformctl login --profile www  --hostname www.espar.biz
esparformctl login --profile shop --hostname shop.espar.biz
esparformctl --profile shop setting get <formID>
```
