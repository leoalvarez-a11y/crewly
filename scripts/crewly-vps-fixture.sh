#!/usr/bin/env bash
set -euo pipefail

FIXTURE_ROOT="/tmp/crewly-deploy/fixture"

case "${1:-}" in
  run)
    if [[ -e "$FIXTURE_ROOT" ]]; then
      printf '%s\n' 'FIXTURE_ALREADY_EXISTS'
      exit 17
    fi
    mkdir -p "$FIXTURE_ROOT/src" "$FIXTURE_ROOT/test"
    git -C "$FIXTURE_ROOT" init --initial-branch=main
    printf '%s\n' '{"name":"crewly-vps-fixture","private":true,"type":"module","scripts":{"test":"node --test"}}' > "$FIXTURE_ROOT/package.json"
    printf '%s\n' 'export function clamp(value, min, max) { return Math.min(min, value); }' > "$FIXTURE_ROOT/src/clamp.js"
    printf '%s\n' "import test from 'node:test'; import assert from 'node:assert/strict'; import { clamp } from '../src/clamp.js'; test('clamps both bounds', () => { assert.equal(clamp(12, 0, 10), 10); assert.equal(clamp(-2, 0, 10), 0); });" > "$FIXTURE_ROOT/test/clamp.test.js"
    printf '%s\n' '# Crewly VPS disposable fixture' > "$FIXTURE_ROOT/README.md"
    git -C "$FIXTURE_ROOT" add package.json src/clamp.js test/clamp.test.js README.md
    git -C "$FIXTURE_ROOT" -c user.name='Crewly Fixture' -c user.email='fixture@invalid.local' commit -m 'test: add failing VPS fixture'
    printf '%s\n' "FIXTURE_READY=$FIXTURE_ROOT"
    ;;
  cleanup)
    case "$FIXTURE_ROOT" in
      /tmp/crewly-deploy/fixture) rm -rf -- "$FIXTURE_ROOT" ;;
      *) printf '%s\n' 'FIXTURE_PATH_REJECTED' >&2; exit 64 ;;
    esac
    printf '%s\n' 'FIXTURE_CLEANED=true'
    ;;
  *)
    printf '%s\n' 'USAGE: crewly-vps-fixture.sh run|cleanup' >&2
    exit 64
    ;;
esac
