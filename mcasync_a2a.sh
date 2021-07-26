#!/usr/bin/env bash

ANDROID_WORLDS="/sdcard/games/com.mojang/minecraftWorlds"

log() {
  echo -e "\e[1m\e[93m * $*\e[39m\e[0m"
}

err() {
  echo -e "\e[1m\e[31m ! $*\e[39m\e[0m"
}

assert_deps() {
  for dep in adb sha1sum mktemp
  do
    if ! command -v "$dep" &>/dev/null
    then
      err "$dep not accessible"
      exit 1
    fi
  done
}

assert_android_worlds() {
  if adb -t "$1" shell "[[ -d $ANDROID_WORLDS ]]"
  then
    log "Found Android (id: $1) worlds folder: $ANDROID_WORLDS"
  else
    log "Could not find Android (id: $1) worlds folder; creating it"
    adb -t "$1" shell mkdir -p "$ANDROID_WORLDS"
  fi
}

_migrate() {
    adb -t "$2" shell rm -rf "${ANDROID_WORLDS:?}/*"
    log "Erased Android (id: $2) world files"
    adb -t "$1" pull "$ANDROID_WORLDS" "$tmp"
    log "Pulled Android (id: $1) world files"
    adb -t "$2" push "$tmp/minecraftWorlds" "$ANDROID_WORLDS/.."
    log "Pushed new world files to Android (id: $2)"
    rm -rf "$tmp"
}

migrate() {
  local android_1_id
  local android_2_id
  local android_1_epoch
  local android_2_epoch

  local tmp
  tmp="$(mktemp -d)"

  read -r -a transport_ids <<< "$(adb devices -l | grep device | awk -F "transport_id:" '{print $2}' | xargs)"
  android_1_id="${transport_ids[0]}"
  android_2_id="${transport_ids[1]}"

  assert_android_worlds "$android_1_id"
  assert_android_worlds "$android_2_id"

  android_1_epoch="$(adb -t "$android_1_id" shell date -r "$ANDROID_WORLDS" "+%s")"
  android_2_epoch="$(adb -t "$android_2_id" shell date -r "$ANDROID_WORLDS" "+%s")"

  if [[ "$android_1_epoch" -gt "$android_2_epoch" ]]
  then
    log "Android (id: $android_1_id) more recent worlds folder"
    _migrate "$android_1_id" "$android_2_id"
  elif [[ "$android_2_epoch" -gt "$android_1_epoch" ]]
  then
    log "Android (id: $android_2_id) more recent worlds folder"
    _migrate "$android_2_id" "$android_1_id"
  else
    log "Both versions up-to-date"
    exit 0
  fi
}

assert_deps
adb start-server &>/dev/null
migrate
