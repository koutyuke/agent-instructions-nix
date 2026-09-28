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

| 関数                                           | 説明                                                               |
| ---------------------------------------------- | ------------------------------------------------------------------ |
| `mkBundle { pkgs, fragments, targets, name? }` | バンドルを作る。設定に誤りがあれば throw する                      |
| `resolveTargets { fragments, targets }`        | 有効なターゲットを `{ <name> = { dest; fragments; }; }` に解決する |
| `checkTargets resolved`                        | 解決結果のエラーメッセージの一覧を返す。問題なければ空             |
| `compose fragments`                            | 断片をつなげた文字列を返す                                         |
| `defaultTargets`                               | 組み込みのターゲットと既定の `dest`                                |

結合済みの本文は、一つのバンドルの直下に `{agent}.md` として生成します。たとえば `/nix/store/<hash>-agent-instructions/` に `codex.md` と `claude.md` が並びます。Home Manager は、各 `dest` からバンドル内の対応するファイルへリンクします。`dest` を変更しても、バンドル内のファイル名は変わりません。

## 断片の書き方

断片は改行 1 つを挟んでつなげられます。見出しの階層はそのまま残るので、H1 は先頭の断片だけに置き、ほかの断片は `##` から書くと生成物の構造が崩れません。

断片のファイル名を `CLAUDE.md` や `AGENTS.md` にするのは避けてください。そのディレクトリで作業するエージェントが、プロジェクトの指示として読み込んでしまいます。macOS の既定のファイルシステムは大文字と小文字を区別しないので、`claude.md` でも同じことが起きます。

## オプション

Home Manager では `programs.agent-instructions` の下に、コアでは引数として同じ名前で渡します。`enable` は Home Manager だけのオプションです。

| オプション                     | 型           | 既定値       | 説明                                                         |
| ------------------------------ | ------------ | ------------ | ------------------------------------------------------------ |
| `enable`                       | bool         | `false`      | モジュールを有効にする                                       |
| `fragments`                    | list of path | `[ ]`        | 全ターゲットで共通の断片                                     |
| `targets.<name>.enable`        | bool         | `false`      | このターゲットに書き込む                                     |
| `targets.<name>.dest`          | string       | 組み込みの値 | `$HOME` からの相対パス。組み込みのターゲットでも上書きできる |
| `targets.<name>.fragments`     | list of path | `[ ]`        | 共通の断片のあとに追加する断片                               |
| `targets.<name>.inheritCommon` | bool         | `true`       | `false` にすると共通の断片を使わない                         |

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
