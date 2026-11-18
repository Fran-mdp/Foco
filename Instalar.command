#!/bin/bash
# Build reviewed source locally and install for the current user; no sudo or downloads.
set -euo pipefail
FOCO_ROOT="$(cd "$(dirname "$0")" && pwd)"
FOCO_CHECK_ONLY=false
case "${1:-}" in
  '') ;;
  --check) FOCO_CHECK_ONLY=true ;;
  *) echo 'Uso: bash Instalar.command [--check]' >&2; exit 2 ;;
esac
fail() { echo "Foco: $*" >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || fail 'Esta versión requiere macOS.'
[ "$(uname -m)" = arm64 ] || fail 'Necesitás una Mac Apple Silicon y una Terminal nativa (sin Rosetta).'
FOCO_OS="$(sw_vers -productVersion)"
[ "${FOCO_OS%%.*}" -ge 26 ] || fail 'Necesitás macOS 26 o posterior.'
xcode-select -p >/dev/null 2>&1 || fail 'Instalá las herramientas de Apple con: xcode-select --install. Después repetí este comando.'
FOCO_SDK="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null)" || fail 'No se encuentra el SDK de macOS. Actualizá las herramientas de Apple.'
[ "${FOCO_SDK%%.*}" -ge 26 ] || fail 'El SDK es anterior a macOS 26. Actualizá las herramientas de Apple.'
command -v python3 >/dev/null || fail 'Falta Python 3, incluido con las herramientas de Apple.'
[ -f "$FOCO_ROOT/codigo/build.sh" ] || fail 'Descomprimí el proyecto completo: falta codigo/build.sh.'
if "$FOCO_CHECK_ONLY"; then
  echo 'Requisitos correctos. No se compiló ni instaló nada.'
  exit 0
fi
if pgrep -x Foco >/dev/null; then
  fail 'Salí de Foco desde su menú antes de actualizar. Guardá tu trabajo y terminá el bloque si hay uno activo.'
fi
FOCO_PARENT="$HOME/Applications"
FOCO_DEST="$FOCO_PARENT/Foco.app"
# Validate an existing destination before replacing any files.
python3 - "$FOCO_DEST" <<'PY'
from pathlib import Path
import plistlib,sys
p=Path(sys.argv[1])
if p.is_symlink(): raise SystemExit('Foco: el destino es un enlace. No se reemplazó.')
if p.exists():
    try: identifier=plistlib.loads((p/'Contents/Info.plist').read_bytes()).get('CFBundleIdentifier')
    except Exception: raise SystemExit('Foco: el destino no es una app reconocida. No se reemplazó.')
    if identifier != 'local.foco.Foco': raise SystemExit('Foco: ya existe otra aplicación con ese nombre. No se reemplazó.')
PY
echo 'Compilando Foco en tu Mac. Puede tardar unos minutos…'
bash "$FOCO_ROOT/codigo/build.sh"
mkdir -p "$FOCO_PARENT"
FOCO_STAGE="$(mktemp -d "$FOCO_PARENT/.foco-install.XXXXXX")"
cleanup() {
  if [ -d "$FOCO_STAGE/anterior.app" ] && [ ! -e "$FOCO_DEST" ]; then
    mv "$FOCO_STAGE/anterior.app" "$FOCO_DEST"
  fi
  rm -rf "$FOCO_STAGE"
}
trap cleanup EXIT
ditto -x -k "$FOCO_ROOT/Foco-Mac.zip" "$FOCO_STAGE"
codesign --verify --deep --strict "$FOCO_STAGE/Foco.app"
if [ -e "$FOCO_DEST" ]; then
  mkdir -p "$FOCO_ROOT/.build"
  ditto -c -k --keepParent --norsrc --noextattr "$FOCO_DEST" "$FOCO_ROOT/.build/Foco-anterior.zip"
  mv "$FOCO_DEST" "$FOCO_STAGE/anterior.app"
fi
mv "$FOCO_STAGE/Foco.app" "$FOCO_DEST"
echo ''
echo "Foco instalada en: $FOCO_DEST"
echo 'Abrila desde tu carpeta personal → Aplicaciones → Foco.'
echo 'Después seguí el paso 3 del README para conectar Chrome.'
echo 'Tus datos y permisos de sitios no fueron reemplazados.'
