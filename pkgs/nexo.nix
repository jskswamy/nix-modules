# nexo - Terminal workspace, project, container, and coding-agent switcher
# Not available in nixpkgs; upstream v0.1.0 predates the Rex backend adapter,
# so we build from the main commit that ships internal/backend/rex.
# https://github.com/vieitesss/nexo
_: prev: {
  nexo = prev.buildGoModule rec {
    pname = "nexo";
    version = "0.1.0-unstable-2026-10-26";

    src = prev.fetchFromGitHub {
      owner = "vieitesss";
      repo = "nexo";
      rev = "3f4d7d14b30f57d739808a060b5d9c2209b0efe2";
      hash = "sha256-1TLgNxUtycL19xz9VIn7Js5YFJxfo5FNAXRLdxap5Ws=";
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
      homepage = "https://github.com/vieitesss/nexo";
      license = licenses.mit;
      mainProgram = "nexo";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}
