# HiddenAuraLogger
A WoW AddOn that helps to detect and analyze hidden auras.

## General Notes

- The addon will automatically be logging at all times. You do not need to do anything to start it.
- Sometimes, visible auras will show up in this tool, but this will mainly happen for auras without Combat Log Events.

## Real-Time Aura Display

![image](https://user-images.githubusercontent.com/50294688/144536552-2dbd3a0b-c2e2-481c-95fb-9adc3901e1ac.png)

- Type `/hal ui` to show the Aura UI.
- This will show any detected hidden auras on your character with their stack count and remaining duration.
- Green borders indicate an aura that was recently added to your character.
- Red borders indicate that the aura was recently removed.
- You can mouse over any aura to get the tooltip for it, which may or may not be useful.

## Logs

### Viewing Logs

![image](https://user-images.githubusercontent.com/50294688/144536749-0cafca44-fe72-4218-a7e2-c2dee4158906.png)

- Type `/hal logs` to open the log viewer.
- Simply select a log on the left to open it and view hidden aura events.

### Exporting Logs

![image](https://user-images.githubusercontent.com/50294688/144536895-dfc5d24d-3055-4eea-b869-202019e32c32.png)

- The "Export Single" button will open an export frame with text to copy for the specific log you have selected.
- The "Export Matching" button will open an export frame with text to copy for all logs with the same encounter and game version as the one you have selected. This is for mass exporting all of the logs for a boss and was specifically designed for PTR raid testing.

### Deleting Logs
- You can type `/hal clear` to delete all logs. Currently, there isn't a way to delete individual logs through the addon.

## Settings

![image](https://user-images.githubusercontent.com/50294688/144536477-765a73c5-f900-44d2-997e-abd8ff819bc1.png)

- Navigate to the Addon settings or type `/hal` to open the settings.
- The "Maximum Milliseconds per Frame" option is used to prevent the addon from using too much CPU. The default of 3 ms is not noticeable in raids for me, but you may wish to set this lower if you're lagging.
- When used to look for hidden auras in specific content, the spell ID range that is searched can be constricted to reduce the amount of time needed to detect a new aura.
