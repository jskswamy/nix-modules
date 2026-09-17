# Model Context Protocol servers, and the gateway that fronts them.
#
# A group rather than a tool: `mcp` is not one program. agentgateway routes
# Claude Code to the HTTP-native servers, local-mcp aggregates the
# stdio-only ones, and the rest are individual server daemons.
{
  imports = [
    ../tools/agentgateway
    ../tools/context7-mcp
    ../tools/serena-mcp
    ../tools/mcp-nixos
    ../tools/local-mcp
  ];
}
