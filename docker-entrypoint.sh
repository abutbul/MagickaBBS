#!/bin/sh
set -e

# Ensure data directory exists and owned (even if running root)
mkdir -p /data || true
if id magicka >/dev/null 2>&1; then
  chown -R magicka:magicka /data 2>/dev/null || true
fi

DATA_DIR="${DATA_DIR:-/data}"
CONFIG_DIR="$DATA_DIR/config"
LOG_DIR="$DATA_DIR/logs"
WWW_DIR="$DATA_DIR/www"
ANSIS_DIR="$DATA_DIR/ansis"
MENUS_DIR="$DATA_DIR/menus"
SCRIPTS_DIR="$DATA_DIR/scripts"

seed_file_structure() {
  mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$WWW_DIR" "$ANSIS_DIR" "$MENUS_DIR" "$SCRIPTS_DIR"

  # Seed base config if missing
  if [ ! -f "$CONFIG_DIR/bbs.ini" ]; then
    echo "Seeding default configuration..." >&2
    cp -r /opt/magicka/config_default/* "$CONFIG_DIR/" 2>/dev/null || true
    # Adjust absolute paths from original developer environment to container paths
    sed -i "s|/home/andrew/MagickaBBS|$DATA_DIR|g" "$CONFIG_DIR/bbs.ini" || true
  fi

  # Seed ANSI files if empty
  if [ "$(ls -A $ANSIS_DIR 2>/dev/null | wc -l)" = "0" ]; then
    cp -r /opt/magicka/ansis_default/* "$ANSIS_DIR/" 2>/dev/null || true
  fi

  # Seed WWW templates
  if [ "$(ls -A $WWW_DIR 2>/dev/null | wc -l)" = "0" ]; then
    cp -r /opt/magicka/www_default/* "$WWW_DIR/" 2>/dev/null || true
  fi
}

tune_config() {
  ini="$CONFIG_DIR/bbs.ini"
  [ -f "$ini" ] || return 0

  # Ensure base paths reference DATA_DIR
  sed -i "s|^Config Path = .*|Config Path = $CONFIG_DIR|" "$ini" || true
  sed -i "s|^WWW Path = .*|WWW Path = $WWW_DIR|" "$ini" || true
  sed -i "s|^String File = .*|String File = /opt/magicka/magicka.strings|" "$ini" || true
  sed -i "s|^PID File = .*|PID File = $DATA_DIR/magicka.pid|" "$ini" || true
  sed -i "s|^ANSI Path = .*|ANSI Path = $ANSIS_DIR|" "$ini" || true
  sed -i "s|^BBS Path = .*|BBS Path = $DATA_DIR|" "$ini" || true
  sed -i "s|^Log Path = .*|Log Path = $LOG_DIR|" "$ini" || true
  sed -i "s|^Script Path = .*|Script Path = $SCRIPTS_DIR|" "$ini" || true
  sed -i "s|^Menu Path = .*|Menu Path = $MENUS_DIR|" "$ini" || true

  if [ "${ENABLE_WWW}" = "true" ]; then
    sed -i 's/^Enable WWW = .*/Enable WWW = true/' "$ini" || true
  else
    sed -i 's/^Enable WWW = .*/Enable WWW = false/' "$ini" || true
  fi

  if [ "${ENABLE_SSH}" = "true" ]; then
    sed -i 's/^Enable SSH = .*/Enable SSH = true/' "$ini" || true
  else
    sed -i 's/^Enable SSH = .*/Enable SSH = false/' "$ini" || true
  fi

  if [ "${ENABLE_FORK}" = "true" ]; then
    sed -i 's/^Fork = .*/Fork = true/' "$ini" || true
  else
    sed -i 's/^Fork = .*/Fork = false/' "$ini" || true
  fi
  # Ensure included config file references keep config/ prefix (app expects relative path)
  for f in localmail.ini illusionnet.ini filesgen.ini; do
    sed -i "s/\(= \)${f}$/\1config\/${f}/" "$ini" || true
  done
}

seed_file_structure
tune_config

if [ "$1" = "magicka" ] && [ $# -eq 1 ]; then
  set -- magicka "$CONFIG_DIR/bbs.ini"
fi

# Run from DATA_DIR so relative 'config/...' paths resolve
cd "$DATA_DIR"

echo "Starting MagickaBBS with: $@" >&2
exec "$@"
