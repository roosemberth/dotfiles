{ config, pkgs, lib, ... }: with lib; {
  options.programs = {
    zsh-roos.enable = mkEnableOption "Roos' zsh config";
  };

  config = mkIf config.programs.zsh-roos.enable {
    programs.starship = {
      enable = true;
      settings = {
        format = builtins.concatStringsSep "" [
          "$username"
          "$hostname"
          "$shlvl"
          "$directory"
          "$git_branch"
          "$git_commit"
          "$git_state"
          "$git_status"
          "$nix_shell"
          "$memory_usage"
          "$sudo"
          "$cmd_duration"
          "$line_break"
          "$jobs"
          "$battery"
          "$status"
          "$character"
        ];
        directory.truncate_to_repo = false;
        battery.display = [{ threshold = 30; }];
        memory_usage.disabled = false;
        status.disabled = false;
        sudo.disabled = false;
        shlvl.disabled = false;
      };
    };
    programs.zsh = {
      enable = true;
      dotDir = ".local/etc/zsh";  # FIXME: Use `$XDG_DATA_DIR`.
      history = {
        size = 100000;  # History size in memory.
        save = 100000000;  # History events.
        path = ".local/var/lib/zsh/history";  # FIXME: Use `$XDG_DATA_DIR`.
        ignoreDups = true;
        ignoreSpace = true;
        extended = true;
        share = false;
      };

      sessionVariables = {
        PAGER = "less -j.3";
        VISUAL = "vim -O";
      };

      shellAliases = {
        ".."    = "cd ..";
        "..."   = "cd ../..";
        "...."  = "cd ../../..";
        "....." = "cd ../../../..";
        "cp"    = "cp -i";
        "df"    = "df -h";
        "l"     = "ls -vlF";
        "ll"    = "ls -valFh";
        "ls"    = "ls --color=auto";
        "mv"    = "mv -i";
        "rlf"   = "readlink -f";
        "rm"    = "rm --one-file-system";
        "wtf"   = "dmesg | tail -n 20";
        "aps"   = "ps aux | grep -v grep | grep --color=always";
      };

      initExtraFirst = ''
        # Only set GPG_TTY if this is a tty session. Otherwise, GPG may try to
        # take control of the session terminal. This is problematic when the tty
        # is already being used and gpg was not called directly (e.g. when
        # creating a git commit from inside vim).
        if [ "$XDG_SESSION_TYPE" = "tty" ]; then
            export GPG_TTY="$(tty)"
        else
            unset GPG_TTY
        fi
      '';

      initExtra = ''
        if command -v fzf-share &> /dev/null; then
          source "$(fzf-share)/completion.zsh"
          source "$(fzf-share)/key-bindings.zsh"
        fi

        # Filter commands going to the history
        zshaddhistory() {
            line="''${1%%$'\n'}"
            case "$line" in
                fg|bg) return 1 ;;
            esac
        }

        # Easy navigation of 'projects' folder.
        wrapToProject() {
            find ~/ws -maxdepth 5 -not -path '*/.*' -type d 2> /dev/null | fzf | read -r dest
            [ -z "$dest" ] && return
            pushd "$dest"
            ranger < /dev/tty
            zle reset-prompt
        }
        zle -N wrapToProject

        bindkey -M viins '' wrapToProject
        bindkey -M viins '' push-input       # Save current line for later
        bindkey -M viins '' down-line-or-history
        bindkey -M viins '' up-line-or-history
        bindkey -M viins '' backward-kill-line
        bindkey -M viins '' vi-backward-kill-word
        bindkey -M viins '^@' vi-forward-word  # C-<Space>

        # Make backspace and delete behave as I'm used to.
        bindkey -M viins ''    backward-delete-char # <Backspace>
        bindkey -M viins '[3~' delete-char          # <Delete>

        setopt PUSHD_SILENT
        setopt PUSHD_TO_HOME
        setopt AUTO_LIST
        setopt BAD_PATTERN
        setopt NO_EXTENDED_GLOB
        setopt MAGIC_EQUAL_SUBST
        setopt HIST_FIND_NO_DUPS
        setopt HIST_IGNORE_ALL_DUPS
        setopt INC_APPEND_HISTORY
        setopt BEEP
        setopt NOTIFY
        setopt PROMPT_SUBST  # Allow substitutions as part of prompt format string
        setopt SH_WORD_SPLIT  # Handle IFS as SH

        function ctmp(){
          TMPBASE="''${XDG_RUNTIME_DIR:-$HOME/tmp/$(id -u)/}"
          mkdir -p "$TMPBASE"
          TMPDIR="$(mktemp -dp $TMPBASE)"
          command -v lsof &>/dev/null && (
              while [ -d "$TMPDIR" ]; do
                  sleep 5
                  if [ -z "\$(lsof +d '$TMPDIR' 2>/dev/null)" ] \
                      && [ -z "\$(lsof +D '$TMPDIR' 2>/dev/null)" ]; then
                      rm -fr "$TMPDIR"
                  fi
              done
          )&!
          [ -d "$TMPBASE/latest-ctmp" ] && rm "$TMPBASE/latest-ctmp"
          ln -sf "$TMPDIR" "$TMPBASE/latest-ctmp"
          pushd "$TMPDIR"
        }

        function cltmp(){
          TMPBASE="''${XDG_RUNTIME_DIR:-$HOME/tmp/$(id -u)/}"
          pushd "$TMPBASE/latest-ctmp"
        }

      '';

      enableAutosuggestions = true;
      enableCompletion = true;
      enableSyntaxHighlighting = true;
    };
  };
}
