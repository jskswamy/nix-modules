# nexo - Terminal workspace, project, container, and coding-agent switcher
# Not available in nixpkgs. Built from the jskswamy fork's
# feat/configurable-session-naming branch (upstream main + session naming).
# https://github.com/jskswamy/nexo (fork of vieitesss/nexo)
_: prev: {
  nexo = prev.buildGoModule rec {
    pname = "nexo";
    version = "0.1.0-unstable-2026-11-05";

    src = prev.fetchFromGitHub {
      owner = "jskswamy";
      repo = "nexo";
      rev = "7f4e3cbc62cb5545d06b7b1033c9c0ff292ce91e";
      hash = "sha256-+nP1gB6p2vSvzlOkXXkx2xInpx2Mvr0luXej6z6/OWM=";
    };

    vendorHash = "sha256-WqJ+vuNBgW5Eohhz1YfI7OfqyUdzcl7IEeDgwVHjmKo=";

    subPackages = ["cmd/nexo"];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/vieitesss/nexo/internal/cli.Version=${version}"
    ];

    # 1. Upstream go.mod declares `go 1.27.1`, while nixpkgs ships Go 1.26;
    #    the codebase uses no 1.27-only stdlib features.
    # 2. Unlike tmux/herdr, Rex has no focus hook invoking `nexo focus`, so
    #    record the departure session alongside the destination session on
    #    Rex container/project/agent switches and fall back to the other live
    #    local Rex session when history has not been seeded yet.
    postPatch = ''
      substituteInPlace go.mod \
        --replace-fail 'go 1.27.1' 'go 1.26'

      substituteInPlace internal/backend/rex/containers.go \
        --replace-fail \
          $'focused, err := b.selectSession(ctx, session.ID)\n\tif err != nil || !focused {\n\t\treturn err\n\t}\n\tentry, err := b.containerEntry(ctx, session)' \
          $'focused, err := b.selectSession(ctx, session.ID)\n\tif err != nil || !focused {\n\t\treturn err\n\t}\n\tif currentID, err := b.CurrentContainerID(ctx); err == nil && currentID != "" && currentID != session.ID {\n\t\tif currentSession, err := b.findSession(ctx, currentID); err == nil {\n\t\t\tif prevEntry, err := b.containerEntry(ctx, currentSession); err == nil {\n\t\t\t\t_ = b.recordContainer(ctx, prevEntry)\n\t\t\t}\n\t\t}\n\t}\n\tentry, err := b.containerEntry(ctx, session)'

      substituteInPlace internal/backend/rex/agents.go \
        --replace-fail \
          $'ledger, err := b.agentLedger(ctx)\n\tif err != nil {\n\t\treturn err\n\t}\n\treturn ledger.MarkSeen(current.ID)' \
          $'if currentID, err := b.CurrentContainerID(ctx); err == nil && currentID != "" && currentID != session.ID {\n\t\tif currentSession, err := b.findSession(ctx, currentID); err == nil {\n\t\t\tif prevEntry, err := b.containerEntry(ctx, currentSession); err == nil {\n\t\t\t\t_ = b.recordContainer(ctx, prevEntry)\n\t\t\t}\n\t\t}\n\t}\n\tif entry, err := b.containerEntry(ctx, session); err == nil {\n\t\t_ = b.recordContainer(ctx, entry)\n\t}\n\tledger, err := b.agentLedger(ctx)\n\tif err != nil {\n\t\treturn err\n\t}\n\treturn ledger.MarkSeen(current.ID)'

      substituteInPlace internal/commands/previous.go \
        --replace-fail \
          $'\t"github.com/vieitesss/nexo/internal/capabilities"\n)' \
          $'\t"github.com/vieitesss/nexo/internal/backend"\n\t"github.com/vieitesss/nexo/internal/capabilities"\n)' \
        --replace-fail \
          $'\t\treturn opener.OpenContainer(ctx, entry.ID)\n\t}\n\treturn nil' \
          $'\t\treturn opener.OpenContainer(ctx, entry.ID)\n\t}\n\tif invocation.Selection.Kind == backend.Rex && current != "" {\n\t\tif lister, ok := invocation.Adapter.(capabilities.ContainerLister); ok {\n\t\t\tif containers, err := lister.ListContainers(ctx); err == nil {\n\t\t\t\tfor _, c := range containers {\n\t\t\t\t\tif !c.Proxy && c.ID != "" && c.ID != current {\n\t\t\t\t\t\treturn opener.OpenContainer(ctx, c.ID)\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n\treturn nil'
    '';

    meta = with prev.lib; {
      description = "Fast terminal switcher for projects, containers, and coding agents";
      homepage = "https://github.com/jskswamy/nexo";
      license = licenses.mit;
      mainProgram = "nexo";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}
