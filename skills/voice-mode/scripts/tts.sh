#!/usr/bin/env bash
set -euo pipefail

PORT="${POCKET_TTS_PORT:-18731}"
HOST="http://localhost:${PORT}"
VOICE="${POCKET_TTS_VOICE:-eponine}"
SPEED="${POCKET_TTS_SPEED:-1.2}"

usage() {
    echo "Usage: tts.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  say <text> [-v voice] [-o output]   Generate speech"
    echo "  play <text> [-v voice]              Generate and play immediately"
    echo "  voices                              List available voices"
    echo "  health                              Check server status"
    echo "  ensure                              Check container is running (exit 1 if not)"
    echo ""
    echo "Voices: alba marius javert jean fantine cosette eponine azelma"
    echo ""
    echo "Environment:"
    echo "  POCKET_TTS_PORT   Server port (default: 18731)"
    echo "  POCKET_TTS_VOICE  Default voice (default: eponine)"
    echo "  POCKET_TTS_SPEED  Playback speed (default: 1.2)"
}

cmd_health() {
    curl -sf "${HOST}/health" 2>/dev/null && echo "ok" || echo "unreachable"
}

cmd_ensure() {
    if curl -sf "${HOST}/health" >/dev/null 2>&1; then
        echo "ok"
        return 0
    fi
    echo "Error: pocket-tts container is not running on port ${PORT}" >&2
    echo "Start it with: POCKET_TTS_PORT=${PORT} docker compose up -d (from your pocket-tts repo)" >&2
    return 1
}

cmd_voices() {
    echo "alba marius javert jean fantine cosette eponine azelma"
}

cmd_say() {
    local text="" voice="${VOICE}" output=""

    if [[ $# -lt 1 ]]; then
        echo "Error: text required" >&2
        exit 1
    fi
    text="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--voice) voice="$2"; shift 2 ;;
            -o|--output) output="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -z "$output" ]]; then
        output="/tmp/tts-$(date +%s%N).wav"
    fi

    curl -sf -X POST "${HOST}/tts" \
        -F "text=${text}" \
        -F "voice_url=${voice}" \
        --output "${output}"

    echo "${output}"
}

cmd_play() {
    local output
    output=$(cmd_say "$@")
    mpv --no-video --really-quiet --speed="${SPEED}" "$output" 2>/dev/null
    rm -f "$output"
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

cmd="$1"; shift
case "$cmd" in
    say)    cmd_say "$@" ;;
    play)   cmd_play "$@" ;;
    voices) cmd_voices ;;
    health) cmd_health ;;
    ensure) cmd_ensure ;;
    *)      usage; exit 1 ;;
esac
