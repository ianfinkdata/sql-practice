# Shared helper for opening a Ptyxis window at a fixed cell size and screen
# position — SOURCED, not executed. Used by terminal launcher scripts.
#
# Why the contortions: this is a Wayland session, and Wayland gives apps no
# way to position their own windows (Ptyxis has no geometry flag at all —
# only --maximize/--fullscreen). So the window is forced onto XWayland
# (GDK_BACKEND=x11 + a standalone instance, since a non-standalone launch
# just activates the existing Wayland-native instance) where mutter still
# honors _NET_MOVERESIZE_WINDOW, and then placed with wmctrl. Verified live
# on cavebox 2026-07-22: requested coordinates land exactly (checked via
# xwininfo; note wmctrl -lG misreports positions at 2x — don't trust it).
#
# Size in terminal cells comes from Ptyxis's default-columns/default-rows
# gsettings, flipped just for the launch and restored right after the window
# maps. This only works while restore-window-size is false — if it's true,
# new windows replay the LAST window's on-screen size instead of reading
# these keys, silently ignoring cols/rows entirely.
#
# Degrades gracefully: if wmctrl/xwininfo are missing or the X side is
# unreachable, it falls back to a plain Wayland --new-window launch.

# ptyxis_place_window COLS ROWS ANCHOR WORKDIR CMD [ARGS...]
#   ANCHOR: "top-left", "top-right", "bottom-left", or "bottom-right" (of the primary monitor).
# Returns once the window is placed (or the fallback launch is fired); the
# Ptyxis process itself is disowned and outlives the caller.
ptyxis_place_window() {
  local cols=$1 rows=$2 anchor=$3 workdir=$4
  shift 4

  _ptyxis_place_fallback() {
    if command -v ptyxis >/dev/null 2>&1; then
      ptyxis --new-window --working-directory="$workdir" -- "$@" &
      disown
    elif [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
      "$TERMINAL" --working-directory="$workdir" -e "$@" &
      disown
    elif command -v gnome-terminal >/dev/null 2>&1; then
      gnome-terminal --working-directory="$workdir" -- "$@" &
      disown
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
      x-terminal-emulator -e "$@" &
      disown
    else
      echo "No graphical terminal emulator found. Running in place:"
      "$@"
    fi
  }

  if ! command -v wmctrl >/dev/null 2>&1 || ! command -v xwininfo >/dev/null 2>&1 || ! command -v ptyxis >/dev/null 2>&1; then
    _ptyxis_place_fallback "$@"
    return 0
  fi

  export DISPLAY="${DISPLAY:-:0}"
  # Autostart/hook contexts may lack XAUTHORITY; mutter's XWayland cookie
  # lives at a known (randomly suffixed) path. On fresh login / on-demand
  # XWayland startup, poll briefly for XWayland to initialize and accept connections.
  local ready=0 _w
  for _w in $(seq 1 25); do
    if wmctrl -l >/dev/null 2>&1; then
      ready=1
      break
    fi
    local auth
    auth=$(ls -t /run/user/"$(id -u)"/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
    [ -n "$auth" ] && export XAUTHORITY="$auth"
    if wmctrl -l >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 0.2
  done

  if [ "$ready" -ne 1 ]; then
    _ptyxis_place_fallback "$@"
    return 0
  fi

  # Primary monitor geometry; falls back to a 1920x1080 monitor at the
  # origin if xrandr is missing or reports no primary.
  local geom px=0 py=0 pw=1920 ph=1080
  geom=$(xrandr --query 2>/dev/null | awk '/ connected primary /{print $4; exit}')
  if [[ "$geom" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
    pw=${BASH_REMATCH[1]}; ph=${BASH_REMATCH[2]}
    px=${BASH_REMATCH[3]}; py=${BASH_REMATCH[4]}
  fi

  # Check-then-set, not blind: restore-window-size is a global toggle, so
  # only touch it when it's actually drifted from what the size flip below
  # depends on.
  if [ "$(gsettings get org.gnome.Ptyxis restore-window-size 2>/dev/null || echo '')" != "false" ]; then
    gsettings set org.gnome.Ptyxis restore-window-size false 2>/dev/null || true
  fi

  local old_cols old_rows
  old_cols=$(gsettings get org.gnome.Ptyxis default-columns 2>/dev/null || echo 80)
  old_rows=$(gsettings get org.gnome.Ptyxis default-rows 2>/dev/null || echo 24)
  gsettings set org.gnome.Ptyxis default-columns "$cols" 2>/dev/null || true
  gsettings set org.gnome.Ptyxis default-rows "$rows" 2>/dev/null || true

  GDK_BACKEND=x11 ptyxis -s -d "$workdir" -- "$@" &
  local pid=$!
  disown

  # Wait for the window to map, matched by the standalone instance's pid
  # (capped at 10s so a wedged launch can't hang the caller).
  local wid="" _i
  for _i in $(seq 1 50); do
    wid=$(wmctrl -lp | awk -v p="$pid" '$3 == p {print $1; exit}')
    [ -n "$wid" ] && break
    sleep 0.2
  done

  # Restore the shared size keys whether or not the window appeared.
  gsettings set org.gnome.Ptyxis default-columns "$old_cols" 2>/dev/null || true
  gsettings set org.gnome.Ptyxis default-rows "$old_rows" 2>/dev/null || true

  [ -z "$wid" ] && return 0

  # X-window pixel size (includes the 25px shadow on each edge).
  local w h
  read -r w h < <(xwininfo -id "$wid" 2>/dev/null \
    | awk '/Width:/{w=$2} /Height:/{h=$2} END{print w, h}')
  [ -z "${w:-}" ] || [ -z "${h:-}" ] && return 0

  local shadow=25 margin=10 x y
  case "$anchor" in
    top-left)
      # Request the monitor corner; mutter clamps into the work area.
      x=$px; y=$py
      ;;
    top-right)
      x=$((px + pw - w + shadow - margin))
      y=$py
      ;;
    bottom-left)
      x=$px
      y=$((py + ph - h + shadow - margin))
      ;;
    bottom-right)
      x=$((px + pw - w + shadow - margin))
      y=$((py + ph - h + shadow - margin))
      ;;
    *)
      return 0
      ;;
  esac
  wmctrl -i -r "$wid" -e "0,$x,$y,-1,-1"
}
