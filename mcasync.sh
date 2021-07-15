#!/usr/bin/env bash

LINUX_WORLDS="$HOME/.local/share/mcpelauncher/games/com.mojang/minecraftWorlds"
LINUX_FLATPAK_WORLDS="$HOME/.var/app/io.mrarm.mcpelauncher/data/mcpelauncher/games/com.mojang/minecraftWorlds"
MAC_WORLDS="$HOME/Library/Application Support/mcpelauncher/games/com.mojang/minecraftWorlds"
WIN_WORLDS="$USERPROFILE/AppData/Local/Packages/Microsoft.MinecraftUWP_8wekyb3d8bbwe/LocalState/games/com.mojang/minecraftWorlds"
ANDROID_WORLDS="/sdcard/games/com.mojang/minecraftWorlds"

POSSIBLE_PC_WORLDS=(
  "$LINUX_WORLDS"
  "$LINUX_FLATPAK_WORLDS"
  "$MAC_WORLDS"
  "$WIN_WORLDS"
)

log() {
  echo -e "\e[1m\e[93m * $*\e[39m\e[0m"
}

err() {
  echo -e "\e[1m\e[31m ! $*\e[39m\e[0m"
}

assert_deps() {
  for dep in adb sha1sum
  do
    if ! command -v "$dep" &>/dev/null
    then
      err "$dep not accessible"
      exit 1
    fi
  done
}

find_pc_worlds() {
  for world in "${POSSIBLE_PC_WORLDS[@]}"
  do
    if [[ -d "$world" ]]
    then
      PC_WORLD="$world"
      log "Found PC worlds folder: $PC_WORLD"
      return
    fi
  done

  err "Could not find PC worlds folder"
  exit 1
}

migrate() {
  local pc_epoch
  local android_epoch

  pc_epoch="$(date -r "$PC_WORLD" "+%s")"

  adb start-server &>/dev/null
  android_epoch="$(adb shell date -r "$ANDROID_WORLDS" "+%s")"

  if [[ "$pc_epoch" -gt "$android_epoch" ]]
  then
    log "PC has more recent worlds folder"
    adb shell rm -rf "${ANDROID_WORLDS:?}/*"
    log "Erased old Android world files"
    adb push "$PC_WORLD" "$ANDROID_WORLDS/.."
    log "Pushed new PC world files"
  elif [[ "$android_epoch" -gt "$pc_epoch" ]]
  then
    log "Android has more recent worlds folder"
    rm -rf "${PC_WORLD:?}/*"
    log "Erased old PC world files"
    adb pull "$ANDROID_WORLDS" "$PC_WORLD/.."
    log "Pushed new Android world files"
  else
    log "Both versions up-to-date"
    exit 0
  fi
}

assert_deps
find_pc_worlds
migrate
