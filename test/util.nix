{ pkgs }:
{
  # Each check evaluates its expectation at eval time and aborts with its name.
  mkCheck =
    name: ok:
    assert pkgs.lib.assertMsg ok "agent-instructions check failed: ${name}";
    pkgs.runCommand "agent-instructions-${name}" { } "touch $out";
}
