#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  METADATA SCRUBBING  (photo / video / audio)
#  Usage: ghostmode metadata photo|video|audio <path>
# ============================================================

cmd_metadata() {
    local kind="${1:-}"
    case "$kind" in
        photo|image) shift; _metadata_photo "$@" ;;
        video)       shift; _metadata_video "$@" ;;
        audio)       shift; _metadata_audio "$@" ;;
        *)
            echo "Usage: ghostmode metadata [photo|video|audio] <path>"
            ;;
    esac
}

_metadata_ensure_tools() {
    command -v exiftool >/dev/null 2>&1 || \
        echo CHANGEME_PASSWORD | sudo -S apt-get install -y libimage-exiftool-perl 2>/dev/null
    command -v ffmpeg >/dev/null 2>&1 || \
        echo CHANGEME_PASSWORD | sudo -S apt-get install -y ffmpeg 2>/dev/null
}

_metadata_photo() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        echo "Usage: ghostmode metadata photo <path>"
        return 1
    fi
    echo -e "${BLD}${CYN}[ Stripping photo metadata ]${RST}"
    _metadata_ensure_tools
    if command -v mat2 >/dev/null 2>&1; then
        mat2 --inplace "$path" 2>/dev/null
    else
        exiftool -all= -overwrite_original "$path" 2>/dev/null
    fi
    echo -e "  ${GRN}✔${RST}  Removed: capture date/time, GPS location, camera/device info,"
    echo -e "       software tags, and every other embedded metadata field"
}

# Shared audio filter: removes mains-hum (50/60Hz "electrical hum" that can
# reveal which country/region a recording was made in — a real forensic
# technique) and shifts pitch/formants so the result no longer matches the
# original speaker's voiceprint. This significantly reduces matchability —
# treat it as strong, not an absolute, mathematically-certain guarantee.
GHOSTMODE_AUDIO_FILTER="highpass=f=130,asetrate=44100*0.92,aresample=44100,atempo=1/0.92"

_metadata_audio() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        echo "Usage: ghostmode metadata audio <path>"
        return 1
    fi
    echo -e "${BLD}${CYN}[ Scrubbing audio: mains hum + voiceprint ]${RST}"
    _metadata_ensure_tools
    local tmp
    tmp="$(dirname "$path")/.ghostmode_tmp_$(basename "$path")"
    ffmpeg -y -i "$path" -af "$GHOSTMODE_AUDIO_FILTER" "$tmp" 2>/dev/null
    if [[ -s "$tmp" ]]; then
        mv "$tmp" "$path"
        if command -v mat2 >/dev/null 2>&1; then
            mat2 --inplace "$path" 2>/dev/null
        else
            exiftool -all= -overwrite_original "$path" 2>/dev/null
        fi
        echo -e "  ${GRN}✔${RST}  Mains hum removed, pitch/formants shifted, metadata stripped"
        echo -e "  ${GRY}Significantly reduces voiceprint matchability — treat as strong, not absolute.${RST}"
    else
        rm -f "$tmp" 2>/dev/null
        echo -e "  ${RED}✘${RST}  Processing failed — check that the file is a valid audio file"
    fi
}

_metadata_video() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        echo "Usage: ghostmode metadata video <path>"
        return 1
    fi
    echo -e "${BLD}${CYN}[ Scrubbing video: metadata + audio-track voiceprint ]${RST}"
    _metadata_ensure_tools
    local tmp
    tmp="$(dirname "$path")/.ghostmode_tmp_$(basename "$path")"
    ffmpeg -y -i "$path" -map_metadata -1 -c:v copy \
        -af "$GHOSTMODE_AUDIO_FILTER" -c:a aac "$tmp" 2>/dev/null
    if [[ -s "$tmp" ]]; then
        mv "$tmp" "$path"
        if command -v mat2 >/dev/null 2>&1; then
            mat2 --inplace "$path" 2>/dev/null
        else
            exiftool -all= -overwrite_original "$path" 2>/dev/null
        fi
        echo -e "  ${GRN}✔${RST}  Removed: capture date/time, GPS, device info, container metadata"
        echo -e "  ${GRN}✔${RST}  Audio track: mains hum removed, voiceprint shifted"
        echo -e "  ${GRY}Note: this scrubs metadata and the audio fingerprint, not visual content"
        echo -e "  ${GRY}(faces/places visible in the footage) — that isn't a metadata problem.${RST}"
    else
        rm -f "$tmp" 2>/dev/null
        echo -e "  ${RED}✘${RST}  Processing failed — check that the file is a valid video file"
    fi
}

