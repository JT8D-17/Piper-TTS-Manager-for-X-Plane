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

- Confirmed working on Arch Linux, Fedora 39, Ubuntu 22.04, Windows 11 and MacOS so far.
- Does not support X-Plane's Steam release!
- X-Plane 11 is untested.
- Windows only: A console window will quickly pop up and close, momentarily taking focus from X-Plane when in full screen mode. This is Windows default behavior which I've tried for hours to work around with all kinds of command and PowerShell voodoo and failed miserably. For [SimpleATC](https://www.stickandrudderstudios.com/x-atc-chatter-project/) usage, it is recommended to simply use the default Windows SpeechAPI voices instead (see X-ATC-Chatter user guide).
- Also see "[Known Issues](#issues)" below.

**Requirements:**

- [X-Plane](https://www.x-plane.com/), version 11.50, 12.00 or newer)
- FlyWithLua:
  - X-Plane 11: [FlyWithLuaNG](https://forums.x-plane.org/index.php?/files/file/38445-flywithlua-ng-next-generation-edition-for-x-plane-11-win-lin-mac/) (version 2.7.28 or higher)
  - X-plane 12: [FlyWithLuaNG+](https://forums.x-plane.org/index.php?/files/file/82888-flywithlua-ng-next-generation-plus-edition-for-x-plane-12-win-lin-mac/) (version 2.8.1 or higher)


[Back to table of contents](#toc)

&nbsp;

<a name="install"></a>
## 2 - Installation

Because of the file sizes involved, PiperTTS Manager is dfelivered as a self-assmbly kit.   
All paths are relative to the X-Plane 11/12 main installation folder.

- Click "Code" --> "Download ZIP" or use [this link](https://github.com/JT8D-17/Piper-TTS-Manager-for-X-Plane/archive/refs/heads/main.zip).
- Unzip the archive and copy the "Scripts" and "Modules" folders into _"X-Plane 11/Resources/plugins/FlyWithLua/"_
- Download Piper's latest release for your operating system from [this Piper TTS fork](https://github.com/TheLouisHong/piper/releases):
  - Linux x86-64: _piper_linux_x86_64.tar.gz_
  - Windows: _piper_windows_amd64.zip_
  - Mac M1/2/3: _piper_macos_aarch64.tar.gz_
  - Mac (other): _piper_macos_x64.tar.gz_
- Unzip the downloaded file
- Move the content of the unzipped _"piper"_ folder (not the folder itself!) to:
  - **Linux:** "Resources/plugins/FlyWithLua/Modules/PiperTTSManager/Resources/Piper_LIN"
  - **Windows:** "Resources/plugins/FlyWithLua/Modules/PiperTTSManager/Resources/Piper_WIN"
  - **Mac:** "Resources/plugins/FlyWithLua/Modules/PiperTTSManager/Resources/Piper_MAC"
- Go to the [PiperTTS voice repository](https://huggingface.co/rhasspy/piper-voices/tree/main)
- Pick any voice(s) you want from the "en" folder (at least download "en/en_US/lessac/medium" because the SimpleATC interface is preconfigured for it)
- The download and installation steps for each voice you pick are the same.
- In the folder of the voice in the repository, download the **.onnx** and **.onnx.json** files (download icon to the right of the file name)
- **After the download, the onnx.json file may need to be renamed. It must(!) have the same(!!) filename as the voice, just with an .onnx.json extension (e.g. _en_US-lessac-medium.onnx_ and _en_US-lessac-medium.onnx.json_)!**
- Move both voice files into _"Resources/plugins/FlyWithLua/Modules/PiperTTSManager/Resources/piper_voices"_.
- Repeat for any desired voice. (Note that PTTSM does not support subfolders in "piper_voices".)

[Back to table of contents](#toc)

&nbsp;

<a name="uninstall"></a>
## 3 - Uninstallation

All paths are relative to the X-Plane 11/12 main installation folder.

- Delete _PiperTTSManager.lua_ from _"Resources/plugins/FlyWithLua/Scripts"_
- Delete _"PiperTTSManager"_ from _"Resources/plugins/FlyWithLua/Modules"_


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
- **Most, if not all, items have tooltips!**    
- After having typed a value into any text/number input box, click anywhere in PTTSM's window to leave it, otherwise it will keep focus, eating up all keyboard inputs (see "Known Issues" section below).
- Undesired values in text/number input boxes that were just entered can be discarded  by pressing the "ESC" key.
- Window visibility, size and position are automatically saved when exiting X-Plane.

All paths stated below are relative to the FlyWithLua installation folder within X-Plane's installation folder.

&nbsp;

**5.1 - UI: Interface selector**

The interface selector lists all the available MTTSM interfaces found in _"FlyWithLua/Modules/PiperTTSManager/Interfaces"_ at script startup. Pressing the _"Rescan"_ button rescans that folder and rebuilds the list of available interfaces.   
**Selecting an interface is only necessary for reviewing its settings or for editing it. All plugin interfaces stored in the interface folder are automatically processed at X-Plane session start and continuously monitored as long as X-Plane is running!**

&nbsp;

**5.2 - UI: Interface settings (non-edit mode)**

This is a multifunction menu which displays various interface information and interaction settings.    
All changes made to the text input and selector boxes **only apply until the next interface rescan or script reload**. For permanent changes to an interface, use "Edit" mode (see below).     
Text input boxes additionally will lose any changes unless in "Edit" mode.

&nbsp;

**5.3 - UI: Interface settings (edit mode)**

The edit mode for the interface can be enabled with the "Enable Edit Mode" button. Picking "Create New Interface" from the interface selector will automatically enter edit mode.   
**When in edit mode, the watchdog that scans for input text files for text-to-speech processing is disabled.**   
Changes made in edit mode may be saved to the interface configuration file (existing or new) by pressing the "Save Interface Configuration File" button.   
Disabling edit mode for an existing interface after having made changes will retain these new values until the "Rescan" button next to the interface selector is pressed. This will trigger a complete reload of all available interfaces.

&nbsp;

**5.4 - UI: Testing area**

This interface element is **only visible when the _"None/Testing"_ interface is selected**.   
The main purpose of this element is to provide a quick method to check that PTTSM is working properly.   
Enter a string that should be spoken, pick a voice and hit the _"Speak"_ button. You should hear the spoken string a few seconds later.
 
 &nbsp;

**5.5 - Settings File**

The path to PTTSM's settings file is: _"FlyWithLua/Modules/PiperTTSManager/settings.cfg"_. You can edit or delete it when X-Plane is not running.

&nbsp;

**5.6 - Log**

PTTSM writes its log to: _"FlyWithLua/Modules/PiperTTSManager/PTTSM_Log.txt"_. The log is regenerated at every script start.

[Back to table of contents](#toc)

&nbsp;

<a name="issues"></a>
## 6 - Known issues

- There is a delay between sending a string to the server and hearing it due to the required processing from text to speech.
- There may be a short stutter in X-Plane while an output audio file is generated.
- Voice quality may be too low for some people, but this is as good as it gets with MaryTTS.
- Text input boxes will not automatically unfocus. Click anywhere inside the UI to unfocus them.
- Checking for an input file or playing back an output wave file may slightly degrade simulator performance.

[Back to table of contents](#toc)

&nbsp;

<a name="license"></a>
## 7 - License

Piper TTS Manager is licensed under the European Union Public License v1.2 (see _EUPL-1.2-license.txt_). Compatible licenses (e.g. GPLv3) are listed  in the section "Appendix" in the license file.

[Back to table of contents](#toc)
