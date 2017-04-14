#!/bin/bash

set -u

OUTPUT_FILE="/etc/X11/xorg.conf.d/09-multigpu.conf"
SNIPPETS_FILE="/etc/multigpu.snippets"
ENUMERATE_UNIQUE_CARDS=0 # Enumeration not yet implemented
REVERSE_CARD_ORDER=1 # Reverse the order in which devices appear. Hacky.
ACTION=${1-}

function get_config_snippet() {
    to_match="$@"
    while IFS= read line; do
        if [[ "$line" =~ ^[[:space:]]+ ]]; then
            # This is a config option
            if [ ! -z "$print_config" ]; then
                echo "$line"
            fi
        else
            # This is a new device section
            if [[ "$to_match" =~ $line ]]; then
                print_config=something
            else
                print_config=""
            fi
        fi
    done < "$SNIPPETS_FILE"
}

function generate_config() {
    pci_id=$(echo $1 | sed 's/\./:/')
    shift
    device_string="$@"
    echo # newline
    echo "Section \"Device\""
    echo "    BusID       \"PCI:${pci_id}\""
    get_config_snippet $device_string
    echo "EndSection"
}

function global_config() {
cat << EOF
Section "ServerFlags"
    Option  "AutoAddGPU" "off"
EndSection
EOF
}

function main() {
    case $ACTION in
        noop)
            OUTPUT_FILE=/dev/stdout
            ;;
        uninstall)
            rm -v "$OUTPUT_FILE"
            ;;
        install|reinstall)
            :
            ;;
        *)
            echo "Please provide an option."
            ;;
    esac
    : > "$OUTPUT_FILE"
    global_config >> "$OUTPUT_FILE"
    cards="$(lspci | grep -E '^[0-9:.]+ VGA compatible controller')"
    if (($REVERSE_CARD_ORDER)); then
        cards=$(echo "$cards" | tac)
    fi
    echo "$cards" | while read card; do
        generate_config $card >> "$OUTPUT_FILE"
    done
}

main
