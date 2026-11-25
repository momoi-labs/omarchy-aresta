#!/bin/bash

STATE=${XDG_RUNTIME_DIR:-/tmp}/cupertino-control-center
mpris() { busctl --user call "$1" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player "$2"; }

case "$1" in
  wifi) [[ $2 == on || $2 == off ]] && nmcli radio wifi "$2" ;;
  bluetooth) [[ $2 == on || $2 == off ]] && omarchy-bluetooth-power "$2" ;;
  focus) omarchy-shell notifications toggleDnd ;;
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
  output) [[ -n $2 && -n $3 ]] && omarchy-audio-output-set-default "$2" "$3" ;;
  previous) [[ $2 == org.mpris.MediaPlayer2.* ]] && mpris "$2" Previous ;;
  playpause) [[ $2 == org.mpris.MediaPlayer2.* ]] && mpris "$2" PlayPause ;;
  next) [[ $2 == org.mpris.MediaPlayer2.* ]] && mpris "$2" Next ;;
  picker) [[ $2 == omarchy.network || $2 == omarchy.bluetooth ]] && omarchy-shell shell toggle "$2" ;;
  *) exit 1 ;;
esac
