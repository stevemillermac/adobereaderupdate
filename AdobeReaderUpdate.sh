#!/bin/sh
#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#   AdobeReaderUpdate.sh -- Installs or updates Adobe Acrobat Reader DC
#
# SYNOPSIS
#   sudo AdobeReaderUpdate.sh
#
####################################################################################################
#
# HISTORY
#
#   Version: 1.4
#
#   - v.1.0 Joe Farage, 23.01.2015
#   - v.1.1 Joe Farage, 08.04.2015:	Support for new Adobe Acrobat Reader DC
#   - v.1.2 Steve Miller, 10.12.2015:	umount and other minor fixes
#   - v.1.3 Steve Miller, 16.12.2015:	Updated to copy echo commands into JSS policy logs
#   - v.1.4 Steve Miller, 21.12.2015:	Updated umount command to use hdiutil. 10.9 issues previous command
#
####################################################################################################
# Script to download and install Adobe Reader.
# Only works on Intel systems.


logfile="/Library/Logs/AdobeReaderDCUpdateScript.log"

# Are we running on Intel?
if [ '`/usr/bin/uname -p`'="i386" -o '`/usr/bin/uname -p`'="x86_64" ]; then
    ## Get OS version and adjust for use with the URL string
    OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )

    ## Set the User Agent string for use with curl
    userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"

    # Get the latest version of Reader available from Adobe's About Reader page.
    latestver=``
    while [ -z "$latestver" ]
    do
       latestver=`/usr/bin/curl -s -L -A "$userAgent" https://get.adobe.com/reader/ | grep "<strong>Version" | /usr/bin/sed -e 's/<[^>][^>]*>//g' | /usr/bin/awk '{print $2}' | cut -c 3-14`
    done

    echo "Latest Version is: $latestver"
    latestvernorm=`echo ${latestver}`
    # Get the version number of the currently-installed Adobe Reader, if any.
    if [ -e "/Applications/Adobe Acrobat Reader DC.app" ]; then
        currentinstalledver=`/usr/bin/defaults read /Applications/Adobe\ Acrobat\ Reader\ DC.app/Contents/Info.plist CFBundleShortVersionString`
        echo "Current installed version is: $currentinstalledver"
        if [ ${latestvernorm} = ${currentinstalledver} ]; then
            echo "Adobe Reader DC is current. Exiting"
            exit 0
        fi
    else
        currentinstalledver="none"
        echo "Adobe Reader DC is not installed"
    fi

    ARCurrVersNormalized=$( echo $latestver | sed -e 's/[.]//g' )
    dmgfile="AcroRdrDC_${ARCurrVersNormalized}_MUI.dmg"
    dmgmount="AcroRdrDC_${ARCurrVersNormalized}_MUI"
    mntpoint=`diskutil list | grep "AcroRdrDC" | awk '{print $6}' `

    echo "ARCurrVersNormalized: $ARCurrVersNormalized"
    url1="http://ardownload.adobe.com/pub/adobe/reader/mac/AcrobatDC/${ARCurrVersNormalized}/AcroRdrDC_${ARCurrVersNormalized}_MUI.dmg"
    url2=""

    #Build URL  
    url=`echo "${url1}${url2}"`
    echo "Latest version of the URL is: $url"


    # Compare the two versions, if they are different or Adobe Reader is not present then download and install the new version.
    if [ "${currentinstalledver}" != "${latestvernorm}" ]; then
        /bin/echo "`date`: Current Reader DC version: ${currentinstalledver}" >> ${logfile}
        /bin/echo "`date`: Available Reader DC version: ${latestver} => ${latestvernorm}" >> ${logfile}
        /bin/echo "`date`: Downloading newer version." >> ${logfile}
        /usr/bin/curl -s -o /tmp/${dmgfile} ${url}
        /bin/echo "`date`: Mounting installer disk image." >> ${logfile}
        /usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
        /bin/echo "`date`: Installing..." >> ${logfile}
        /usr/sbin/installer -pkg /Volumes/AcroRdrDC_${ARCurrVersNormalized}_MUI/AcroRdrDC_${ARCurrVersNormalized}_MUI.pkg -target / > /dev/null

        #Unmount DMG and delete tmp files
        /bin/sleep 10
        /bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
        mntpoint=`diskutil list | grep "AcroRdrDC" | awk '{print $6}' `
        /bin/echo The mount point is "$mntpoint"
        hdiutil unmount $mntpoint -force -quiet
        hdiutil detach $mntpoint -force -quiet
        /bin/sleep 10
        /bin/echo "`date`: Deleting disk image." >> ${logfile}
        /bin/rm /tmp/${dmgfile}

        #double check to see if the new version got updated
        newlyinstalledver=`/usr/bin/defaults read /Applications/Adobe\ Acrobat\ Reader\ DC.app/Contents/Info.plist CFBundleShortVersionString`
        if [ "${latestvernorm}" = "${newlyinstalledver}" ]; then
            /bin/echo "SUCCESS: Adobe Reader has been updated to version ${newlyinstalledver}"
            /bin/echo "`date`: SUCCESS: Adobe Reader has been updated to version ${newlyinstalledver}" >> ${logfile}
        else
            /bin/echo "ERROR: Adobe Reader update unsuccessful, version remains at ${currentinstalledver}."
            /bin/echo "`date`: ERROR: Adobe Reader update unsuccessful, version remains at ${currentinstalledver}." >> ${logfile}
            /bin/echo "--" >> ${logfile}
            exit 1
        fi

    # If Adobe Reader is up to date already, just log it and exit.       
    else
        /bin/echo "Adobe Reader is already up to date, running ${currentinstalledver}."
        /bin/echo "`date`: Adobe Reader is already up to date, running ${currentinstalledver}." >> ${logfile}
        /bin/echo "--" >> ${logfile}
    fi  
else
    /bin/echo "`date`: ERROR: This script is for Intel Macs only." >> ${logfile}
fi

exit 0
