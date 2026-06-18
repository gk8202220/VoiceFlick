#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${1:-$HOME/Library/Application Support/VoiceFlick/runtime.log}"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "runtime log not found: $LOG_PATH" >&2
  exit 1
fi

/usr/bin/awk '
  /logger ready/ {
    session += 1
    frames = 0
    handTrue = 0
    handFalse = 0
    fist = 0
    victory = 0
    starts = 0
    stops = 0
    returns = 0
    trustedFalse = 0
    trustedTrue = 0
    sequence = ""
    sessionStart = $1
  }

  session > 0 {
    if ($0 ~ /frame /) {
      frames += 1
      if ($0 ~ /hand=true/) handTrue += 1
      if ($0 ~ /hand=false/) handFalse += 1
      if ($0 ~ /gesture=closedFist/) fist += 1
      if ($0 ~ /gesture=victory/) victory += 1
    }
    if ($0 ~ /action startDictation/) {
      starts += 1
      sequence = sequence "S"
    }
    if ($0 ~ /action stopDictation/) {
      stops += 1
      sequence = sequence "T"
    }
    if ($0 ~ /action pressReturn/) {
      returns += 1
      sequence = sequence "R"
    }
    if ($0 ~ /perform requested/ && $0 ~ /trusted=false/) trustedFalse += 1
    if ($0 ~ /perform requested/ && $0 ~ /trusted=true/) trustedTrue += 1
  }

  END {
    print "VoiceFlick runtime stress summary"
    print "session:", session, "started:", sessionStart
    print "frames:", frames, "hand=true:", handTrue, "hand=false:", handFalse
    print "closedFist frames:", fist, "victory frames:", victory
    print "actions start:", starts, "stop:", stops, "return:", returns
    print "trusted=true actions:", trustedTrue, "trusted=false actions:", trustedFalse
    print "action sequence:", sequence

    ok = 1
    if (starts < 1) {
      print "FAIL: no startDictation action observed"
      ok = 0
    }
    if (stops < 1) {
      print "FAIL: no stopDictation action observed"
      ok = 0
    }
    if (sequence !~ /STS/) {
      print "WARN: latest session did not contain a full start-stop-start continuity cycle"
    }
    if (trustedFalse > 0) {
      print "WARN: Accessibility still blocked at least one action"
    }
    if (ok == 0) exit 1
  }
' "$LOG_PATH"
