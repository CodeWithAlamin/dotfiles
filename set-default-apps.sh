#!/usr/bin/env bash

set -u
set -o pipefail

# ============================================================
# CachyOS / Niri
# Default Applications Manager
#
# Behavior:
#   1. Scan installed applications ONCE at startup
#   2. Build a cached application database
#   3. Build cached lists for every category
#   4. Let the user make pending selections
#   5. Change NOTHING while selecting
#   6. Apply EVERYTHING only when "Apply All" is selected
#   7. Report every successful/failed association
#   8. View currently configured default applications
#   9. Exit after applying
#
# Application detection is dynamic:
#   - .desktop metadata
#   - MIME types
#   - Categories
#   - Name
#   - GenericName
#   - Comment
#   - Exec
#
# No application is hardcoded.
# ============================================================


# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

BOLD=$'\033[1m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'
RESET=$'\033[0m'


# ------------------------------------------------------------
# Temporary directory
# ------------------------------------------------------------

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM


# ============================================================
# REQUIREMENTS
# ============================================================

if ! command -v xdg-mime >/dev/null 2>&1; then
    echo -e "${RED}xdg-mime is required.${RESET}"
    echo
    echo "Install it with:"
    echo "sudo pacman -S xdg-utils"
    exit 1
fi


# ============================================================
# APPLICATION DISCOVERY
# ============================================================

clear

echo
echo -e "${BOLD}${CYAN}╭────────────────────────────────────────────────────╮${RESET}"
echo -e "${BOLD}${CYAN}│          Default Applications Manager             │${RESET}"
echo -e "${BOLD}${CYAN}╰────────────────────────────────────────────────────╯${RESET}"
echo
echo "Scanning installed applications..."
echo -e "${DIM}This happens only once.${RESET}"
echo


# ------------------------------------------------------------
# Desktop application directories
# ------------------------------------------------------------

DESKTOP_DIRS=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/applications"
)


# Flatpak user applications

[[ -d "$HOME/.local/share/flatpak/exports/share/applications" ]] &&
    DESKTOP_DIRS+=(
        "$HOME/.local/share/flatpak/exports/share/applications"
    )


# Flatpak system applications

[[ -d "/var/lib/flatpak/exports/share/applications" ]] &&
    DESKTOP_DIRS+=(
        "/var/lib/flatpak/exports/share/applications"
    )


# ------------------------------------------------------------
# Desktop database
#
# Fields:
#   name
#   generic name
#   comment
#   desktop ID
#   full path
#   MIME types
#   categories
#   Exec
# ------------------------------------------------------------

DESKTOP_DB="$TMP_DIR/desktop.db"

find "${DESKTOP_DIRS[@]}" \
    -maxdepth 1 \
    -type f \
    -name '*.desktop' \
    -print 2>/dev/null |
    sort -u |
    while IFS= read -r file; do

        type="$(
            awk -F= '
                $1=="Type" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        hidden="$(
            awk -F= '
                $1=="Hidden" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        nodisplay="$(
            awk -F= '
                $1=="NoDisplay" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        name="$(
            awk -F= '
                $1=="Name" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        generic_name="$(
            awk -F= '
                $1=="GenericName" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        comment="$(
            awk -F= '
                $1=="Comment" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        mimes="$(
            awk -F= '
                $1=="MimeType" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        categories="$(
            awk -F= '
                $1=="Categories" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        exec_line="$(
            awk -F= '
                $1=="Exec" {
                    print substr($0,index($0,"=")+1)
                    exit
                }
            ' "$file"
        )"

        [[ "$type" == "Application" ]] || continue
        [[ "$hidden" == "true" ]] && continue
        [[ "$nodisplay" == "true" ]] && continue
        [[ -n "$name" ]] || continue

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$name" \
            "$generic_name" \
            "$comment" \
            "$(basename "$file")" \
            "$file" \
            "$mimes" \
            "$categories" \
            "$exec_line"

    done > "$DESKTOP_DB"


APP_COUNT="$(wc -l < "$DESKTOP_DB")"

echo -e "${GREEN}✓ Found $APP_COUNT applications.${RESET}"
sleep 0.7


# ============================================================
# CACHE APPLICATION LISTS
# ============================================================

declare -A APP_LISTS


# ------------------------------------------------------------
# Generic MIME-based category cache
# ------------------------------------------------------------

cache_mimes() {

    local key="$1"
    shift

    local output="$TMP_DIR/$key"
    local raw="$TMP_DIR/${key}.raw"

    : > "$raw"

    while IFS=$'\t' read -r \
        name generic_name comment desktop file mimes categories exec_line
    do

        for wanted_mime in "$@"; do

            if [[ ";$mimes" == *";$wanted_mime;"* ]]; then

                printf '%s\t%s\n' \
                    "$name" \
                    "$desktop" >> "$raw"

                break
            fi

        done

    done < "$DESKTOP_DB"

    awk -F '\t' '!seen[$1]++' "$raw" |
        sort -f > "$output"

    APP_LISTS["$key"]="$output"
}


# ============================================================
# STANDARD CATEGORIES
# ============================================================

cache_mimes browser \
    "x-scheme-handler/http" \
    "x-scheme-handler/https" \
    "text/html" \
    "application/xhtml+xml"


cache_mimes filemanager \
    "inode/directory"


cache_mimes texteditor \
    "text/plain"


cache_mimes image \
    "image/jpeg" \
    "image/png" \
    "image/gif" \
    "image/webp" \
    "image/bmp" \
    "image/tiff" \
    "image/svg+xml" \
    "image/x-icon" \
    "image/avif"


cache_mimes video \
    "video/mp4" \
    "video/x-matroska" \
    "video/webm" \
    "video/x-msvideo" \
    "video/mpeg" \
    "video/quicktime" \
    "video/x-flv" \
    "video/ogg"


cache_mimes audio \
    "audio/mpeg" \
    "audio/mp4" \
    "audio/ogg" \
    "audio/flac" \
    "audio/wav" \
    "audio/x-wav" \
    "audio/webm" \
    "audio/aac" \
    "audio/x-m4a"


# ============================================================
# PDF VIEWER / EDITOR
#
# Detection is intentionally broader than MimeType alone.
#
# An application can still be a PDF application if its desktop
# entry does not correctly advertise application/pdf.
#
# We inspect:
#   - MIME types
#   - Categories
#   - Name
#   - GenericName
#   - Comment
#   - Exec
#
# No application name is hardcoded.
# ============================================================

PDF_LIST="$TMP_DIR/pdf"
PDF_RAW="$TMP_DIR/pdf.raw"

: > "$PDF_RAW"

while IFS=$'\t' read -r \
    name generic_name comment desktop file mimes categories exec_line
do

    combined="$(
        printf '%s\n%s\n%s\n%s\n%s\n%s' \
            "$name" \
            "$generic_name" \
            "$comment" \
            "$mimes" \
            "$categories" \
            "$exec_line" |
        tr '[:upper:]' '[:lower:]'
    )"

    is_pdf=false


    # Direct MIME declaration

    if [[ ";$mimes" == *";application/pdf;"* ]]; then
        is_pdf=true
    fi


    # Desktop metadata

    if [[ "$combined" =~ (^|[^[:alnum:]])pdf([^[:alnum:]]|$) ]]; then
        is_pdf=true
    fi


    # Document-related categories combined with PDF wording

    if [[ "$categories" =~ (Office|Viewer|Graphics|Utility|Documentation) ]] &&
       [[ "$combined" =~ pdf ]]; then

        is_pdf=true

    fi


    if [[ "$is_pdf" == true ]]; then

        printf '%s\t%s\n' \
            "$name" \
            "$desktop" >> "$PDF_RAW"

    fi

done < "$DESKTOP_DB"


awk -F '\t' '!seen[$1]++' "$PDF_RAW" |
    sort -f > "$PDF_LIST"

APP_LISTS["pdf"]="$PDF_LIST"


# ============================================================
# E-BOOK
# ============================================================

cache_mimes ebook \
    "application/epub+zip" \
    "application/x-mobipocket-ebook"


# ============================================================
# ARCHIVES
# ============================================================

cache_mimes archive \
    "application/zip" \
    "application/x-7z-compressed" \
    "application/x-rar" \
    "application/x-tar" \
    "application/gzip" \
    "application/x-bzip2" \
    "application/x-xz" \
    "application/x-compressed-tar"


# ============================================================
# OFFICE
# ============================================================

cache_mimes word \
    "application/msword" \
    "application/rtf" \
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"


cache_mimes spreadsheet \
    "text/csv" \
    "application/vnd.ms-excel" \
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


cache_mimes presentation \
    "application/vnd.ms-powerpoint" \
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"


# ============================================================
# EMAIL
# ============================================================

cache_mimes email \
    "x-scheme-handler/mailto"


# ============================================================
# TORRENT / MAGNET
# ============================================================

cache_mimes torrent \
    "x-scheme-handler/magnet" \
    "application/x-bittorrent"


# ============================================================
# TERMINAL APPLICATIONS
#
# Detection uses:
#   - TerminalEmulator category
#   - Terminal-related metadata
#
# No specific application is selected automatically.
# ============================================================

TERMINAL_LIST="$TMP_DIR/terminal"
TERMINAL_RAW="$TMP_DIR/terminal.raw"

: > "$TERMINAL_RAW"

while IFS=$'\t' read -r \
    name generic_name comment desktop file mimes categories exec_line
do

    combined="$(
        printf '%s\n%s\n%s\n%s\n%s' \
            "$name" \
            "$generic_name" \
            "$comment" \
            "$categories" \
            "$exec_line" |
        tr '[:upper:]' '[:lower:]'
    )"

    is_terminal=false


    if [[ ";$categories" == *";TerminalEmulator;"* ]]; then
        is_terminal=true
    fi


    if [[ "$combined" =~ terminal ]] ||
       [[ "$combined" =~ terminal-emulator ]]; then

        is_terminal=true

    fi


    if [[ "$is_terminal" == true ]]; then

        printf '%s\t%s\n' \
            "$name" \
            "$desktop" >> "$TERMINAL_RAW"

    fi

done < "$DESKTOP_DB"


awk -F '\t' '!seen[$1]++' "$TERMINAL_RAW" |
    sort -f > "$TERMINAL_LIST"

APP_LISTS["terminal"]="$TERMINAL_LIST"


# ============================================================
# PENDING SELECTIONS
# ============================================================

declare -A SELECTED_NAME
declare -A SELECTED_DESKTOP


# ============================================================
# APPLICATION SELECTOR
# ============================================================

choose_app() {

    local key="$1"
    local title="$2"
    local file="${APP_LISTS[$key]}"

    mapfile -t OPTIONS < "$file"


    clear

    echo
    echo -e "${BOLD}${CYAN}$title${RESET}"
    echo


    if (( ${#OPTIONS[@]} == 0 )); then

        echo -e \
            "${YELLOW}No compatible installed applications were found.${RESET}"

        echo

        read -rp "Press Enter to return..."

        return

    fi


    OPTIONS+=("Cancel")


    local cursor=0
    local count=${#OPTIONS[@]}
    local keypress
    local name
    local selected


    while true; do

        clear

        echo
        echo -e "${BOLD}${CYAN}$title${RESET}"
        echo


        for ((i=0; i<count; i++)); do

            name="${OPTIONS[$i]%%$'\t'*}"


            if (( i == cursor )); then

                echo -e \
                    "  ${GREEN}❯${RESET} ${BOLD}${name}${RESET}"

            else

                echo "    $name"

            fi

        done


        echo
        echo -e \
            "${DIM}↑ ↓ Move   Enter Select   Esc Cancel${RESET}"


        IFS= read -rsn1 keypress


        case "$keypress" in

            $'\x1b')

                IFS= read -rsn2 keypress 2>/dev/null || true


                case "$keypress" in

                    '[A')
                        ((cursor--)) || true
                        ;;

                    '[B')
                        ((cursor++)) || true
                        ;;

                    '')
                        return
                        ;;

                esac

                ;;


            '')

                if (( cursor == count - 1 )); then
                    return
                fi


                selected="${OPTIONS[$cursor]}"


                SELECTED_NAME["$key"]="${selected%%$'\t'*}"
                SELECTED_DESKTOP["$key"]="${selected#*$'\t'}"


                return

                ;;

        esac


        (( cursor < 0 )) && cursor=$((count - 1))
        (( cursor >= count )) && cursor=0

    done
}


# ============================================================
# CURRENT DEFAULTS
# ============================================================

get_default_name() {

    local mime="$1"
    local desktop
    local name


    desktop="$(
        xdg-mime query default "$mime" 2>/dev/null || true
    )"


    if [[ -z "$desktop" ]]; then

        printf '%s\n' "Not set"

        return

    fi


    name="$(
        awk -F '\t' \
            -v id="$desktop" \
            '$4 == id {
                print $1
                exit
            }' \
            "$DESKTOP_DB"
    )"


    if [[ -n "$name" ]]; then

        printf '%s\n' "$name"

    else

        printf '%s\n' "$desktop"

    fi
}


show_current_defaults() {

    clear

    echo
    echo -e \
        "${BOLD}${CYAN}╭────────────────────────────────────────────────────╮${RESET}"

    echo -e \
        "${BOLD}${CYAN}│              Current Default Applications         │${RESET}"

    echo -e \
        "${BOLD}${CYAN}╰────────────────────────────────────────────────────╯${RESET}"

    echo


    printf "  %-30s %s\n" \
        "Web Browser" \
        "$(get_default_name 'x-scheme-handler/http')"


    printf "  %-30s %s\n" \
        "File Manager" \
        "$(get_default_name 'inode/directory')"


    printf "  %-30s %s\n" \
        "Text Editor" \
        "$(get_default_name 'text/plain')"


    printf "  %-30s %s\n" \
        "Image Viewer" \
        "$(get_default_name 'image/jpeg')"


    printf "  %-30s %s\n" \
        "Video Player" \
        "$(get_default_name 'video/mp4')"


    printf "  %-30s %s\n" \
        "Audio Player" \
        "$(get_default_name 'audio/mpeg')"


    printf "  %-30s %s\n" \
        "PDF Viewer / Editor" \
        "$(get_default_name 'application/pdf')"


    printf "  %-30s %s\n" \
        "E-book Reader" \
        "$(get_default_name 'application/epub+zip')"


    printf "  %-30s %s\n" \
        "Archive Manager" \
        "$(get_default_name 'application/zip')"


    printf "  %-30s %s\n" \
        "Word Processor" \
        "$(get_default_name 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')"


    printf "  %-30s %s\n" \
        "Spreadsheet" \
        "$(get_default_name 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')"


    printf "  %-30s %s\n" \
        "Presentation" \
        "$(get_default_name 'application/vnd.openxmlformats-officedocument.presentationml.presentation')"


    printf "  %-30s %s\n" \
        "Email Client" \
        "$(get_default_name 'x-scheme-handler/mailto')"


    printf "  %-30s %s\n" \
        "Torrent / Magnet" \
        "$(get_default_name 'x-scheme-handler/magnet')"


    # --------------------------------------------------------
    # Terminal
    #
    # Terminal is not an XDG MIME association.
    # --------------------------------------------------------

    local terminal_current="${TERMINAL:-}"


    if [[ -z "$terminal_current" && -f "$HOME/.profile" ]]; then

        terminal_current="$(
            sed -n \
                's/^[[:space:]]*export TERMINAL=//p' \
                "$HOME/.profile" |
            tail -n 1
        )"


        terminal_current="${terminal_current#\"}"
        terminal_current="${terminal_current%\"}"

        terminal_current="${terminal_current#\'}"
        terminal_current="${terminal_current%\'}"

    fi


    [[ -z "$terminal_current" ]] &&
        terminal_current="Not set"


    printf "  %-30s %s\n" \
        "Terminal Emulator" \
        "$terminal_current"


    echo

    echo -e \
        "${DIM}These are the defaults currently configured on your system.${RESET}"

    echo

    read -rp "Press Enter to return to the menu..."

}


# ============================================================
# APPLY TRACKING
# ============================================================

SUCCESS_COUNT=0
FAIL_COUNT=0

declare -a FAILED_ASSOCIATIONS


# ============================================================
# APPLY ONE MIME ASSOCIATION
# ============================================================

apply_one() {

    local desktop="$1"
    local mime="$2"


    if xdg-mime default "$desktop" "$mime" >/dev/null 2>&1; then

        ((SUCCESS_COUNT++)) || true

    else

        ((FAIL_COUNT++)) || true

        FAILED_ASSOCIATIONS+=(
            "$mime → $desktop"
        )

    fi
}


# ============================================================
# APPLY MULTIPLE MIME TYPES
# ============================================================

apply_mimes() {

    local desktop="$1"
    shift


    [[ -z "$desktop" ]] && return


    local mime


    for mime in "$@"; do

        apply_one "$desktop" "$mime"

    done
}


# ============================================================
# TERMINAL APPLICATION
# ============================================================

apply_terminal() {

    local selected_desktop="$1"
    local selected_name="$2"

    local terminal_file=""
    local exec_line=""
    local executable=""

    while IFS=$'\t' read -r \
        name generic_name comment desktop file mimes categories exec_line_db
    do

        if [[ "$desktop" == "$selected_desktop" ]]; then

            terminal_file="$file"
            exec_line="$exec_line_db"

            break

        fi

    done < "$DESKTOP_DB"


    if [[ -z "$terminal_file" ]]; then

        ((FAIL_COUNT++)) || true

        FAILED_ASSOCIATIONS+=(
            "Terminal → $selected_name"
        )

        return

    fi


    # Extract the first executable from Exec=.

    executable="$(
        awk '
            {
                gsub(/%[fFuUdDnNickvm]/, "")
                print $1
            }
        ' <<< "$exec_line"
    )"


    executable="${executable##*/}"


    if [[ -z "$executable" ]]; then

        ((FAIL_COUNT++)) || true

        FAILED_ASSOCIATIONS+=(
            "Terminal → $selected_name (could not determine executable)"
        )

        return

    fi


    # --------------------------------------------------------
    # Write TERMINAL to shell startup files
    # --------------------------------------------------------

    local shell_failed=false


    touch "$HOME/.profile" || shell_failed=true


    if [[ "$shell_failed" == false ]]; then

        sed -i \
            '/^[[:space:]]*export TERMINAL=/d' \
            "$HOME/.profile" 2>/dev/null ||
            shell_failed=true

    fi


    if [[ "$shell_failed" == false ]]; then

        printf 'export TERMINAL=%q\n' \
            "$executable" >> "$HOME/.profile" ||
            shell_failed=true

    fi


    if [[ -f "$HOME/.bashrc" && "$shell_failed" == false ]]; then

        sed -i \
            '/^[[:space:]]*export TERMINAL=/d' \
            "$HOME/.bashrc" 2>/dev/null ||
            shell_failed=true


        if [[ "$shell_failed" == false ]]; then

            printf 'export TERMINAL=%q\n' \
                "$executable" >> "$HOME/.bashrc" ||
                shell_failed=true

        fi

    fi


    if [[ -f "$HOME/.zshrc" && "$shell_failed" == false ]]; then

        sed -i \
            '/^[[:space:]]*export TERMINAL=/d' \
            "$HOME/.zshrc" 2>/dev/null ||
            shell_failed=true


        if [[ "$shell_failed" == false ]]; then

            printf 'export TERMINAL=%q\n' \
                "$executable" >> "$HOME/.zshrc" ||
                shell_failed=true

        fi

    fi


    if [[ "$shell_failed" == true ]]; then

        ((FAIL_COUNT++)) || true

        FAILED_ASSOCIATIONS+=(
            "Terminal → $selected_name (could not update shell configuration)"
        )

        return

    fi


    export TERMINAL="$executable"

    ((SUCCESS_COUNT++)) || true

    echo -e \
        "${GREEN}✓${RESET} Terminal → $selected_name"

}


# ============================================================
# APPLY EVERYTHING
# ============================================================

apply_all() {

    clear

    SUCCESS_COUNT=0
    FAIL_COUNT=0
    FAILED_ASSOCIATIONS=()


    echo
    echo -e \
        "${BOLD}${CYAN}Applying your selections...${RESET}"

    echo


    # --------------------------------------------------------
    # Browser
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[browser]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[browser]}" \
            "x-scheme-handler/http" \
            "x-scheme-handler/https" \
            "text/html" \
            "application/xhtml+xml"

        echo -e \
            "${GREEN}✓${RESET} Web Browser → ${SELECTED_NAME[browser]}"

    fi


    # --------------------------------------------------------
    # File Manager
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[filemanager]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[filemanager]}" \
            "inode/directory"

        echo -e \
            "${GREEN}✓${RESET} File Manager → ${SELECTED_NAME[filemanager]}"

    fi


    # --------------------------------------------------------
    # Text Editor
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[texteditor]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[texteditor]}" \
            "text/plain" \
            "text/markdown" \
            "text/x-c" \
            "text/x-c++" \
            "text/x-python" \
            "text/x-java" \
            "text/x-shellscript" \
            "text/css" \
            "text/javascript" \
            "application/javascript" \
            "application/json" \
            "application/xml"

        echo -e \
            "${GREEN}✓${RESET} Text Editor → ${SELECTED_NAME[texteditor]}"

    fi


    # --------------------------------------------------------
    # Image Viewer
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[image]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[image]}" \
            "image/jpeg" \
            "image/png" \
            "image/gif" \
            "image/webp" \
            "image/bmp" \
            "image/tiff" \
            "image/svg+xml" \
            "image/x-icon" \
            "image/avif"

        echo -e \
            "${GREEN}✓${RESET} Image Viewer → ${SELECTED_NAME[image]}"

    fi


    # --------------------------------------------------------
    # Video Player
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[video]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[video]}" \
            "video/mp4" \
            "video/x-matroska" \
            "video/webm" \
            "video/x-msvideo" \
            "video/mpeg" \
            "video/quicktime" \
            "video/x-flv" \
            "video/ogg"

        echo -e \
            "${GREEN}✓${RESET} Video Player → ${SELECTED_NAME[video]}"

    fi


    # --------------------------------------------------------
    # Audio Player
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[audio]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[audio]}" \
            "audio/mpeg" \
            "audio/mp4" \
            "audio/ogg" \
            "audio/flac" \
            "audio/wav" \
            "audio/x-wav" \
            "audio/webm" \
            "audio/aac" \
            "audio/x-m4a"

        echo -e \
            "${GREEN}✓${RESET} Audio Player → ${SELECTED_NAME[audio]}"

    fi


    # --------------------------------------------------------
    # PDF Viewer / Editor
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[pdf]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[pdf]}" \
            "application/pdf"

        echo -e \
            "${GREEN}✓${RESET} PDF Viewer → ${SELECTED_NAME[pdf]}"

    fi


    # --------------------------------------------------------
    # E-book Reader
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[ebook]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[ebook]}" \
            "application/epub+zip" \
            "application/x-mobipocket-ebook"

        echo -e \
            "${GREEN}✓${RESET} E-book Reader → ${SELECTED_NAME[ebook]}"

    fi


    # --------------------------------------------------------
    # Archive Manager
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[archive]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[archive]}" \
            "application/zip" \
            "application/x-7z-compressed" \
            "application/x-rar" \
            "application/x-tar" \
            "application/gzip" \
            "application/x-bzip2" \
            "application/x-xz" \
            "application/x-compressed-tar"

        echo -e \
            "${GREEN}✓${RESET} Archive Manager → ${SELECTED_NAME[archive]}"

    fi


    # --------------------------------------------------------
    # Word Processor
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[word]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[word]}" \
            "application/msword" \
            "application/rtf" \
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

        echo -e \
            "${GREEN}✓${RESET} Word Processor → ${SELECTED_NAME[word]}"

    fi


    # --------------------------------------------------------
    # Spreadsheet
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[spreadsheet]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[spreadsheet]}" \
            "text/csv" \
            "application/vnd.ms-excel" \
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

        echo -e \
            "${GREEN}✓${RESET} Spreadsheet → ${SELECTED_NAME[spreadsheet]}"

    fi


    # --------------------------------------------------------
    # Presentation
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[presentation]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[presentation]}" \
            "application/vnd.ms-powerpoint" \
            "application/vnd.openxmlformats-officedocument.presentationml.presentation"

        echo -e \
            "${GREEN}✓${RESET} Presentation → ${SELECTED_NAME[presentation]}"

    fi


    # --------------------------------------------------------
    # Email
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[email]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[email]}" \
            "x-scheme-handler/mailto"

        echo -e \
            "${GREEN}✓${RESET} Email Client → ${SELECTED_NAME[email]}"

    fi


    # --------------------------------------------------------
    # Torrent / Magnet
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[torrent]:-}" ]]; then

        apply_mimes "${SELECTED_DESKTOP[torrent]}" \
            "x-scheme-handler/magnet" \
            "application/x-bittorrent"

        echo -e \
            "${GREEN}✓${RESET} Torrent / Magnet → ${SELECTED_NAME[torrent]}"

    fi


    # --------------------------------------------------------
    # Terminal
    # --------------------------------------------------------

    if [[ -n "${SELECTED_DESKTOP[terminal]:-}" ]]; then

        apply_terminal \
            "${SELECTED_DESKTOP[terminal]}" \
            "${SELECTED_NAME[terminal]}"

    fi


    # ========================================================
    # FINAL REPORT
    # ========================================================

    echo
    echo -e \
        "${DIM}────────────────────────────────────────────────────${RESET}"

    echo


    if (( FAIL_COUNT == 0 )); then

        echo -e \
            "${BOLD}${GREEN}✓ Finished with 0 errors.${RESET}"

    else

        echo -e \
            "${BOLD}${YELLOW}Finished with $FAIL_COUNT error(s).${RESET}"

    fi


    echo

    echo -e \
        "${GREEN}Successful operations:${RESET} $SUCCESS_COUNT"

    echo -e \
        "${RED}Failed operations:${RESET}     $FAIL_COUNT"


    if (( FAIL_COUNT > 0 )); then

        echo
        echo -e \
            "${BOLD}${RED}Failed operations:${RESET}"


        for failure in "${FAILED_ASSOCIATIONS[@]}"; do

            echo -e \
                "  ${RED}✗${RESET} $failure"

        done

    fi


    echo

    read -rp "Press Enter to exit..."

    clear

    exit 0

}


# ============================================================
# MAIN MENU
# ============================================================

MENU_NAMES=(
    "🌐  Web Browser"
    "📁  File Manager"
    "📝  Text Editor"
    "🖼️  Image Viewer"
    "🎬  Video Player"
    "🎵  Audio Player"
    "📄  PDF Viewer / Editor"
    "📚  E-book Reader"
    "🗜️  Archive Manager"
    "📝  Word Processor"
    "📊  Spreadsheet"
    "📽️  Presentation"
    "📧  Email Client"
    "🧲  Torrent / Magnet"
    "🖥️  Terminal Emulator"
)


MENU_KEYS=(
    "browser"
    "filemanager"
    "texteditor"
    "image"
    "video"
    "audio"
    "pdf"
    "ebook"
    "archive"
    "word"
    "spreadsheet"
    "presentation"
    "email"
    "torrent"
    "terminal"
)


# ============================================================
# MENU INDEXES
#
#   0-14 = application categories
#   15   = View Current Defaults
#   16   = Apply All
#   17   = Cancel
# ============================================================

cursor=0
MENU_TOTAL=${#MENU_NAMES[@]}


# ============================================================
# MAIN LOOP
# ============================================================

while true; do

    clear

    echo
    echo -e \
        "${BOLD}${CYAN}╭────────────────────────────────────────────────────╮${RESET}"

    echo -e \
        "${BOLD}${CYAN}│          Default Applications Manager             │${RESET}"

    echo -e \
        "${BOLD}${CYAN}╰────────────────────────────────────────────────────╯${RESET}"

    echo

    echo -e \
        "${DIM}Your selections are pending. Nothing has been applied yet.${RESET}"

    echo


    # --------------------------------------------------------
    # Application categories
    # --------------------------------------------------------

    for ((i=0; i<MENU_TOTAL; i++)); do

        category="${MENU_KEYS[$i]}"
        title="${MENU_NAMES[$i]}"


        if [[ -n "${SELECTED_NAME[$category]:-}" ]]; then

            selected_text="${GREEN}${SELECTED_NAME[$category]}${RESET}"

        else

            selected_text="${DIM}Not selected${RESET}"

        fi


        if (( i == cursor )); then

            echo -e \
                "  ${GREEN}❯${RESET} ${BOLD}${title}${RESET}" \
                "  ${selected_text}"

        else

            printf "    %-30s " "$title"
            printf "%b\n" "$selected_text"

        fi

    done


    echo
    echo -e \
        "  ${DIM}────────────────────────────────────────────────────${RESET}"

    echo


    # --------------------------------------------------------
    # View Current Defaults
    # --------------------------------------------------------

    if (( cursor == 15 )); then

        echo -e \
            "  ${GREEN}❯${RESET} ${BOLD}🔍  View Current Defaults${RESET}"

    else

        echo \
            "    🔍  View Current Defaults"

    fi


    # --------------------------------------------------------
    # Apply All
    # --------------------------------------------------------

    if (( cursor == 16 )); then

        echo -e \
            "  ${GREEN}❯${RESET} ${BOLD}${GREEN}✓  Apply All${RESET}"

    else

        echo -e \
            "    ${GREEN}✓  Apply All${RESET}"

    fi


    # --------------------------------------------------------
    # Cancel
    # --------------------------------------------------------

    if (( cursor == 17 )); then

        echo -e \
            "  ${GREEN}❯${RESET} ${BOLD}${RED}✕  Cancel${RESET}"

    else

        echo -e \
            "    ${RED}✕  Cancel${RESET}"

    fi


    echo
    echo -e "${DIM}↑ ↓ Move   Enter Select${RESET}"


    # --------------------------------------------------------
    # Read keyboard input
    # --------------------------------------------------------

    IFS= read -rsn1 key


    case "$key" in

        # ====================================================
        # ESC / ARROW KEYS
        # ====================================================

        $'\x1b')

            IFS= read -rsn2 key 2>/dev/null || true


            case "$key" in

                '[A')
                    ((cursor--)) || true
                    ;;

                '[B')
                    ((cursor++)) || true
                    ;;

                '')
                    clear
                    exit 0
                    ;;

            esac

            ;;


        # ====================================================
        # ENTER
        # ====================================================

        '')

            if (( cursor < MENU_TOTAL )); then

                choose_app \
                    "${MENU_KEYS[$cursor]}" \
                    "${MENU_NAMES[$cursor]}"


            elif (( cursor == 15 )); then

                show_current_defaults


            elif (( cursor == 16 )); then

                apply_all


            elif (( cursor == 17 )); then

                clear

                echo
                echo -e \
                    "${RED}Cancelled. No changes were applied.${RESET}"

                echo

                exit 0

            fi

            ;;

    esac


    # ========================================================
    # WRAP NAVIGATION
    # ========================================================

    (( cursor < 0 )) && cursor=17

    (( cursor > 17 )) && cursor=0

done

