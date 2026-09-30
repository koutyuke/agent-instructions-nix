# Built-in targets: agents that read a single user-level instructions file.
# `dest` is relative to $HOME and fixed at build time, so runtime overrides such
# as CODEX_HOME or XDG_CONFIG_HOME are not followed; set `dest` instead.
# Sources are listed in README.md#targets--default-paths.
{
  agents.dest = ".agents/AGENTS.md";
  agentty.dest = ".agentty/AGENTS.md";
  amp.dest = ".config/amp/AGENTS.md";
  antigravity.dest = ".gemini/AGENTS.md";
  claude.dest = ".claude/CLAUDE.md";
  cline.dest = ".cline/rules/AGENTS.md";
  codex.dest = ".codex/AGENTS.md";
  command-code.dest = ".commandcode/AGENTS.md";
  copilot.dest = ".copilot/copilot-instructions.md";
  crush.dest = ".config/crush/CRUSH.md";
  droid.dest = ".factory/AGENTS.md";
  dsh.dest = ".dsh/AGENTS.md";
  eca.dest = ".config/eca/AGENTS.md";
  every-code.dest = ".code/AGENTS.md";
  forgecode.dest = ".forge/AGENTS.md";
  fx.dest = ".fx/AGENTS.md";
  gemini.dest = ".gemini/GEMINI.md";
  goose.dest = ".config/goose/.goosehints";
  hax.dest = ".config/hax/AGENTS.md";
  junie.dest = ".junie/AGENTS.md";
  kilocode.dest = ".config/kilo/AGENTS.md";
  kimi.dest = ".kimi-code/AGENTS.md";
  mimo.dest = ".config/mimocode/AGENTS.md";
  minimax.dest = ".minimax/AGENTS.md";
  mistral-vibe.dest = ".vibe/AGENTS.md";
  omp.dest = ".omp/agent/AGENTS.md";
  opencode.dest = ".config/opencode/AGENTS.md";
  pi.dest = ".pi/agent/AGENTS.md";
  prime-agent.dest = ".prime/agent/AGENTS.md";
  qoder.dest = ".qoder/AGENTS.md";
  qwen.dest = ".qwen/QWEN.md";
  reasonix.dest = ".reasonix/AGENTS.md";
  vix.dest = ".vix/AGENTS.md";
  zaly.dest = ".config/zaly/AGENTS.md";
  zcode.dest = ".zcode/AGENTS.md";
}
