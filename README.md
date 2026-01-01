# Pixel Perfect Placement

**It does two things:**
1. Allows you to record exact tower locations in sandbox (or wherever) and then place the towers in the exact same location whenever you want.
2. It tells you when a super monkey tower is just out of range of another super monkey for pixel perfect temple placement.

## How to Use:
1. Download the AHK script for your resolution and save to a folder of your choosing
	a. 1920 x 1080 and 2560 x 1440 currently supported
2. Make sure your client is in windowed mode
3. Run script
4. Go ham

## Basic Controls:
Ctrl+B  : next slot\
Ctrl+N  : previous slot\
Ctrl+M  : move mouse to current slot\
Ctrl+S  : save current mouse position to current slot as SUPER (Included in temple range calcs)\
Ctrl+A  : save current mouse position to current slot as NORMAL (Not included in temple range calcs)\
Ctrl+W  : toggle current slot type (s <-> a)\
Ctrl+E  : delete current slot\

### Pixel nudges (overlay shows ONLY on these):
Ctrl+I/J/K/L : move 1 pixel\
Ctrl+Enter : click\

## Other:
F6 : show client size\
F7 : toggle slot list (top-left of client)\
Ctrl+Esc : exit\

## IMPORTANT Info:
1.	If Slot 1 is saved as SUPER it will act as your VTSG location (accounts for increased range when upgrading from sun temple to VTSG)
2.	The script can only read the slots file so you must add and delete slots as you add and delete monkey towers.

## Other Info:
1.	If you’re manually modifying your slots file yourself, abort the script first then reopen once changes are saved.
2.	Display scaling (control panel) needs to be 100%
