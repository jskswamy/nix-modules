# claide: an aide-wrapped agent entrypoint. `claide --resume` runs
# `aide -- --resume`, so aide resolves the context (env, secret, sandbox,
# mcp_servers) and launches the agent. Named via the agent + `-aide`
# convention so future shims (e.g. `graide` for gravity) stay recognizable.
# Not named `claude` to avoid aide re-exec'ing this shim in a loop.
_: prev: {
  claide = prev.writeShellScriptBin "claide" ''
    exec aide -- "$@"
  '';
}
