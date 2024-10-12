#!/bin/zsh

enableAirDropPF() {
    /usr/bin/logger "ADA: Enabling PF ADA Anchors"
    echo 'anchor "ada_anchor"' >> /etc/pf.conf
    echo 'load anchor "ada_anchor" from "/etc/pf.anchors/ada_anchor"' >> /etc/pf.conf
    /sbin/pfctl -e 2> /dev/null
    /sbin/pfctl -f /etc/pf.conf 2> /dev/null

    if [[ ! -f "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist" ]]; then
        /usr/bin/logger "ADA: Creating ADA PF LaunchDaemon"
        /bin/cp "/System/Library/LaunchDaemons/com.apple.pfctl.plist" "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist" 2> /dev/null
        /usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string -e" "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist" 2> /dev/null
        /usr/libexec/PlistBuddy -c "Set :Label ada.pfctl" "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist" 2> /dev/null
        /bin/launchctl enable system/ada.pfctl 2> /dev/null
        /bin/launchctl bootstrap system "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist" 2> /dev/null
    fi
        
}

disableAirDropPF() {
    /usr/bin/logger "ADA: Disabling and Removing ADA PF Anchors"
    /bin/rm /etc/pf.anchors/ada_anchor
    /usr/bin/sed -i '' '/anchor "ada_anchor"/d' /etc/pf.conf
    /usr/bin/sed -i '' '/load anchor "ada_anchor" from "\/etc\/pf.anchors\/ada_anchor"/d' /etc/pf.conf
    /sbin/pfctl -e 2> /dev/null
    /sbin/pfctl -f /etc/pf.conf 2> /dev/null
    /bin/launchctl disable system/mscp.pfctl 2> /dev/null
    /bin/launchctl bootout system "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist" 2> /dev/null
    /bin/rm -rf "/Library/LaunchDaemons/com.ttinc.Air-Drop-Assistant.pfctl.plist"
    /usr/bin/defaults write "/Library/Preferences/com.ttinc.Air-Drop-Assistant.plist" ADA_PF "off"
}

disableOutgoing() {
    /usr/bin/logger "ADA: Creating disable outgoing ada_anchor"
    echo "block out proto tcp to port 8770" > /etc/pf.anchors/ada_anchor
    /usr/bin/defaults write "/Library/Preferences/com.ttinc.Air-Drop-Assistant.plist" ADA_PF "DisableOut"
    enableAirDropPF
}

disableInComing() {
    /usr/bin/logger "ADA: Creating disable incoming ada_anchor"
    echo "block in proto tcp to port 8770" > /etc/pf.anchors/ada_anchor
    /usr/bin/defaults write "/Library/Preferences/com.ttinc.Air-Drop-Assistant.plist" ADA_PF "DisableIn"
    enableAirDropPF
}

/usr/bin/logger "ADA: PF Helper Script Launched"
if [[ $EUID -ne 0 ]]; then
    /usr/bin/logger "ADA: Prompting for Admin Privs"
    /usr/bin/logger "ADA: $0 $1"
    # /usr/bin/osascript -e "do shell script \"$0 $1\" with administrator privileges"
    /usr/bin/osascript -e 'on run {commandName, commandArgument}' -e 'do shell script ((quoted form of commandName) & " " & (quoted form of commandArgument)) without altering line endings with administrator privileges with prompt "Air Drop Assistant would like permission to change system level settings."' -e 'end run' -- "$0" "$1"
    exit 0
fi

zparseopts -blockOut=blockOut -blockIn=blockIn -remove=disableAirDropPF

if [[ $blockOut ]] || [[ $blockIn ]] || [[ $disableAirDropPF ]]; then
    if [[ $blockOut ]]; then 
        disableOutgoing
    fi
    if [[ $blockIn ]]; then 
        disableInComing
    fi
    if [[ $disableAirDropPF ]]; then 
        disableAirDropPF
    fi
fi
