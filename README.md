# Trans Flag Scroller

A scrolling text demo for PC that fits in a boot sector.

![Screenshot of the scroller](https://raw.githubusercontent.com/spazzylemons/trans-flag-scroller/main/screenshot.png)

## Usage

You can run the image in [QEMU](https://www.qemu.org/) or
[86Box](https://86box.net/), or copy it to the boot sector of any bootable
medium and boot it (if you do this last method, you will overwrite the partition
table of the drive!)

Requires CGA minimum for graphics, though VGA is preferred for better colors.
This software should run on most IBM PCs and compatibles.

To run in QEMU, use this command:

```sh
qemu-system-x86_64 trans.img
```

To run in 86Box, insert the image into a virtual floppy drive and restart the
machine. Not all of the ROMs offered by 86Box will boot the image.

To run on real hardware, you can perform these steps. This assumes you have a
bootable medium inserted, and will use `<device>` as a placeholder in the
commands. You may also need to run these commands as root/via sudo.

First, you should back up the current boot sector:

```sh
dd count=512 if=<device> of=backup.img
```

Then, copy the boot sector to the bootable medium:

```sh
dd if=trans.img of=<device>
```

You can then run the program by inserting the bootable medium into a PC and
booting from it.

When you are finished, you should restore the boot sector:

```sh
dd if=backup.img of=<device>
```

## Building

Assemble the image using [NASM](https://nasm.us/):

```sh
nasm -f bin -o trans.img trans.asm
```

## License

This software is licensed under the MIT license. Redistribution is highly
encouraged.
