#!/bin/bash

STATE=${XDG_RUNTIME_DIR:-/tmp}/aresta-control-center
SETTINGS_FILE=${HOME}/.config/aresta/settings.toml
mpris() { busctl --user call "$1" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player "$2"; }

setting_text() {
  local val=""
  if [[ -f $SETTINGS_FILE ]]; then
    val=$(sed -nE "s/^[[:space:]]*${1}[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*$/\1/p" "$SETTINGS_FILE" | tail -n1)
  fi
  printf '%s' "${val:-$2}"
}

case "$1" in
  wifi) [[ $2 == on || $2 == off ]] && nmcli radio wifi "$2" ;;
  bluetooth) [[ $2 == on || $2 == off ]] && omarchy-bluetooth-power "$2" ;;
  focus) omarchy-shell notifications toggleDnd ;;
  nightlight) omarchy-toggle-nightlight ;;
  theme)
    light_theme=$(setting_text light_theme aresta-light)
    dark_theme=$(setting_text dark_theme aresta-dark)
    if [[ $2 == light ]]; then
      target=$light_theme
    elif [[ $2 == dark ]]; then
      target=$dark_theme
    elif [[ -z $2 ]]; then
      mode=""
      current=""
      [[ -f $HOME/.local/state/omarchy/current/theme/colors.toml ]] && mode=$(sed -nE 's/^[[:space:]]*mode[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$/\1/p' "$HOME/.local/state/omarchy/current/theme/colors.toml" | head -n1)
      [[ -f $HOME/.local/state/omarchy/current/theme.name ]] && current=$(tr -d '\n' <"$HOME/.local/state/omarchy/current/theme.name")
      if [[ $mode == light || $current == "$light_theme" ]]; then
        target=$dark_theme
      else
        target=$light_theme
      fi
    else
      exit 1
    fi
    omarchy-theme-set "$target"
    ;;
  brightness)
    [[ $2 =~ ^[0-9]+$ ]] || exit 1
    omarchy-brightness-display --no-osd "$2%"
    rm -f "$STATE"/brightness-*
    ;;
  volume)
    [[ $2 =~ ^[0-9]+$ ]] || exit 1
    sink=$(omarchy-audio-output-sink)
    [[ -n $sink ]] || exit 1
    pactl set-sink-mute "$sink" 0
    pactl set-sink-volume "$sink" "$2%"
    ;;
  previous) [[ $2 == org.mpris.MediaPlayer2.* ]] && mpris "$2" Previous ;;
  playpause) [[ $2 == org.mpris.MediaPlayer2.* ]] && mpris "$2" PlayPause ;;
  next) [[ $2 == org.mpris.MediaPlayer2.* ]] && mpris "$2" Next ;;
  picker)
    case "$2" in
      omarchy.network|omarchy.bluetooth|omarchy.monitor|omarchy.audio)
        omarchy-shell shell toggle "$2"
        ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
