# Built-in targets: agents that read a single user-level instructions file.
# `dest` is relative to $HOME and fixed at build time, so runtime overrides such
# as CODEX_HOME or XDG_CONFIG_HOME are not followed; set `dest` instead.
# Sources are listed in README.md#built-in-targets.
{
  amp.dest = ".config/amp/AGENTS.md";
  claude.dest = ".claude/CLAUDE.md";
  codex.dest = ".codex/AGENTS.md";
  copilot.dest = ".copilot/copilot-instructions.md";
  crush.dest = ".config/crush/CRUSH.md";
  gemini.dest = ".gemini/GEMINI.md";
  goose.dest = ".config/goose/.goosehints";
  kiro.dest = ".kiro/steering/AGENTS.md";
  opencode.dest = ".config/opencode/AGENTS.md";
  pi.dest = ".pi/agent/AGENTS.md";
  windsurf.dest = ".codeium/windsurf/memories/global_rules.md";
}
