# Reset terminal mouse tracking mode before each prompt.
# Fixes garbled mouse escape sequences after an SSH session drops
# unexpectedly (e.g. laptop sleep), where the remote app never sent
# the disable-mouse-tracking sequence.
autoload -Uz add-zsh-hook

_reset_mouse_tracking() {
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
}

add-zsh-hook precmd _reset_mouse_tracking
