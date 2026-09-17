# Generic git configuration. Identity (user.name/user.email), the signing
# key path, work-config includes and any url.insteadOf routing are
# deliberately absent: they are per-person and per-employer, and belong in
# the consumer's own configuration layered on top of this.
{
  config,
  lib,
  hunkEnabled,
}: {
  enable = true;
  ignores = [
    "*.swp"
    ".DS_Store"
    "._*"
    ".Spotlight-V100"
    ".Trashes"
    "Thumbs.db"
    "Desktop.ini"
    "TAGS"
    "tags"
    ".tags"
    ".tags1"
    "gtags.files"
    "GTAGS"
    "GRTAGS"
    "GPATH"
    "cscope.files"
    "cscope.out"
    "cscope.in.out"
    "cscope.po.out"
    "*.un~"
    "Session.vim"
    ".netrwhist"
    "*~"
    ".sass-cache"
    ".envrc"
    ".tfvars"
    ".idea/"
    "lsp/"
    ".beads/"
  ];
  signing.format = "ssh";
  lfs.enable = true;
  settings = {
    alias = {
      a = "add";
      chunkyadd = "add --patch";
      b = "branch -v";
      c = "commit -m";
      ca = "commit -am";
      ci = "commit";
      amend = "commit --amend";
      co = "checkout";
      nb = "checkout -b";
      cp = "cherry-pick -x";
      d = "diff";
      dc = "diff --cached";
      last = "diff HEAD^";
      dft = "difftool";
      dftlog = "-c diff.external=difft log -p --ext-diff";
      l = "log --graph --date=short";
      changes = "log --pretty=format:\"%h %cr %cn %Cgreen%s%Creset\" --name-status";
      short = "log --pretty=format:\"%h %cr %cn %Cgreen%s%Creset\"";
      simple = "log --pretty=format:\" * %s\"";
      shortnocolor = "log --pretty=format:\"%h %cr %cn %s\"";
      pl = "pull";
      ps = "push";
      rc = "rebase --continue";
      rs = "rebase --skip";
      r = "remote -v";
      unstage = "reset HEAD";
      uncommit = "reset --soft HEAD^";
      filelog = "log -u";
      mt = "mergetool";
      ss = "stash";
      sl = "stash list";
      sa = "stash apply";
      sd = "stash drop";
      s = "status";
      st = "status";
      stat = "status";
      t = "tag -n";
      snapshot = "!git stash save \"snapshot: $(date)\" && git stash apply \"stash@{0}\"";
      snapshots = "!git stash list --grep snapshot";
      recent-branches = "!git for-each-ref --count=15 --sort=-committerdate refs/heads/ --format='%(refname:short)'";
    };
    color = {
      ui = true;
      branch = {
        current = "yellow reverse";
        local = "yellow";
        remote = "green";
      };
      diff = {
        meta = "yellow bold";
        frag = "magenta bold";
        old = "red";
        new = "green";
      };
    };
    format.pretty = "format:%C(blue)%ad%Creset %C(yellow)%h%C(green)%d%Creset %C(blue)%s %C(magenta) [%an]%Creset";
    init.defaultBranch = "main";
    core =
      {
        editor = "vim";
        autocrlf = "input";
      }
      # Dropping hunk leaves git on its own default pager rather than
      # pointing at a binary that is no longer configured.
      // lib.optionalAttrs hunkEnabled {pager = "hunk pager";};
    # hunk needs a real TTY to render (falls back to plain passthrough
    # otherwise, confirmed by testing), so the non-interactive filter
    # paths below stay on delta.
    interactive.diffFilter = "delta --color-only";
    delta = {
      syntax-theme = "ansi";
      side-by-side = false;
      line-numbers = true;
      navigate = true;
      hyperlinks = true;
      line-numbers-minus-style = "red";
      line-numbers-plus-style = "green";
      # plus-style/minus-style default to "syntax auto"/"normal auto",
      # which resolves to delta's own hardcoded RGB backgrounds instead
      # of following the terminal's ANSI theme (confirmed by testing —
      # showed up as a fixed dark red/green regardless of gruvbox
      # light/dark). Tried "syntax <ansi-color>" (theme-relative
      # background, syntax-highlighted foreground) but that composites
      # two independently-chosen colors — some syntax token colors
      # ended up low-contrast against the background, confirmed by
      # testing both as a full-line wash and as word-level emphasis.
      #
      # Settled on a fixed foreground+background PAIR instead (soft
      # pastel pink/green, approximated from Claude Code's own diff
      # rendering, which the user specifically liked) — guaranteed
      # contrast by construction since both colors are chosen together,
      # rather than composed from two unrelated sources. Trade-off:
      # fixed hex, so it won't adapt if the terminal theme changes to
      # something these pastels clash with.
      minus-style = ''"#9d0006" "#f2d5d5"'';
      plus-style = ''"#79740e" "#e3ecd0"'';
      minus-emph-style = ''"#9d0006" "#f2d5d5" bold'';
      plus-emph-style = ''"#79740e" "#e3ecd0" bold'';
    };
    commit.gpgsign = true;
    tag.gpgsign = true;
    # Written by the writeAllowedSigners activation entry. Signing needs
    # only the private key; verifying needs this file, and without it git
    # reports %G? = N for every commit it has no way to check.
    gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
    pull.rebase = true;
    push.default = "upstream";
    rebase.autoStash = true;
    branch.autosetupmerge = true;
    advice.statusHints = false;
    apply.whitespace = "nowarn";
    merge = {
      summary = true;
      verbosity = 1;
    };
    mergetool.prompt = false;
    diff = {
      algorithm = "patience";
      mnemonicprefix = true;
      tool = "difftastic";
      jupyternotebook.command = "git-nbdiffdriver diff --ignore-metadata --ignore-details";
    };
    difftool = {
      difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
      nbdime.cmd = "git-nbdifftool diff $LOCAL $REMOTE $BASE";
      prompt = false;
    };
    mergetool.nbdime.cmd = "git-nbmergetool merge $BASE $LOCAL $REMOTE $MERGED";
    merge.jupyternotebook = {
      driver = "git-nbmergedriver merge %O %A %B %L %P";
      name = "jupyter notebook merge driver";
    };
    rerere.enabled = true;
  };
}
