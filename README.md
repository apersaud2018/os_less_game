# Welcome to an OS-less game

Hello! This is a small game written in x86 assembly that is meant to be run in the Bochs virtual machine.

# Theory
For an indepth look at the exact function of the code, please look at the [About.pdf](./About.pdf).


# Running

To run this game you will need [Python 3](https://www.python.org/downloads/), [Nasm](https://www.nasm.us/), and [Bochs](https://sourceforge.net/projects/bochs/files/bochs/).

For windows, simply run **Bochs-win64-2.6.11.exe** to install Bochs.
Installing Nasm can be skipped if the user doesn't wish to edit the code.

This assumes that all three executables are now on your PATH.
In the main folder(the folder where make.py exists) run `python make.py build` (`python3` if on Linux). This will compile the boot loader and main program and write them to a flat binary image file. Afterwards, if on Windows you can run the game with Bochs by double clicking on the rungame.bxrc. On Linux you use the command `bochs -qf rungame.bxrc` . This starts Bochs with all the configurations needed for it to run the game. There is a good chance it will start with the debugger running. This functions much like the gdb debugger, so type c to continue.
On the main menu the game will start if you press **enter**. You use **space** to jump.
