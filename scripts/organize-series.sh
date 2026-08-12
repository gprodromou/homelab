#!/bin/bash
#
# organize-series.sh — Restructure a downloaded season pack into Plex layout.
#
# Usage:
#   organize-series.sh "<folder name>"          (dry-run: shows what it WOULD do)
#   organize-series.sh --go "<folder name>"     (actually moves files)
#
# It reads from the TV downloads folder and writes into the Plex TV library,
# creating:   Show Name (Year)/Season 0X/<episodes>
#
# Safe by default: does nothing until you add --go.

set -uo pipefail

# ---- Config: adjust these two paths if your layout ever changes ----
TV_LIB="/mnt/data_1tb/media/tv"          # where Plex looks for shows
SEARCH_DIRS=("$TV_LIB")                   # where to look for the source folder
# --------------------------------------------------------------------

# --- Parse arguments ---
DRY_RUN=true
if [[ "${1:-}" == "--go" ]]; then
  DRY_RUN=false
  shift
fi

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
  echo "Usage: $0 [--go] \"<folder name>\""
  echo "  Without --go, it's a dry run (shows the plan, changes nothing)."
  exit 1
fi

# --- Locate the source folder ---
SRC=""
for d in "${SEARCH_DIRS[@]}"; do
  if [[ -d "$d/$INPUT" ]]; then
    SRC="$d/$INPUT"
    break
  fi
done
if [[ -z "$SRC" ]]; then
  echo "ERROR: folder not found: $INPUT"
  echo "Looked in: ${SEARCH_DIRS[*]}"
  exit 1
fi

echo "Source: $SRC"
echo ""

# --- Find video files ---
mapfile -t FILES < <(find "$SRC" -maxdepth 1 -type f \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' \) | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: no video files (.mkv/.mp4/.avi) found in that folder."
  exit 1
fi

# --- Derive the show name + year from the FOLDER name ---
# Take everything up to the first "S0x" / season / year marker.
folder=$(basename "$SRC")

# Extract year (first 19xx/20xx found), if any
YEAR=$(echo "$folder" | grep -oE '(19|20)[0-9]{2}' | head -1)

# Show name = text before the year, or before SxxExx / SNN, cleaned up
name_raw=$(echo "$folder" | sed -E 's/[._]/ /g')                 # dots/underscores -> spaces
name_raw=$(echo "$name_raw" | sed -E 's/ (19|20)[0-9]{2}.*//')   # cut at year
name_raw=$(echo "$name_raw" | sed -E 's/ [Ss][0-9]{1,2}([Ee][0-9]{1,2})?.*//') # or at SxxExx
SHOW=$(echo "$name_raw" | sed -E 's/[[:space:]]+$//')            # trim trailing space

if [[ -n "$YEAR" ]]; then
  SHOW_DIR="$SHOW ($YEAR)"
else
  SHOW_DIR="$SHOW"
fi

echo "Detected show : $SHOW"
echo "Detected year : ${YEAR:-<none>}"
echo "Target folder : $TV_LIB/$SHOW_DIR"
echo ""

# --- Plan the moves: figure out each file's season ---
echo "Plan:"
declare -A SEASONS_SEEN
PLAN=()
for f in "${FILES[@]}"; do
  base=$(basename "$f")
  # Extract season number from SxxExx (case-insensitive)
  season=$(echo "$base" | grep -oiE 'S[0-9]{1,2}E[0-9]{1,2}' | head -1 | grep -oiE 'S[0-9]{1,2}' | grep -oE '[0-9]{1,2}')
  if [[ -z "$season" ]]; then
    echo "  SKIP (no SxxExx found): $base"
    continue
  fi
  season_padded=$(printf "%02d" "$((10#$season))")
  dest_dir="$TV_LIB/$SHOW_DIR/Season $season_padded"
  SEASONS_SEEN[$season_padded]=1
  PLAN+=("$f|$dest_dir/$base")
  echo "  $base  ->  Season $season_padded/"
done

if [[ ${#PLAN[@]} -eq 0 ]]; then
  echo ""
  echo "Nothing to do — no files matched the SxxExx pattern."
  exit 1
fi

echo ""

# --- Execute or stop ---
if $DRY_RUN; then
  echo "DRY RUN — nothing was moved."
  echo "If this looks right, run again with --go :"
  echo "    $0 --go \"$INPUT\""
  exit 0
fi

echo "Moving files..."
for entry in "${PLAN[@]}"; do
  src="${entry%%|*}"
  dst="${entry##*|}"
  mkdir -p "$(dirname "$dst")"
  mv -n "$src" "$dst"
  echo "  moved: $(basename "$dst")"
done

# --- Clean up the now-empty source folder ---
if [[ -z "$(find "$SRC" -type f 2>/dev/null)" ]]; then
  rm -rf "$SRC"
  echo "Removed empty source folder."
fi

echo ""
echo "Done. Now trigger a Plex scan:"
echo "  plex.local -> TV Shows -> ... -> Scan Library Files"
