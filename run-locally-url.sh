#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"
cd "${ORIG_DIR}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

main() {
  cwltool --outdir out convert-url-app.cwl#convert --fn resize --url "https://eoepca.org/media_portal/images/logo6_med.original.png" --size "50%"
}

main "$@"
