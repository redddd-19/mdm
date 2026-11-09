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
    "Disable Notification (SIP)" 
    "Disable Notification (Recovery)" 
    "Check MDM Enrollment" 
    "Quit"
)

select opt in "${options[@]}"; do
    case $opt in
    "Bypass on Recovery")
        echo -e "${GREEN}Bypass on Recovery${NC}"
        
        # Check and rename the Data volume to avoid path whitespace issues
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
        
        # Block Apple Device Enrollment host endpoints
        echo "0.0.0.0 deviceenrollment.apple.com" >> "/Volumes/Macintosh HD/etc/hosts"
        echo "0.0.0.0 mdmenrollment.apple.com" >> "/Volumes/Macintosh HD/etc/hosts"
        echo "0.0.0.0 iprofiles.apple.com" >> "/Volumes/Macintosh HD/etc/hosts"
        echo -e "${GREEN}Successfully blocked MDM host domains.${NC}"
        
        # Mark Setup Assistant as complete
        touch /Volumes/Data/private/var/db/.AppleSetupDone
        
        # Clear activation records and create spoofed configuration flags
        rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord"
        rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
        touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
        touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound"
        
        echo "----------------------"
        break
        ;;

    "Disable Notification (SIP)")
        echo -e "${RED}Please enter your password to proceed:${NC}"
        sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
        sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
        sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
        sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
        echo -e "${GREEN}MDM enrollment notification flags cleared.${NC}"
        break
        ;;

    "Disable Notification (Recovery)")
        rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord"
        rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
        touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
        touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound"
        echo -e "${GREEN}Recovery MDM notification flags cleared.${NC}"
        break
        ;;

    "Check MDM Enrollment")
        echo ""
        echo -e "${GREEN}Checking MDM Enrollment (an error indicates no profile is active):${NC}"
        echo ""
        echo -e "${RED}Please enter your password to proceed:${NC}"
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
