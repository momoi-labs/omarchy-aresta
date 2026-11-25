#!/bin/bash

STATE=${XDG_RUNTIME_DIR:-/tmp}/cupertino-control-center
mkdir -p "$STATE"

wifi_on=false
[[ $(timeout 3 nmcli radio wifi 2>/dev/null) == enabled ]] && wifi_on=true
line=$(timeout 3 nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep -m1 '^yes:')
signal=$(cut -d: -f2 <<<"$line")
ssid=$(cut -d: -f3- <<<"$line" | sed 's/\\:/:/g')

bt_on=false
timeout 3 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && bt_on=true
bt_devices=$(timeout 3 bluetoothctl devices Connected 2>/dev/null | sed -n 's/^Device [^ ]* //p' | jq -R . | jq -sc .)

focus=$(timeout 2 omarchy-shell notifications isDnd 2>/dev/null)
[[ $focus == on ]] || focus=off

cache=$STATE/brightness
if [[ ! -s $cache || $(( $(date +%s) - $(stat -c %Y "$cache") )) -ge 15 ]]; then
  value=$(timeout 6 omarchy-brightness-display 2>/dev/null)
  [[ $value =~ ^[0-9]+$ ]] || value=-1
  echo "$value" >"$cache"
fi
read -r brightness <"$cache"

default_sink=$(timeout 3 pactl get-default-sink 2>/dev/null)
volume_sink=$(timeout 3 omarchy-audio-output-sink 2>/dev/null)
sinks=$(timeout 3 pactl -f json list sinks 2>/dev/null)
jq -e 'type == "array"' <<<"$sinks" >/dev/null 2>&1 || sinks='[]'

media='{}'
for name in $(timeout 3 busctl --user list --no-legend 2>/dev/null | awk '$1 ~ /^org\.mpris\.MediaPlayer2\./ { print $1 }'); do
  status=$(timeout 2 busctl --user get-property "$name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
  identity=$(timeout 2 busctl --user get-property "$name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2 Identity 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
  meta=$(timeout 2 busctl --user --json=short get-property "$name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Metadata 2>/dev/null)
  entry=$(jq -c --arg bus "$name" --arg status "$status" --arg player "$identity" '.data | { bus: $bus, player: $player, status: $status, title: (.["xesam:title"].data // ""), artist: ((.["xesam:artist"].data // []) | join(", ")), art: (.["mpris:artUrl"].data // "") }' <<<"$meta" 2>/dev/null)
  [[ -n $entry ]] || entry=$(jq -nc --arg bus "$name" --arg status "$status" --arg player "$identity" '{ bus: $bus, player: $player, status: $status, title: "", artist: "", art: "" }')
  [[ $media == '{}' || $status == Playing ]] && media=$entry
  [[ $status == Playing ]] && break
done

jq -nc \
  --argjson wifi_on "$wifi_on" --arg ssid "$ssid" --argjson signal "${signal:-0}" \
  --argjson bt_on "$bt_on" --argjson bt_devices "${bt_devices:-[]}" \
  --arg focus "$focus" \
  --argjson brightness "${brightness:--1}" \
  --arg default_sink "$default_sink" --arg volume_sink "$volume_sink" --argjson sinks "$sinks" \
  --argjson media "$media" \
  'def title: (.properties["node.nick"] // .description // .name);
   ($sinks | map(select(.name == $volume_sink)) | first) as $level
   | ($sinks | map(select(.name == $default_sink)) | first) as $current
   | { wifi: { on: $wifi_on, ssid: $ssid, signal: $signal },
       bt: { on: $bt_on, devices: $bt_devices },
       focus: { on: ($focus == "on") },
       display: { percent: $brightness },
       sound: { percent: (if $level then ([$level.volume[]?.value_percent] | first // "-1" | sub("%"; "") | tonumber) else -1 end),
                muted: ($level.mute // false),
                sink: (if $current then ($current | title) else "" end),
                outputs: ($sinks | map({ id: (.properties["object.id"] // "" | tostring), name: .name, label: title, current: (.name == $default_sink) })) },
       media: $media }'
