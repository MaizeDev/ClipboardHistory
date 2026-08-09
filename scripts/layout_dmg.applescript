on run arguments
    set volumeName to item 1 of arguments
    set mountedVolumePath to item 2 of arguments
    set backgroundPicture to POSIX file (mountedVolumePath & "/.background/background.png") as alias

    tell application "Finder"
        tell disk volumeName
            open

            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set pathbar visible to false
                set bounds to {120, 120, 780, 540}
            end tell

            set viewOptions to icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 128
            set text size of viewOptions to 14
            set label position of viewOptions to bottom
            set background picture of viewOptions to backgroundPicture

            set position of item "ClipboardHistory.app" to {170, 190}
            set position of item "Applications" to {490, 190}

            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
