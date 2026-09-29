# agent-instructions-nix

複数の Markdown 断片をつなげて、AI コーディングエージェントのグローバル指示ファイルを生成します。対象は `~/.claude/CLAUDE.md` や `~/.codex/AGENTS.md` などです。

共通の指示は一か所に書き、エージェントごとの差分だけを足せます。

## 構成

| 層                    | 場所                                                       | 依存         | 役割                                                                                           |
| --------------------- | ---------------------------------------------------------- | ------------ | ---------------------------------------------------------------------------------------------- |
| コア                  | `lib/`（flake の `lib` 出力）                              | nixpkgs だけ | ターゲットの解決、検証、断片の結合、ターゲットごとの本文をまとめたパッケージ（バンドル）の生成 |
| Home Manager の対応層 | `modules/home-manager.nix`（`homeManagerModules.default`） | Home Manager | オプションをコアに渡し、バンドルのファイルを `home.file` でリンクする                          |

flake の input は nixpkgs だけです。Home Manager の対応層は、利用者の Home Manager に読み込まれて動くので、この flake は Home Manager に依存しません。

## Home Manager で使う

```nix
# flake.nix
inputs.agent-instructions = {
  url = "github:koutyuke/agent-instructions-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# Home Manager の設定
{ inputs, ... }:
{
  imports = [ inputs.agent-instructions.homeManagerModules.default ];

  programs.agent-instructions = {
    enable = true;
    # 全ターゲットに、この順番でつなげて書き込む
    fragments = [
      ./instructions/COMMON.md
      ./instructions/CONTEXT7.md
    ];
    targets = {
      claude.enable = true;
      # 共通の断片のあとに追加する
      codex = {
        enable = true;
        fragments = [ ./instructions/CODEX.md ];
      };
      # 組み込みにないツールは、dest を指定すれば追加できる
      my-agent = {
        enable = true;
        dest = ".my-agent/RULES.md";
        inheritCommon = false; # 共通の断片を使わない
        fragments = [ ./instructions/MY_AGENT.md ];
      };
    };
  };
}
```

## コアを直接使う

Home Manager を使わない場合は、コアでバンドルを作り、好きな方法で `$HOME` へ配置します。引数は Home Manager のオプションと同じ形です。

```nix
bundle = inputs.agent-instructions.lib.mkBundle {
  inherit pkgs;
  fragments = [ ./instructions/COMMON.md ];
  targets.claude.enable = true;
};
# => $out/claude.md
```

| 関数                                                      | 説明                                                                                                               |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `mkBundle { pkgs, fragments, insertH1?, targets, name? }` | バンドルを作る。`checkTargets` のエラーがあれば throw し、`targetWarnings` の警告は評価時の warning として表示する |
| `resolveTargets { fragments, insertH1?, targets }`        | 有効なターゲットを `{ <name> = { dest; fragments; h1; }; }` に解決する。`h1` は挿入する見出しの文字列か `null`     |
| `checkTargets resolved`                                   | 解決結果のエラーメッセージの一覧を返す。問題なければ空                                                             |
| `targetWarnings resolved`                                 | 解決結果の警告メッセージの一覧を返す。問題なければ空                                                               |
| `compose { fragments, h1? }`                              | 断片を整えてつなげた文字列を返す。解決済みのターゲットをそのまま渡せる                                             |
| `defaultTargets`                                          | 組み込みのターゲットと既定の `dest`                                                                                |

結合済みの本文は、一つのバンドルの直下に `{agent}.md` として生成します。たとえば `/nix/store/<hash>-agent-instructions/` に `codex.md` と `claude.md` が並びます。Home Manager は、各 `dest` からバンドル内の対応するファイルへリンクします。`dest` を変更しても、バンドル内のファイル名は変わりません。

### ローカルで試す

[examples/core.nix](./examples/core.nix) は、共通の断片から front matter と元の H1 を取り除き、配置先のファイル名を H1 にします。Codex には専用の断片も追加します。

サンプル自身が `builtins.getFlake` でルートの flake を読み込みます。`flake.nix` にサンプル用の出力を追加する必要はありません。リポジトリのルートで実行してください。

```bash
nix build --impure --file examples/core.nix
cat result/claude.md
cat result/codex.md
```

`--impure` は、ローカルの flake の読み込みと `builtins.currentSystem` の利用に必要です。`result` は生成したバンドルへのリンクです。Claude の先頭は `# CLAUDE.md`、Codex の先頭は `# AGENTS.md` になり、Codex だけに追加ルールが入ります。ホームディレクトリの指示ファイルへの配置は行いません。

## 断片の書き方

断片は次の順に整えてから、空行 1 つを挟んでつなげます。生成物は改行 1 つで終わります。

1. CRLF を LF にし、先頭の BOM を取り除く
2. 1 行目の `---` から次の `---` までの front matter を取り除く。生成物の途中に残すと見出しとして解釈されるため、常に取り除きます
3. `headingStrategy` に従って見出しを扱う
4. 前後の空行を取り除き、連続する空行を 1 行にまとめる。コードフェンスの中は変えません

見出しの扱いは、断片を `{ path; headingStrategy; }` の形で指定して選びます。path だけなら `"none"` です。ほかの値を指定するとエラーになります。

| `headingStrategy` | 動作                                                     | 使う場面                                            |
| ----------------- | -------------------------------------------------------- | --------------------------------------------------- |
| `"none"`          | 見出しをそのまま残す                                     | `##` から書いた断片                                 |
| `"demote"`        | すべての見出しを 1 段下げる。H1 がない断片でも下げる     | `# Context7` のようなトピック名の H1 を節として残す |
| `"drop"`          | 冒頭の H1 の行だけを消す。冒頭が H1 でなければ何もしない | `# 共通の指示` のような文書名の H1 を捨てる         |

見出しとして扱うのは、コードフェンスの外にある ATX 形式（`#` から始まる行）だけです。setext 形式（次の行に `===` や `---` を置く形）は扱いません。相対リンクや画像のパス、脚注や参照リンクの定義も書き換えないので、断片どうしで衝突しないように書いてください。同じ名前の節も統合せず、順番どおりに並べます。

生成物の先頭に H1 を入れるには `insertH1.enable = true` にします。`insertH1.text` を省くと、`dest` のファイル名（`CLAUDE.md`、`.goosehints` など）を見出しにします。`targets.<name>.insertH1` を設定すると、そのターゲットでは共通の `insertH1` の代わりに使います。無効のままなら、先頭の断片の H1 がそのまま文書の見出しになります。

```nix
programs.agent-instructions = {
  insertH1.enable = true; # 各ファイルの先頭が "# CLAUDE.md" や "# AGENTS.md" になる
  fragments = [
    { path = ./instructions/COMMON.md; headingStrategy = "drop"; }   # "# 共通の指示" を捨てる
    { path = ./rules/context7.md; headingStrategy = "demote"; }      # "# Context7" が "## Context7" になる
    ./instructions/NIX.md                                            # "##" から書いた断片
  ];
  targets.codex = {
    enable = true;
    insertH1 = { enable = true; text = "Codex の指示"; };
  };
};
```

断片の内容に次の問題があっても生成は続け、警告を表示します。Home Manager と `mkBundle` のどちらでも、評価時の warning として表示します。複数のターゲットが同じ断片を使っていても、断片の警告は 1 回だけ表示します。

| 条件                                            | 生成物                                                  |
| ----------------------------------------------- | ------------------------------------------------------- |
| H1 が 2 つ以上ある（`insertH1` を含む）         | そのまま出力する                                        |
| `drop` で消した H1 と次の見出しの間に本文がある | 本文は残り、直前の断片の最後の節の続きになる            |
| 閉じていないコードフェンスがある                | 断片の末尾を、開始と同じ記号と長さのフェンスで閉じる    |
| `demote` で H6 より深くなる見出しがある         | `#######` として出力する。Markdown では見出しにならない |

断片のファイル名を `CLAUDE.md` や `AGENTS.md` にするのは避けてください。そのディレクトリで作業するエージェントが、プロジェクトの指示として読み込んでしまいます。macOS の既定のファイルシステムは大文字と小文字を区別しないので、`claude.md` でも同じことが起きます。

## オプション

Home Manager では `programs.agent-instructions` の下に、コアでは引数として同じ名前で渡します。`enable` は Home Manager だけのオプションです。

| オプション                     | 型                      | 既定値       | 説明                                                            |
| ------------------------------ | ----------------------- | ------------ | --------------------------------------------------------------- |
| `enable`                       | bool                    | `false`      | モジュールを有効にする                                          |
| `fragments`                    | list of (path or attrs) | `[ ]`        | 全ターゲットで共通の断片。attrs は `{ path; headingStrategy; }` |
| `insertH1.enable`              | bool                    | `false`      | 生成物の先頭に H1 を入れる                                      |
| `insertH1.text`                | null or string          | `null`       | 見出しの文字列。`null` なら `dest` のファイル名                 |
| `targets.<name>.enable`        | bool                    | `false`      | このターゲットに書き込む                                        |
| `targets.<name>.dest`          | string                  | 組み込みの値 | `$HOME` からの相対パス。組み込みのターゲットでも上書きできる    |
| `targets.<name>.fragments`     | list of (path or attrs) | `[ ]`        | 共通の断片のあとに追加する断片                                  |
| `targets.<name>.inheritCommon` | bool                    | `true`       | `false` にすると共通の断片を使わない                            |
| `targets.<name>.insertH1`      | null or attrs           | `null`       | このターゲットで共通の `insertH1` の代わりに使う設定            |

次の場合はエラーになります。Home Manager では assertion として、`mkBundle` では throw として報告します。

- 組み込みにないターゲットに `dest` がない
- 有効なターゲットに書き込む断片が 1 つもない
- 複数のターゲットが同じ `dest` を指している
- （Home Manager のみ）同じファイルを書く `programs.<tool>.context` が同時に設定されている

## 組み込みのターゲット

公式ドキュメントで、ユーザー単位のグローバル指示ファイルを確認できたツールだけを載せています（2026-09-28 時点）。

| 名前       | `dest`                                       | 競合する Home Manager のオプション    | 出典                                                                                                 |
| ---------- | -------------------------------------------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `amp`      | `.config/amp/AGENTS.md`                      | -                                     | [Amp](https://ampcode.com/docs/customize/agents-md)                                                  |
| `claude`   | `.claude/CLAUDE.md`                          | `programs.claude-code.context`        | [Claude Code](https://code.claude.com/docs/en/memory)                                                |
| `codex`    | `.codex/AGENTS.md`                           | `programs.codex.context`              | [Codex](https://developers.openai.com/codex/guides/agents-md)                                        |
| `copilot`  | `.copilot/copilot-instructions.md`           | `programs.github-copilot-cli.context` | [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/add-custom-instructions) |
| `crush`    | `.config/crush/CRUSH.md`                     | -                                     | [Crush](https://github.com/charmbracelet/crush/blob/main/README.md)                                  |
| `gemini`   | `.gemini/GEMINI.md`                          | -                                     | [Gemini CLI](https://geminicli.com/docs/cli/gemini-md/)                                              |
| `goose`    | `.config/goose/.goosehints`                  | -                                     | [goose](https://goose-docs.ai/docs/guides/context-engineering/using-goosehints/)                     |
| `kiro`     | `.kiro/steering/AGENTS.md`                   | -                                     | [Kiro](https://kiro.dev/docs/steering/)                                                              |
| `opencode` | `.config/opencode/AGENTS.md`                 | `programs.opencode.context`           | [opencode](https://opencode.ai/docs/rules/)                                                          |
| `pi`       | `.pi/agent/AGENTS.md`                        | `programs.pi-coding-agent.context`    | [pi](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)     |
| `windsurf` | `.codeium/windsurf/memories/global_rules.md` | -                                     | [Windsurf](https://docs.devin.ai/desktop/cascade/memories)                                           |

`dest` はビルド時に決まります。`CLAUDE_CONFIG_DIR`、`CODEX_HOME`、`XDG_CONFIG_HOME` などで設定ディレクトリを移している場合、その値は反映されないので、`dest` を明示してください。

Windsurf のグローバルルールには 6,000 文字の上限があります。

次のツールは、グローバル指示を単一のファイルで持てない、または設定画面でしか持てないため、組み込みにしていません。

- Cursor: ユーザールールは設定画面だけで管理します
- Aider: 自動で読み込むファイルがなく、`read:` の設定で指定します
- Cline、Roo Code: ルールをディレクトリで管理します。必要なら、`dest` に任意のファイル名を指定して追加してください

## 開発

```bash
nix flake check        # コアのテスト（test/core.nix）。nixpkgs だけで動く
nix flake check ./dev  # Home Manager 対応層のテスト（test/home-manager.nix）
nix fmt                # nixfmt で整形
```

## ライセンス

[MIT](./LICENSE)
