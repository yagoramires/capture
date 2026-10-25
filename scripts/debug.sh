#!/bin/zsh
# Envia um comando ao Capture aberto (precisa de: defaults write local.capture debugBridge -bool true).
# Uso: scripts/debug.sh shot-screen | copy-screen | record-screen | record-area | record-stop | toolbar
#                       | dump
# O dump vai para /tmp/capture-debug.txt.
set -euo pipefail
swift - "$*" <<'SWIFT'
import Foundation
DistributedNotificationCenter.default().postNotificationName(
    .init("local.capture.debug"), object: CommandLine.arguments[1], userInfo: nil, deliverImmediately: true)
SWIFT
