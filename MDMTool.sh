#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "Auto Tools for macOS"
echo ""

PS3='Please enter your choice: '
options=(
    "Bypass on Recovery"
    "Disable Notification (Recovery)"
    "Check MDM Enrollment"
    "Quit"
)

DOMAINS=(
    "iprofiles.apple.com"
    "mdmenrollment.apple.com"
    "deviceenrollment.apple.com"
    "albert.apple.com"
    "gdmf.apple.com"
    "axm-adm-enroll.apple.com"
    "axm-adm-mdm.apple.com"
    "axm-adm-scep.apple.com"
    "configuration.apple.com"
)

clear_recovery_flags() {
    local settings_dir="$1"
    if [ -d "$settings_dir" ]; then
        rm -f "$settings_dir/.cloudConfigHasActivationRecord" \
              "$settings_dir/.cloudConfigRecordFound" \
              "$settings_dir/.cloudConfigTimerCheck" \
              "$settings_dir/com.apple.mdm.depnag.plist"
        touch "$settings_dir/.cloudConfigProfileInstalled" \
              "$settings_dir/.cloudConfigRecordNotFound"
        echo -e "${GREEN}Cleared activation records in $settings_dir${NC}"
    fi
}

select opt in "${options[@]}"; do
    case $opt in
    "Bypass on Recovery")
        echo -e "${GREEN}Bypass on Recovery${NC}"

        # Rename Data volume to avoid whitespace issues
        if [ -d "/Volumes/Macintosh HD - Data" ]; then
            diskutil rename "Macintosh HD - Data" "Data"
        fi

        echo -e "${GREEN}Create New User Account${NC}"
        echo -e "${BLUE}Press Enter to proceed; empty inputs will use the default values.${NC}"

        echo -e "Enter Full Name (Default: MAC):"
        read realName
        realName="${realName:=MAC}"

        echo -e "${BLUE}Enter Username ${RED}(NO SPACES OR ACCENTS)${GREEN} (Default: MAC):${NC}"
        read username
        username="${username:=MAC}"

        echo -e "${BLUE}Enter Password (Default: 1234):${NC}"
        read passw
        passw="${passw:=1234}"

        dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
        echo -e "${GREEN}Creating user account...${NC}"

        # Create user via OpenDirectory
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"

        # Create Home Directory
        mkdir -p "/Volumes/Data/Users/$username"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"

        # Set Password and assign Admin rights
        dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
        dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

        # Block Apple Device Enrollment & Activation endpoints (IPv4 & IPv6)
        HOSTS_TARGET="/Volumes/Macintosh HD/etc/hosts"
        {
            echo ""
            echo "# >>> MDM & ACTIVATION BLOCKS >>>"
            for domain in "${DOMAINS[@]}"; do
                echo "0.0.0.0 $domain"
            done
            for domain in "${DOMAINS[@]}"; do
                echo ":: $domain"
            done
            echo "# <<< MDM & ACTIVATION BLOCKS <<<"
        } >> "$HOSTS_TARGET"
        echo -e "${GREEN}Successfully blocked IPv4 and IPv6 MDM host domains.${NC}"

        # Mark Setup Assistant as complete
        touch /Volumes/Data/private/var/db/.AppleSetupDone

        # Clear activation records on the writable Data volume
        clear_recovery_flags "/Volumes/Data/private/var/db/ConfigurationProfiles/Settings"

        # Write executable mdm_shield.sh into /Users/Shared so it survives temporary user deletion
        mkdir -p "/Volumes/Data/Users/Shared"
        cat << 'SHIELD_EOF' > "/Volumes/Data/Users/Shared/mdm_shield.sh"
#!/bin/bash
set -euo pipefail

# Ensure root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Elevating to root..."
    exec sudo "$0" "$@"
fi

# Resolve target console user UID (falls back to 502 if run over SSH/non-GUI)
CONSOLE_USER=$(stat -f "%Su" /dev/console)
TARGET_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "${SUDO_UID:-502}")

HOSTS_FILE="/etc/hosts"
MARKER_BEGIN="# >>> MDM & ACTIVATION BLOCKS >>>"
MARKER_END="# <<< MDM & ACTIVATION BLOCKS <<<"

DOMAINS=(
    "iprofiles.apple.com"
    "mdmenrollment.apple.com"
    "deviceenrollment.apple.com"
    "albert.apple.com"
    "gdmf.apple.com"
    "axm-adm-enroll.apple.com"
    "axm-adm-mdm.apple.com"
    "axm-adm-scep.apple.com"
    "configuration.apple.com"
)

SYSTEM_SERVICES=(
    "system/com.apple.ManagedClient.enroll"
    "system/com.apple.ManagedClient.cloudconfigurationd"
)

GUI_SERVICES=(
    "gui/${TARGET_UID}/com.apple.ManagedClientAgent.agent"
    "gui/${TARGET_UID}/com.apple.ManagedClientAgent.enrollagent"
)

echo "=== 1. Updating /etc/hosts (IPv4 & IPv6) ==="
TMP_HOSTS=$(mktemp)
awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
' "$HOSTS_FILE" > "$TMP_HOSTS"

sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$TMP_HOSTS" 2>/dev/null || true

{
    echo ""
    echo "$MARKER_BEGIN"
    echo "# IPv4 Loopback Blocks"
    for domain in "${DOMAINS[@]}"; do
        echo "0.0.0.0 $domain"
    done
    echo ""
    echo "# IPv6 Loopback Blocks"
    for domain in "${DOMAINS[@]}"; do
        echo ":: $domain"
    done
    echo "$MARKER_END"
} >> "$TMP_HOSTS"

cat "$TMP_HOSTS" > "$HOSTS_FILE"
chmod 644 "$HOSTS_FILE"
chown root:wheel "$HOSTS_FILE"
rm -f "$TMP_HOSTS"
echo "Hosts file updated cleanly."

echo ""
echo "=== 2. Flushing DNS Cache ==="
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
echo "DNS resolver cache flushed."

echo ""
echo "=== 3. Disabling System MDM Daemons ==="
for svc in "${SYSTEM_SERVICES[@]}"; do
    launchctl disable "$svc" 2>/dev/null || true
    echo "Disabled: $svc"
done

echo ""
echo "=== 4. Disabling GUI Nag Agents (UID: $TARGET_UID) ==="
for svc in "${GUI_SERVICES[@]}"; do
    launchctl disable "$svc" 2>/dev/null || true
    echo "Disabled: $svc"
done

killall followupd 2>/dev/null || true

echo ""
echo "=== 5. Verification Audit ==="
echo "[DNS Resolution Check - albert.apple.com]"
dscacheutil -q host -a name albert.apple.com | grep -E "ip_address|ipv6_address" || echo "WARNING: DNS check returned empty"

echo ""
echo "[Disabled System Daemons]"
launchctl print-disabled system | grep -E "ManagedClient|cloudconfigurationd" || echo "WARNING: System overrides not found"

echo ""
echo "[Disabled GUI Agents (UID $TARGET_UID)]"
launchctl print-disabled "gui/${TARGET_UID}" | grep -E "ManagedClient" || echo "WARNING: GUI overrides not found"

echo ""
echo "[System Status]"
csrutil status
profiles status -type enrollment 2>/dev/null || true
echo "Done."
SHIELD_EOF

        chmod 755 "/Volumes/Data/Users/Shared/mdm_shield.sh"
        chown root:wheel "/Volumes/Data/Users/Shared/mdm_shield.sh"
        echo -e "${GREEN}Created executable /Users/Shared/mdm_shield.sh on the Data volume.${NC}"

        echo "----------------------"
        echo -e "${BLUE}Next steps after reboot:${NC}"
        echo -e "${BLUE}1. Create your permanent Admin account in System Settings, reboot into it, and delete the temporary account.${NC}"
        echo -e "${BLUE}2. Run: cp /Users/Shared/mdm_shield.sh ~/mdm_shield.sh && ~/mdm_shield.sh${NC}"
        break
        ;;

    "Disable Notification (Recovery)")
        if [ -d "/Volumes/Macintosh HD - Data" ]; then
            clear_recovery_flags "/Volumes/Macintosh HD - Data/private/var/db/ConfigurationProfiles/Settings"
        elif [ -d "/Volumes/Data" ]; then
            clear_recovery_flags "/Volumes/Data/private/var/db/ConfigurationProfiles/Settings"
        else
            echo -e "${RED}Data volume not found under /Volumes.${NC}"
        fi
        break
        ;;

    "Check MDM Enrollment")
        echo ""
        echo -e "${GREEN}Checking MDM Enrollment (an error indicates no profile is active):${NC}"
        echo ""
        sudo profiles show -type enrollment
        break
        ;;

    "Quit")
        echo "Exiting."
        break
        ;;

    *)
        echo "Invalid option: $REPLY"
        ;;
    esac
done
