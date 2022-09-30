# Magicka2LUA
This is a framework for intercepting and loading customized LUA script files in Magicka 2.

## Installation
This framework sideloads a LUA interceptor by way of **[SimpleDLLLoader](https://github.com/aap/simpledllloader)**.

Install the following files to the  **\<Game Directory\>\Engine** path:

|File|Description|
|--|--|
|m2lua.dll|Magicka 2 LUA Hooking DLL|
|init.lua|Initial script called by LUA Hook
|dinput8.dll|SimpleDLLLoader|
|plugins.cfg|Defines DLLs Loaded by SimpleDLLLoader|

## Usage
This framework hooks and redirects the **loadbufferx** function call through the [init.lua](init.lua) script. This allows for intercepting and replacing script loading with customized LUA scripts. This process is demonstrated in the example that comes with this framework below:

```lua
replace("scripts/game/boot/boot_common","codebase/boot_common.lua")
replace("foundation/scripts/boot/foundation_setup","codebase/foundation_setup.lua")
```

Hook initialization and script loading is logged to the **lua.log** file created in the same folder as the [m2lua.dll](m2lua.dll). This log can be beneficial for identifying the scripts loaded by the game, which can then be used to generate a **murmur** hash to locate the corresponding LUA file within the game archives. Additionally, the files can be dumped to disk directly from within the initial LUA script as needed.

## Example
Included with the framework is an example modification that alters the original [boot_common.lua](codebase/boot_common.lua) and [foundation_setup.lua](codebase/foundation_setup.lua) to enable the **G_HACK_INGAME** flag and add additional code necessary to enable developer key(s) functionality.
