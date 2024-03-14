# Piper-TTS-Manager-for-X-Plane

Piper TTS Manager is an adaption of the [MaryTTS Manager](https://github.com/JT8D-17/MaryTTS-Manager-for-X-Plane) utility for the [FlyWithLua](https://github.com/X-Friese/FlyWithLua) plugin for [X-Plane 11/12](https://www.x-plane.com/) to the [Piper TTS](https://github.com/rhasspy/piper). Compared to MaryTTS Manager, the codebase has been slicked and cleaned up.

&nbsp;

<a name="toc"></a>
## Table of Contents
1. [Compatibility and Requirements](#requirements)
2. [Installation](#install)
3. [Uninstallation](#uninstall)
4. [Functionality](#functionality)
5. [Usage](#Usage)
6. [Known Issues](#issues)
7. [License](#license)

&nbsp;

<a name="requirements"></a>
## 1 - Compatibility and Requirements

**Compatibility:**

Linux: Development platform; extensively tested   
Windows 10: Works, but has only been tested a little   
MacOS/OSX: Unknown due to a lack of willing and able testers

**Requirements:**

- All: [X-Plane 11](https://www.x-plane.com/) (version 11.50 or higher)
- All: [FlyWithLuaNG](https://forums.x-plane.org/index.php?/files/file/38445-flywithlua-ng-next-generation-edition-for-x-plane-11-win-lin-mac/) (version 2.7.28 or higher)
- Linux: System packages providing the _curl_, _kill_, _ls_ and _pgrep_ commands
- Windows: Any version that provides the _curl_, _dir_, _start_,  _taskkill_ and _tasklist_ commands (Windows 10 or newer)

**Please check and confirm that your system fulfills the operating system specific requirements before installing MTTSM!**

[Back to table of contents](#toc)

&nbsp;

<a name="install"></a>
## 2 - Installation

- Click "Code" --> "Download ZIP" or use [this link](https://github.com/JT8D-17/Piper-TTS-Manager-for-X-Plane/archive/refs/heads/main.zip).
- Unzip the archive and copy the "Scripts" and "Modules" folders into _"X-Plane 11/Resources/plugins/FlyWithLua/"_


[Back to table of contents](#toc)

&nbsp;

<a name="uninstall"></a>
## 3 - Uninstallation

- Delete _PiperTTSManager.lua_ from _"X-Plane [11/12]/Resources/plugins/FlyWithLua/Scripts"_
- Delete _"PiperTTSManager"_ from _"X-Plane [11/12]/Resources/plugins/FlyWithLua/Modules"_


[Back to table of contents](#toc)

&nbsp;

<a name="functionality"></a>
## 4 - Functionality

**4.1 - Purpose**

Piper TTS Manager is an interface and wrapper to call Piper TTS to generate an output audio file that can be played back. It is basically a bridge between an X-Plane plugin (or FlyWithLua or XLua or SASL script) and a local Piper TTS installation.

It was developed for use with the _SimpleATC_ module of [X-ATC-Chatter](https://www.stickandrudderstudios.com/x-atc-chatter-project/) in close cooperation with [Stick and Rudder studios](https://www.stickandrudderstudios.com/) to provide multiple pilot and controller voices.

&nbsp;

**4.2 - Interfaces**

The bridging between plugin and Piper TTS is defined in interface files that can be created and edited directly in PTTSM's user interface in X-Plane. These interfaces define various aspects like input text file location, output WAV file location and optional voice mapping to assign a specific voice to a specific actor. Interface file structure is fixed and the user interface exposes all the required inputs for plugin or script developers.

&nbsp;

**4.3 - Input processing**

The core element is a watchdog loop that runs in one second intervals and monitors a text input file. If a string is written to said input file, PTTSM will read it from file, split it into actor and string to be spoken based on a delimiter defined in the interface file.   
The actor is then further matched to a present Piper TTS voice by means of a voice mappping defined in the interface file or - if none is found - by a random voice selection. There is a small degree of memory for actors, so that e.g. an ATC ground controller will have a consistent voice for all interactions until a switchover to another actor (e.g. ATC tower controller), at which point another (unmapped) voice is randomly chosen.   
Piper TTS is then called with the voice and string to be spoken to output a WAV file to a location specified in the interface file.
Playback of the output WAV file is either done by the plugin itself or by FlyWithLua. After playback, the WAV file is deleted.

[Back to table of contents](#toc)

&nbsp;

<a name="Usage"></a>
## 5 - Usage

Call the PTTSM user interface...
...from X-Plane's _"Plugins"_ menu with  _"PiperTTS Manager"_ --> _"Open Window"_    
or    
...from the FlyWithLua menu with _"FlyWithLua"_ --> _"FlyWithLua Macros"_ --> _"PiperTTS Manager: Toggle Window"_    
or    
...by assigning a keyboard shortcut to _"PiperTTS Manager/Window/Toggle Window"_ in X-Plane's keyboard settings window.

General hints:   
**Most, if not all, items have tooltips!**    
After having typed a value into any text/number input box, click anywhere in PTTSM's window to leave it, otherwise it will keep focus, eating up all keyboard inputs (see "Known Issues" section below).   
Undesired values in text/number input boxes that were just entered can be discarded  by pressing the "ESC" key.  
Window visibility, size and position are automatically saved when exiting X-Plane.

&nbsp;

**5.1 - UI: Interface selector**

The interface selector lists all the available MTTSM interfaces found in `FlyWithLua/Modules/PiperTTSManager/Interfaces` at script startup. Pressing the _"Rescan"_ button rescans that folder and rebuilds the list of available interfaces.   
**Selecting an interface is only necessary for reviewing its settings or for editing it. All plugin interfaces stored in the interface folder are automatically processed at X-Plane session start and continuously monitored as long as X-Plane is running!**

&nbsp;

**5.2 - UI: Interface settings (non-edit mode)**

This is a multifunction menu which displays various interface information and interaction settings.    
All changes made to the text input and selector boxes **only apply until the next interface rescan or script reload**. For permanent changes to an interface, use "Edit" mode (see below).     
Text input boxes additionally will lose any changes unless in "Edit" mode.

&nbsp;

**5.3 - UI: Interface settings (edit mode)**

The edit mode for the interface can be enabled with the _"Enable Edit Mode"_ button. Picking _"Create New Interface"_ from the interface selector will automatically enter edit mode.   
**When in edit mode, the watchdog that scans for input text files for text-to-speech processing is disabled.**   
Changes made in edit mode may be saved to the interface configuration file (existing or new) by pressing the _"Save Interface Configuration File"_ button.   
Disabling edit mode for an existing interface after having made changes will retain these new values until the _"Rescan"_ button next to the interface selector is pressed. This will trigger a complete reload of all available interfaces.

&nbsp;

**5.4 - UI: Testing area**

This interface element is **only visible when the _"None/Testing"_ interface is selected**.   
The main purpose of this element is to provide a quick method to check that PTTSM is working properly.   
Enter a string that should be spoken, pick a voice and hit the _"Speak"_ button. You should hear the spoken string a few seconds later.
 
 &nbsp;

**5.5 - Settings File**

The path to PTTSM's settings file is: `FlyWithLua/Modules/PiperTTSManager/settings.cfg`. You can edit or delete it when X-Plane is not running.

&nbsp;

**5.6 - Log**

PTTSM writes its log to: `FlyWithLua/Modules/PiperTTSManager/PTTSM_Log.txt`. The log is regenerated at every script start.

[Back to table of contents](#toc)

&nbsp;

<a name="issues"></a>
## 7 - Known issues

- There is a slight delay between sending a string to the server and hearing it due to the required processing from text to speech.
- Voice quality may be too low for some people, but this is as good as it gets with MaryTTS.
- MaryTTS still has bugs, especially with [strings with apostrophes](https://github.com/marytts/marytts/issues/817). MTTSM attempts to expand such strings (e.g. "you're" --> "you are") but naturally can't catch all of them (see *MTTSM_PhoneticCorrections* in *Modules/MaryTTSManager/Lua/MTTSM_Main.lua*), so it's best to avoid contractions where possible.
- Text input boxes will not automatically unfocus. Click anywhere inside the UI to unfocus them.
- Checking for the server process may produce system stutters, especially on Windows
- Checking for an input file or playing back an output wave file may slightly degrade simulator performance


[Back to table of contents](#toc)

&nbsp;

<a name="license"></a>
## 8 - License

MaryTTS Manager is licensed under the European Union Public License v1.2 (see _EUPL-1.2-license.txt_). Compatible licenses (e.g. GPLv3) are listed  in the section "Appendix" in the license file.

[MaryTTS license](https://github.com/marytts/marytts/blob/master/LICENSE.md)

[Adoptium license](https://adoptium.net/docs/faq/)
