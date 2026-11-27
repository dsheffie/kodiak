---
title: Getting a software stack (Solaris, SunOS, NeXTSTEP)
---

# Getting a software stack: Solaris, SunOS, NeXTSTEP

Kodiak runs the **real SPARCstation 20 boot PROM** and **unmodified OS install media**. None of that
software is in this repo. This page lists what to get, how to check you have the right copy, how to
install each OS into a disk image, and how to boot that disk on the board.

The recommended path for every OS is:

1. Install into a disk image under **ss10sim**, the SS-20 instruction-set simulator
   (`github.com/dsheffie/ss10sim`). It uses the same C++ device models as the board, and installing
   in the sim is easier to drive and to retry.
2. Copy the installed image to the Ultra96 and boot it with `kodiak_arm`.

## 1. What you need

Kodiak doesn't ship Sun or NeXT software. Use media you have the right to use: dumped from your own
hardware, or from a software archive such as
[fsck.technology/software/Sun Microsystems](https://fsck.technology/software/Sun%20Microsystems/).
You can also search for the file names below. Whatever the source, check the size and md5. These are
the exact files Kodiak has been brought up with; other releases may hit untested paths.

| What | File used here | Size (bytes) | md5 |
|---|---|---|---|
| SS-20 OpenBoot PROM 2.25R (unified SS-10/20 ROM, 512 KB) | `obp.rom` | 524288 | `63e763220d1213b9ab3fca214cd6b075` |
| Solaris 2.5.1 11/97 SPARC install CD | `solaris_2.5.1_1197.iso` | 452157440 | `c8309cbf3ccf5d9db6f8173838d2dedc` |
| SunOS 4.1.4 (Solaris 1.1.2) SPARC install CD | `sunos414.iso` | 329297920 | `927fa22042a70bf21a80be9393b15770` |
| NeXTSTEP 3.3 for RISC (SPARC) install CD | `nextstep33_risc.iso` | 369573888 | `1eb9460eba52a74aaa15d380ed0a1e64` |

The rest is already in a repo or a distro package:

| What | Where |
|---|---|
| NVRAM image with `diag-switch?` false (skips the long POST) | `arm/ss20_nvram_nodiag.bin` (this repo) |
| NVRAM image as dumped (`diag-switch?` true) | `superdupersparc/sparc_tests/ss20_nvram.bin` |
| TCX framebuffer FCode, for Solaris/SunOS consoles | qemu's `QEMU,tcx.bin` (Debian/Ubuntu `qemu-system-data`: `/usr/share/qemu/QEMU,tcx.bin`) |

!!! warning "Never commit the PROM or the ISOs"
    `obp.rom` is Sun's firmware. `kodiak_arm` and ss10sim load it at run time from the path you give
    them, so it never needs to be in a repo.

## 2. The board side, once

On the Ultra96-v2, running its stock PetaLinux:

- **Kernel module:** load the AXI/DRAM driver (`ultra96v2_riscv.ko`, from `ultra96v2-rv64core-kmd`)
  after every power cycle: `insmod ultra96v2_riscv.ko`. `/dev/rv64core_fpga` should appear.
- **Bitstream:** build it with `gen_mipscore.sh` followed by `rebuild_kodiak.tcl` (see the script
  headers). Then program it with `fpgautil -b kodiak.bit`. About 1 in 20 loads hangs the board, which
  then needs a power cycle.
- **`kodiak_arm`:** build it on the board with `cd arm && make`. It needs
  `libboost-program-options` and `libcapstone`. The device models come from the
  `superdupersparc` submodule.

`kodiak_arm` options you'll use (`kodiak_arm --help` has the rest):

| Option | Meaning |
|---|---|
| `-r obp.rom` | the boot PROM (required) |
| `--nvram arm/ss20_nvram_nodiag.bin` | the NVRAM image |
| `--scsi-disk ID:img` | a disk at SCSI target ID (the OS disk is target 3, `sd0` / `c0t3d0`). It is written in place, so keep a copy. |
| `--scsi-cdrom ID:iso` | a CD-ROM (target 6 by convention) |
| `--no-kbd` | no keyboard, so the console is ttya on your terminal |
| `--tcx tcx.bin` | a TCX framebuffer (Solaris/SunOS probe one; with `--no-kbd` the console stays on ttya) |
| `--cg14 --cg14-depth 32 --fb-dump fb.ppm --input-fifo in.fifo` | NeXTSTEP's graphical console: CG14 framebuffer, screen dumped to a PPM, keyboard and mouse fed through a FIFO |

Ctrl-C on the terminal kills `kodiak_arm`. NeXTSTEP needs a Ctrl-C delivered to the guest, so run
`stty intr '^]'` first: Ctrl-C then goes to the guest and Ctrl-] stops the run.

## 3. ss10sim basics

Every install below uses this base command line:

```sh
ss10sim --rom obp.rom --nvram ss20_nvram_nodiag.bin --ram 256 --tcx --no-kbd \
  --scsi-disk 3:disk3.img  ...  --console-input -
```

- `--console-input -` types your terminal's input into ttya. Run it under `stty raw -echo` (and
  `stty sane` afterwards), or inside a tmux session if you want to script the prompts.
- Make the target disk sparse first: `truncate -s 2G disk3.img` (SunOS: 1 GB is enough).
- ss10sim doesn't save NVRAM changes. Anything you `setenv` at `ok` lasts only for that run.
- OBP reaches `ok` after roughly 6 billion simulated instructions, i.e. a minute or two.

## 4. Solaris 2.5.1

The installer won't boot from the CD at target 6 under OBP 2.25R. Attach the ISO **as a disk** at
target 1 instead, and boot its slice d:

```sh
cp solaris_2.5.1_1197.iso disk1.img          # used as a disk; take a copy
truncate -s 2G disk3.img
ss10sim --rom obp.rom --nvram ss20_nvram_nodiag.bin --ram 256 --tcx --no-kbd \
  --scsi-disk 3:disk3.img --scsi-disk 1:disk1.img --console-input -
ok boot disk1:d
```

Then follow the installer:
- terminal type vt100 (or whatever your terminal is)
- label the disk with type `SUN2.1G`
- pick the Entire Distribution, hostname `kodiak` (any name works)

When it finishes, boot the installed disk with `boot disk`. The first boot stops at the sysid
root-password prompt.

On the board:

```sh
kodiak_arm -r obp.rom --nvram ss20_nvram_nodiag.bin --tcx tcx.bin --no-kbd --scsi-disk 3:disk3.img
```

OBP autoboots the disk. If you land at `ok`, type `boot disk`.

## 5. SunOS 4.1.4

SunOS needs the CD-ROM in 512-byte-block mode (`--cdrom-bs 512`) and boots from target 6:

```sh
truncate -s 1G disk3.img
ss10sim --rom obp.rom --nvram ss20_nvram_nodiag.bin --ram 128 --tcx --no-kbd \
  --scsi-disk 3:disk3.img --scsi-cdrom 6:sunos414.iso --cdrom-bs 512 --console-input -
ok boot cdrom
```

From the MUNIX miniroot menu:
1. Run `format`, choose disk type `SUN1.05`, and write the label.
2. Run `suninstall` and choose a Full_install.

**Known problem: the end of `suninstall` loops** on "Versatec ... cannot extract" / "mount volume
1". The guest can't see the last directory record on the ISO. This looks like a 512-byte CD bug in
the sim and hasn't been investigated. Interrupt the loop. Interrupting also skips suninstall's
post-install, so do it by hand from the miniroot shell, with the new root mounted (paths relative to
it):

- copy `usr/kvm/stand/vmunix` and `usr/kvm/stand/boot.sun4m` to `/vmunix` and `/boot`
- install the boot block: `installboot` with `bootsd` onto `/dev/rsd0a`
- write `/etc/fstab`:
  ```
  /dev/sd0a / 4.2 rw 1 1
  /dev/sd0g /usr 4.2 rw 1 2
  /dev/sd0h /home 4.2 rw 1 3
  ```
- write `/etc/hostname.le0` containing the hostname, then run `MAKEDEV std sd0` in `/dev`
- populate `/sbin` from `usr/kvm/boot/*` plus `usr/kvm/stand/sh`
- add a `/sbin/hostname` shell script, and add a call to it at the end of `/etc/rc.single`. The 4.1.4
  media has no static `hostname`, and without one `rc.boot` loops asking bootparams. The script:
  ```sh
  #!/sbin/sh
  # no static hostname on the 4.1.4 media: use the file until /usr is up
  if [ -x /usr/bin/hostname ]; then
    if [ $# -eq 0 -a -z "`/usr/bin/hostname`" ]; then
      read h < /etc/hostname.le0; /usr/bin/hostname $h
    fi
    exec /usr/bin/hostname "$@"
  fi
  if [ $# -eq 0 ]; then read h < /etc/hostname.le0; echo $h; fi
  ```

The disk then boots multi-user to `login:` (root has no password). It runs on the board with the
same command line as Solaris. Shut it down with `sync; halt`. qemu's SS-20 is no help with this OS:
4.1.4's GENERIC kernel panics there early.

## 6. NeXTSTEP 3.3

The disk goes at target 3 and the CD at target 6:

```sh
truncate -s 2G ns33.img
ss10sim --rom obp.rom --nvram ss20_nvram_nodiag.bin --ram 256 --tcx --no-kbd \
  --scsi-disk 3:ns33.img --scsi-cdrom 6:nextstep33_risc.iso --console-input -
ok boot cdrom
```

The first prompts (language, "prepare the disk") come from the standalone booter. Mach starts after
the second answer, and the rest of the first install stage runs on ttya.

**Keep the CD attached on every boot.** `/etc/fstab` mounts it (`/dev/sd1a` as `/NEXTSTEP_INSTALL`).
Without it, fsck fails and the boot drops to the single-user `#` shell.

On the board, serial console:

```sh
stty intr '^]'
kodiak_arm -r obp.rom --nvram ss20_nvram_nodiag.bin --no-kbd \
  --scsi-disk 3:ns33.img --scsi-cdrom 6:nextstep33_risc.iso
```

When `rc.net` starts waiting for a network configuration server, press **Ctrl-C** once. The Lance
model receives nothing, so it would otherwise wait forever.

The second install stage and the desktop need the **CG14** framebuffer. NeXTSTEP's booter can't map
TCX or cg6 on the SS-20.

```sh
kodiak_arm -r obp.rom --nvram ss20_nvram_nodiag.bin --cg14 --cg14-depth 32 \
  --fb-dump fb.ppm --input-fifo in.fifo \
  --scsi-disk 3:ns33.img --scsi-cdrom 6:nextstep33_risc.iso
echo "move 10 0" > in.fifo      # mouse/keyboard commands: see kodiak_arm --help
```

Finish Configure, then the second stage. Workspace then logs in as `me`, and `su` needs no password.

**Known problems:**
- Every reboot that NeXTSTEP starts itself (fsck's automatic reboot, the installer's Restart) hangs
  in OBP's reset loop when a CG14 is present. `halt` is fine. After a hang, kill `kodiak_arm` and boot
  again: fsck has already marked the disk clean.
- Mouse: the last packet of a burst only takes effect when the next one arrives. Follow each command
  with a small `move 1 0`. Double-click doesn't register; use click plus `meta o`.

## Also known to work

- **NetBSD 10.2 sparc** boots multi-user from an existing install, on the serial console or the CG14.
  Its `cgfourteen` driver uses SX, which Kodiak doesn't model, so boot with `boot disk -c`, then type
  `disable sx` and `quit`.
- **Linux** (buildroot, SILO disk) is what the CINT95 and MiBench bakeoff runs use.
