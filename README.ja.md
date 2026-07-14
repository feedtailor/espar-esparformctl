# esparformctl

espar formを管理するCLIです。

- `--json`を指定するとJSON形式で出力します。
- 書き込み系（`mail update`/`setting set`/`form set`）は、適用前に変更内容を表示して確認します。
- 認証情報（アクセストークン）はプロファイルごとに分離して安全に保存し、出力やログには一切出しません。

## インストール

### スクリプト（macOS/Linux）

```sh
curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh | sh
```

バージョンやインストール先を指定する場合：

```sh
ESPARFORMCTL_VERSION=v1.2.3 INSTALL_DIR=$HOME/.local/bin \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh)"
```

スクリプトはOSとアーキテクチャを自動判定してバイナリを配置します（`curl`と`tar`が必要です）。

- `ESPARFORMCTL_VERSION`：`v1.2.3`のように指定します（先頭の`v`は省略しても構いません）。指定しない場合は最新版（`latest`）をインストールします。
- `INSTALL_DIR`：指定しない場合はmacOSでは`~/.local/bin`、Linuxでは`/usr/local/bin`に配置します。`~/.local/bin`が`PATH`にない場合は、インストール後に表示される案内に従って`PATH`に追加してください。

### アップデート

最新版に更新するには、インストールと同じスクリプトを再実行してください（既存のバイナリを上書きします）。

### 手動

[Releases](https://github.com/feedtailor/espar-esparformctl/releases)から
`esparformctl_<version>_<os>_<arch>.tar.gz`（Windowsは`.zip`）を取得し、展開して`PATH`の通ったディレクトリに置いてください。

### Windows

インストールスクリプトはWindowsに対応していません。手動でインストールしてください。

1. [Releases](https://github.com/feedtailor/espar-esparformctl/releases)から
   `esparformctl_<version>_windows_amd64.zip`（Armの場合は`_windows_arm64.zip`）を取得する
2. 展開して`esparformctl.exe`を取り出す
3. `PATH`の通ったフォルダに置く（または置いたフォルダを`PATH`に追加する）
4. PowerShellまたはコマンドプロンプトで動作確認する

```powershell
esparformctl.exe --version
```

### バージョン確認

```sh
esparformctl --version
```

## 認証（login）

```sh
# 対象サイトのホスト名でログイン
esparformctl login --hostname=<ホスト名>
# パスワードは端末の非表示プロンプトで入力します（引数では受け付けません）

# --hostnameを省略すると、対話端末ではホスト名もプロンプトで入力できます
esparformctl login
```

- `--hostname`を省略した場合、**対話端末ではプロンプト**（`hostname: `）から入力できます。
- **非対話**（パイプやリダイレクト）、`--password-stdin`または`--json`の指定時は、プロンプトが表示されないため`--hostname`が必須です（未指定の場合はエラー終了します）。

非対話環境（スクリプトやSkill）でパスワードを渡す場合：

```sh
printf '%s' "$PASSWORD" | esparformctl login --hostname=www.example.com --password-stdin
```

取得した認証情報は、設定ディレクトリの`credentials`ファイルにプロファイルごとに分離して保存されます。`--profile`を省略すると、`default`プロファイルが作成または更新されます。複数のホスト名を使い分ける方法については、[profile](#profile複数ホスト名の切り替え)を参照してください。保存先については、[設定ファイル](#設定ファイル)を参照してください。

## logout（プロファイルの削除）

保存された認証情報（プロファイル）を削除するには、`logout`を使います。

```sh
# 現在のプロファイルからログアウト（確認プロンプトあり。--yesでスキップ）
esparformctl logout

# プロファイルを指定してログアウト
esparformctl logout --profile shop

# スクリプトやSkillから（--jsonは--yes必須）
esparformctl logout --json --yes
```

## profile（複数ホスト名の切り替え）

**複数のホストに対応する認証情報を同時に保持**して使い分けられます。プロファイルの名前は`--profile`で指定します。

```sh
# サイトごとにプロファイルを作る（プロファイル名は自由に付けられます）
esparformctl login --profile=www --hostname=www.espar.biz
esparformctl login --profile=shop --hostname=shop.espar.biz

# 使用するプロファイルを指定して操作（--profile省略時はdefaultプロファイル）
esparformctl --profile=shop setting get espf

# シェルセッション単位で固定する場合は環境変数を使う
export ESPARFORMCTL_PROFILE=shop

# プロファイルの一覧
esparformctl profile list

# 削除（確認プロンプトあり。--yesでスキップ）
esparformctl profile delete shop
```

プロファイルの優先順位：**`--profile`フラグ > 環境変数`ESPARFORMCTL_PROFILE` > `default`**。

## コマンドリファレンス

### auth status — ログイン状態の確認

ログイン状態、使用中のプロファイル、ホスト名をまとめて確認できます。読み取り専用で、アクセストークンは出力されません。

```sh
esparformctl auth status [--json]
```

```json
{ "logged_in": true, "profile": "www", "hostname": "www.espar.biz",
  "token_expired": false, "expires_at": "2026-07-15T11:14:00+09:00", "source": "server" }
```

- **未ログインの場合も、エラーではなく状態として返します**（`logged_in`は`false`、その他のフィールドは`null`、終了コードは2）。読み取り専用のため、`--json`でも`--yes`は不要です。
- `--all`を指定すると、保存済みの全プロファイルの状態を一覧で確認できます（`--json`では`{"profiles": [...]}`形式）。一部のプロファイルの照会に失敗しても、他のプロファイルの結果は返り、失敗の内容は各エントリの`error`に示されます。全プロファイルがログイン済みなら終了コードは0、未ログインのプロファイルまたは照会に失敗したプロファイルが1件でもあれば終了コードは2です。`--profile`とは併用できません。

### form — フォームID/APIキーの取得

```sh
esparformctl form list [--json]
esparformctl form get <formID> [--json]
```

- 出力項目は`id`/`name`/`url`/`api_key`です（`get`は1件、`list`は`forms`配列）。
- `api_key`はHTMLに埋め込む**公開値**のため、マスクせずそのまま表示します。
- `api_key`をAIや自動化ツールに渡す場合、**AIの学習、テレメトリ、フィードバックには含めない**ようにしてください。

### form set — フォーム名・設置URLの変更

```sh
esparformctl form set <formID> --name="お問い合わせ（本番）"
esparformctl form set <formID> --url=https://www.example.com/contact/
```

- **指定したフラグのみ部分更新**します（未指定の項目は変更しません）。空の値（`--name=`/`--url=`）を指定すると、**値をクリア**します。
- `http`または`https`のURLのみ有効です（検証はサーバで行われ、不正な値は入力エラーになります）。
- 適用前に変更内容を表示して確認する流れは`setting set`と同じです。`--dry-run`と`--json --yes`も同様に使えます。
- `form get`が返す項目のうち、**`api_key`のみが読み取り専用**です。

### form logs — メール配信結果の照会（読み取り専用）

フォームのメール送信履歴（送信日時、通知または自動返信の種別、配信結果）を新しい順に表示します。「フォーム送信は成功したのにメールが届かない」という問題の切り分けに使えます。送信後も履歴が表示されない場合は、メールが生成されていません（テンプレートが未登録または無効）。履歴があり、`status`が失敗を示している場合は、配信上の問題です。

```sh
esparformctl form logs <formID> [--date <YYYY-MM[-DD]>] [--json]
```

```sh
# 直近の配信結果を確認する（最新20件）
esparformctl form logs espf

# 特定の日の全件（「この日の問い合わせのメールが届いていない」の調査）
esparformctl form logs espf --date 2026-07-08

# 月の全件をJSONで取得する
esparformctl form logs espf --date 2026-07 --json
```

- `--date`を指定しない場合は**最新20件**を表示します。`--date`で日（`YYYY-MM-DD`）または月（`YYYY-MM`）を指定すると、**その期間の全件**を表示します。ハイフンなし（`20260708`/`202607`）でも指定できます。
- **配信結果（`status`）は約10分間隔で非同期に反映**されます。送信直後は「未確定」（`--json`では`status`が`null`）になるため、時間をおいて再照会してください。
- `status`の主な値：`sent`/`deferred`/`bounced`/`expired`/`skipped`/`error`（将来追加されることがあります）。
- 照会対象は最新12か月分で、古い履歴が残っている場合は末尾に案内が表示されます（`--json`では`has_more`が`true`）。
- 宛先・差出人などの個人情報は表示されません。履歴の削除・変更はできません（読み取り専用）。
- 出力は1行1件なので、`head`/`tail`/`grep`や`jq`と組み合わせて絞り込めます。

### mail get — メールテンプレートの取得（TOML）

メールテンプレート（通知または自動返信）をTOMLで出力します。出力をそのまま`mail update --mail-file`に渡せます（`get`→編集→`update`）。

```sh
# 取得（TOMLで出力）
esparformctl mail get <formID>

# 取得→編集→適用
esparformctl mail get <formID> > mail.toml
$EDITOR mail.toml
esparformctl mail update <formID> --mail-file mail.toml

# JSON形式で出力
esparformctl mail get <formID> --json
```

- 出力の先頭には`etag = "..."`の行が含まれます。この行を削除せずに、出力をそのまま`mail update`に渡せます。
- **同時更新の検出**：出力先頭の`etag`行を使用し、`mail get`を実行してから`mail update`を実行するまでの間に、他のユーザーがフォームを変更していた場合は、`mail update`が自動的に警告します（`--json`では`warnings`に`stale_input`が含まれます）。警告が表示されても適用は続行されます（差分は常に最新の設定値と比較して表示されます）。`--dry-run`を使って、事前に差分と警告だけを確認することもできます。

### mail sample — TOMLひな型の出力（ログイン不要）

テンプレートをゼロから記述するためのコメント付きTOMLひな型を出力します。ログインやサーバへの接続は不要です。

```sh
# ひな型を出力→編集→適用
esparformctl mail sample > mail.toml
$EDITOR mail.toml
esparformctl mail update <formID> --mail-file mail.toml
```

- 「キーを書くと更新、`""`を書くとクリア、キーを書かない場合は変更なし」というルールをコメントで説明し、任意フィールドはコメントアウトした状態で出力します。**使わない行はコメントのままにしてください**（`""`のまま適用すると、該当する項目がクリアされます）。
- 現在の設定値から編集を始める場合は`mail get`を使ってください（`sample`はゼロから書く場合、`get`は現在の値を編集する場合に使います）。
- `--json`には対応していません（出力は常にTOMLです。指定するとエラーで終了します）。JSONで内容を確認したい場合は`mail get --json`を使ってください。

### mail update — メールテンプレートの更新

入力には、**更新対象だけを記載したTOML**を`--mail-file`で渡します（`-`を指定すると`stdin`から読み込みます）。手元の`espf.toml`から必要なセクションだけを切り出して渡せます。`mail get`の出力（`etag`行を含む）もそのまま渡せます。

```sh
# 通知メールの件名を更新（mail.tomlの[notification.mail]セクションにsubject = "..."を書く）
esparformctl mail update <formID> --mail-file ./mail.toml

# フォームのフィールド名を渡し、テンプレート変数の不一致を警告（--known-fields）
esparformctl mail update <formID> --mail-file ./mail.toml --known-fields name,email,message --dry-run

# 適用せずに差分だけ確認する（--dry-run）
esparformctl mail update <formID> --mail-file ./mail.toml --dry-run

# stdinから渡す
cat <<'TOML' | esparformctl mail update <formID> --mail-file -
[notification]
enabled = true

[notification.mail]
subject = "お問い合わせありがとうございます"
to = "ops@example.com"
TOML
```

- 構造：`[notification]`/`[reply]`の`enabled`/`allow_attach`（`bool`）、`[notification.mail]`/`[reply.mail]`の`from`/`subject`/`body`/`to`/`cc`/`bcc`/`reply_to`（文字列）。
- **適用前に現在の値と比較し、実際に変わったフィールドだけを更新します**。キーを書いても現在の値と同じなら変更なし、空文字`""`は（現在の値が空でなければ）クリア、書かなければ変更なしです。クリアしたフィールドは、結果の`cleared_fields`に含まれます。`mail get`の出力をそのまま渡しても、編集した箇所だけが差分になります。変更がなければ「変更はありません」と表示して終了します。
- 宛先（`to`/`cc`/`bcc`/`reply_to`）は、メールヘッダーと同様の形式の**テキスト**です（カンマ区切りで複数指定できます）。
- `body`はTOMLの複数行文字列（`"""..."""`）で直接書けます。`@`で始まる文字列も**そのままの文字列**として送られます（ファイルとして展開しません）。
- **`--dry-run`**（短縮形`-n`）：差分の表示と警告まで通常どおり実行し、**適用せず**、確認プロンプトを表示せずに終了します（差分の有無によらず終了コードは0）。`--json --dry-run`は通常の更新結果と同じ形式で、`dry_run`が`true`のJSONを出力します。**`--yes`は不要**です。
- **取得後の変更の検出**：入力TOMLの先頭に`etag`行がある場合（`mail get`の出力を使用した場合）、取得時点から他のユーザーがフォームを変更していると警告します。`--json`では`warnings`に`stale_input`が含まれます。警告が表示されても適用は続行されます。
- **テンプレート変数の検証（`--known-fields`）**：フォームの実際のフィールド名（`name`属性）をカンマ区切りで渡すと、テンプレートの`{{ .xxx }}`変数のうち、フォームに存在しないものを警告します。`--json`では`warnings`に`unknown_template_var`が含まれます。警告が表示されても適用は続行されます。`{{ .espf_date }}`などの組み込み変数は警告対象外です。指定しない場合は検証しません。`--dry-run`と組み合わせると、実送信の前に「本文が空欄になる」不一致を検出できます。

### setting — フォーム設定の取得・変更

```sh
esparformctl setting get <formID> [--json]

esparformctl setting set <formID> \
  --allow-http=false \
  --allow-localhost=true \
  --token-expiration=90m \
  --send-rate-limit=60s
```

- `setting get`は、設定8項目（`allow_http`/`allow_localhost`/`allowed_referers`/`token_expiration`/`send_rate_limit`/`date_format`/`time_format`/`list_delimiter`）と`etag`を表示します。
- `setting set`は、**`allowed_referers`を除く7項目**を変更できます（`--allow-http`/`--allow-localhost`/`--token-expiration`/`--send-rate-limit`/`--date-format`/`--time-format`/`--list-delimiter`）。
- **指定したフラグのみ部分更新**します（未指定のフラグに対応する項目は変更しません）。文字列系フラグに空値（`--token-expiration=`など）を指定すると、**初期値に戻します**。
- **期間（`duration`）の書式**：`--token-expiration`/`--send-rate-limit`は、単位付きの**正の期間**で指定します（例：`30s`、`10m`、`1h30m`）。単位なし（`10`）、負値、`0s`は送信前にエラーになります。
- **許可する送信元ホストは表示できますが**、CLIからは変更できません。変更が必要な場合は担当者に依頼してください。
- 拒否リストに関する設定はCLIでは表示も変更もできません（管理画面を利用してください）。
- **`--dry-run`**：適用せずに差分だけを確認します（`mail update --dry-run`と同じ動作です。終了コードは0で、`--json --dry-run`でも`--yes`は不要です）。

## JSON出力（`--json`）

スクリプトなどから利用する場合は、以下の仕様を前提にできます。

- `--json`：`stdout`に1つのJSONオブジェクトを出力します。
- `--yes`：確認プロンプトをスキップします。**`--json`で書き込み操作（`mail update`/`setting set`/`form set`/`logout`）を行う場合は`--yes`が必須**です。指定しない場合はエラー終了します。例外として、`--dry-run`は書き込みではないため、`--json --dry-run`では`--yes`は不要です。
- 確認プロンプトや診断は`stderr`に、結果は`stdout`に出力します。
- エラーは、`error`オブジェクトに`code`、`message`、`request_id`を含むJSON形式で出力します。更新結果には`updated_fields`、`unchanged_fields`、`cleared_fields`、`etag`、`warnings`が含まれます。`--dry-run`の場合のみ、`dry_run`が`true`になります。
- **ログイン済みかどうかの判定には`auth status --json`を使ってください**。データ取得を伴わないため軽量で、終了コードとJSONのどちらでも判定できます。

### 終了コード

| エラーコード | 意味 | 終了コード |
|--------------|------|------------|
| （なし） | 成功 | `0` |
| `validation_error` | 入力検証失敗 | `1` |
| `auth_required` | 未ログイン | `2` |
| `auth_expired` | トークン失効 | `3` |
| `auth_invalid` | トークン不正 | `4` |
| `permission_denied` | 権限不足 | `5` |
| `conflict` | 競合（ETagの不一致または未指定） | `6` |
| `not_found` | リソース不在 | `7` |
| `network_error` | 通信失敗 | `8` |
| `non_interactive_required` | `--json`による書き込みで`--yes`が未指定 | `9` |
| `api_error` | その他サーバエラー | `10` |
| `usage_error` | 使用方法エラー | `64` |
| `internal_error` | 内部エラー | `70` |

## 設定ファイル

認証情報は設定ディレクトリ`<config-dir>/esparformctl/`配下に保存します（形式はTOMLです）。

| ファイル | 内容 |
|---------|------|
| `<config-dir>/esparformctl/credentials` | 認証情報（アクセストークンをプロファイルごとに分離） |

`<config-dir>`の保存先：

| OS | `<config-dir>` |
|----|----------------|
| Linux | `$XDG_CONFIG_HOME`（未設定なら`~/.config`） |
| macOS | `$XDG_CONFIG_HOME`（絶対パスで設定されている場合）。それ以外は`~/Library/Application Support` |
| Windows | `%AppData%`（`XDG_CONFIG_HOME`は参照しません） |

> **注：**macOSで`XDG_CONFIG_HOME`を設定して保存先を変えても、既存の`~/Library/Application Support/esparformctl/`からの**自動移行は行いません**。新しい場所で再度`login`を実行するか、ファイルを手動で移動してください。

認証情報（アクセストークン）は`stdout`、`stderr`、ログ、エラー、JSONに一切出力しません。
