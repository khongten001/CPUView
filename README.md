Advanced CPU-View for Lazarus.
================

Attention - BETA, version!!!

``` 
As of January 17, 2025, daily CPU-View updates have been suspended.  

All core functionality has been added, only 4 steps remain,  
each of which will require a long development time and will not be  
posted so as not to break the current CPU-View behavior.  

1. SIMD register editor. (DONE)
2. Window displaying function call parameters.
3. Carbon/Cocoa widget support under macOS.
4. Support for ARM architecture.
```

### Setup and use: 
1. Download FWHexView https://github.com/AlexanderBagel/FWHexView and compile FWHexView.LCL.lpk
2. Open CPUView_win_x86_64_D.lpk (or CPUView_lin_x86_64_D.lpk for Linux) and install it in the IDE (menu: Package->Install/Uninstall Packages) 
3. Rebuild IDE
4. In debug mode select menu "View->Debug Windows->CPU-View" or press Ctrl+Shift+C
5. Enjoy  

If you want to make changes to the Cpu-View dialogs, you must also install the FWHexView_D.LCL.lpk package

### Debug Log and Crash Dump:
The debug log is stored in the following path: “lazarus_path\config_lazarus\cpuview\debug.log”.  
It is created when the CPU-View dialog is first opened, and contains all logs added during the session (i.e. until Lazarus is finally closed).  
The previous session's log is deleted on startup, so if an error occurs, you should save the log file for later analysis.  
If an exception occurs, CallStack is saved to the current log.  
  
You can disable logging or crash dump collection in the settings "Tools->Options->Environment->CPU-View".  
![](https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/settings.png)

### Five active editors:
1. Disassembler
2. Registers
3. Dump
4. Stack
5. Script and Hint
6. Utils

### Common features:
* OS: Windows and Linux support via Gtk2 or Qt5
* Proc: Intel x86_64 (ARM not yet implemented)
* Thread context (Basic, x87 and SIMD register) full support on Windows and Linux
* Light and dark display themes
* Crosscompiling support
* Supports thread switching with instantaneous change of displayed information about the active thread
* Command to jump the selected address in any of the windows
* Bidirectional jump stack in each editor
* Active tooltips for each editor

### The disassembler window supports:
* Output debugging information
* Jump direction display
* Active jump highlighting
* Highlighting of the selected register
* Displays the names of called functions instead of their addresses
* Offsets (double-click on the address column)
* Hinting on the selected instruction with a menu to jump to each block of the received information
* Instruction coloring for easy code reading
* Breakpoints (display and modify)
* Display the disassembler for each jump in the tooltip

### Register window:
* Contains debugging information for each register (RAX..R15)
* Display SIMD registers (XMM and YMM) with 12 display mode
* Three display modes for x87 registers (ST-R-M)
* Bitwise representation of EFLAGS, TagWord, StatusWord, ControlWord, MxCsr flag registers (include decoded TagWord on x64)
* Change ALL register value and fast flag switching
* Two display modes (full and compact)
* Quick hint on active jump instructions
* LastError and LastStatus code with description (Windows only)
* Highlight of changed registers
* Highlighting and hinting to validated addresses
* Hints for some registers and flags from external database

### Stack supports:
* Debug information
* Active and previous frames highlighting
* Return address highlighting
* Offsets (double-click on the address column)
* Selections of duplicates
* Highlighting and hinting to validated addresses

### Dump supports:
* Multiple dump windows
* 17 display mode (include Long Double 80 bit)
* 6 text encoding mode
* 5 Copy mode (include pascal array)
* Highlighting and hinting to validated addresses
* Quick jumps to found validated addresses (via Ctrl+Click)
* Offsets (double-click on the address column)
* Selections of duplicates
* Address recognition and highlighting

### Utils
Started development of a set of built-in utilities.

1. TraceLog - displays all instructions on which a stop occurred during debugging in CpuView.
2. Exports - displays a list of exported functions by libraries loaded into the address space of the process being debugged.
3. Memory Map - displays the memory map of the process being debugged.

### Commands:

"?" - calculates the result of the expression  
For example: "? [RIP+EAX*2+123]" output [RIP+EAX*2+123] = [100003982] -> 35DC5E8D98948C3

"gmh", "getmodulehandle" - returns the ImageBase of the library in the process being debugged  
For example: "gmh user32" output "user32.dll" instance 7FFEFDDF0000. Path: C:\WINDOWS\System32\user32.dll

"gpa", "getprocaddress" - returns address of procedure in debugging process  
for example: "gpa user32:MessageBoxA" output "user32:MessageBoxA" address: 7FFEFDE7C5B0

"bp" - Set new BreakPoint   
for example: "bp user32:MessageBoxA" output "user32:MessageBoxA" address: 7FFEFDE7C5B0 breakpoint set

"bc" - Delete the previously set BreakPoint  
for example: "bc user32:MessageBoxA" output "user32:MessageBoxA" address: 7FFEFDE7C5B0 breakpoint remove

For gpa/getprocaddress/bp/bc commands, the library name is optional.  
for example: "gpa PeekMessageA" output "user32.dll:PeekMessageA" address: 7FFE289E3FC0

It is allowed to use offsets after the function name:  
For example: "gpa Beep" output "KERNELBASE.dll:Beep" address: 7FFE26702B10  
Now let's specify the offset when setting the breakpoint - "bp Beep+12" output "KERNELBASE.dll:Beep+12" address: 7FFE26702B1C breakpoint set

### Appearance:

Light theme:
![](https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/light.png)

Dark theme:
![](https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/dark.png)

Active jump, breakpoints, smart hints for selected instructions and their menus, Register hightlight.

RegView:

<img src="https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/regview.png"/>

RegEditors:
<img src="https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/regeditors.png"/>

Stack:

<img src="https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/stackview.png"/>

Dump:

<img src="https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/dumpview.png"/>

Hints:

<img src="https://raw.githubusercontent.com/AlexanderBagel/CPUView/main/img/hints.png"/>

https://github.com/user-attachments/assets/65bea692-c68c-4264-b4c6-74bf9d3f8c99


