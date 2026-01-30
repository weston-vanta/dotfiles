# Terminal image rendering utilities
# These are automatically loaded by oh-my-zsh on shell startup

# Render a graphviz dot file and display it in the terminal using viu
# Usage: dotviu [options] <file.dot>
#   -s, --scale <factor>    Scale relative to terminal width (default: 0.8)
#   -r, --rankdir <dir>     Graph direction: TB, BT, LR, RL (default: LR)
dotviu() {
  local scale=0.8
  local rankdir=LR
  local dotfile=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--scale)
        scale="$2"
        shift 2
        ;;
      -r|--rankdir)
        rankdir="$2"
        shift 2
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Usage: dotviu [-s|--scale <factor>] [-r|--rankdir <dir>] <file.dot>"
        return 1
        ;;
      *)
        dotfile="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$dotfile" ]]; then
    echo "Usage: dotviu [-s|--scale <factor>] [-r|--rankdir <dir>] <file.dot>"
    return 1
  fi

  if [[ ! -f "$dotfile" ]]; then
    echo "Error: File not found: $dotfile"
    return 1
  fi

  if ! command -v dot &> /dev/null; then
    echo "Error: graphviz not installed (dot command not found)"
    return 1
  fi

  if ! command -v viu &> /dev/null; then
    echo "Error: viu not installed"
    return 1
  fi

  local tmpfile=$(mktemp -t dotviu.XXXXXX.png)
  trap "rm -f '$tmpfile'" EXIT

  # Render with terminal-friendly styling
  dot -Tpng \
    -Gdpi=150 \
    -Gbgcolor=transparent \
    -Gmargin=0.75 \
    -Grankdir="$rankdir" \
    -Gfontcolor=white \
    -Gfontname=Helvetica \
    -Nfontcolor=white \
    -Nfontname=Helvetica \
    -Ncolor=white \
    -Efontcolor=white \
    -Efontname=Helvetica \
    -Ecolor=white \
    "$dotfile" -o "$tmpfile"

  # Scale relative to terminal width
  local term_cols=$(tput cols)
  local width=$(printf "%.0f" "$(echo "$term_cols * $scale" | bc)")
  [[ $width -lt 1 ]] && width=1

  viu -w "$width" "$tmpfile"
}
