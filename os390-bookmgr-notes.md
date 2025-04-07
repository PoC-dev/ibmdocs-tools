## Comfortably read *BOOK* files in OS/390 BookManager/READ
*BOOK* is an IBM proprietary format for publishing technical documentation documents. It is a very old format and has been superseded by PDFs for a long time. Still, there's a considerable amount of old documentation in *BOOK* format.

As with PDF, *BOOK*s need special software to be read:
- the Microsoft Windows based [IBM Softcopy Reader](https://www.ibm.com/support/pages/ibm-softcopy-reader-windows-v40-0)
- the [IBM BookManager BookServer 2.3](https://github.com/cyberdotgent/bookmgr-docker)
- the [AS/400 5250 based InfoSeeker](https://try-as400.pocnet.net/wiki/Reviving_InfoSeeker)
- OS/390 ADCD 2.10 contains *BookManager/READ MVS*

This list is sorted according to my personal perception of awfulness.

The visual rendition of text provided by the *IBM Softcopy Reader* isn't particularly friendly to the eye.

The *IBM BookManager BookServer* is incompatible with reverse-proxies, leading to spurious complaints about some temporary file not being found. Also if you open a *BOOK* directly by URL (example `/bookmgr/bookmgr.cgi/BOOKS/GC28-1251-08/CCONTENTS`) the actual *BOOK* being shown is a different one.

Some *BOOK*s contain graphics. Unless there is a character based rendition included (such as with simple flowcharts), these obviously cannot be displayed with purely text based viewers.

Using 3270 instead of 5250 has the advantage of providing not just 24 lines of text, but 43 (if configured correctly) - thus giving a better overview. Many older *BOOK*s are preformatted to be 80 chars wide. Thus, using a 132 character width terminal setting might not provide as beneficial as it seems.

### License
This document is part of the IBM Documentation Utilities, to be found on [GitHub](https://github.com/PoC-dev/ibmdocs-tools) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

### Preface
Occasionally, there's a more or less large cache of *BOOK* files coming in. Since this is happening in an irregular but frequent manner, I tend to forget how to efficiently handle this situation. This document is primarily meant to serve as a reminder, and copy-paste snippet provider how to prepare/expand the OS/390 environment running in the *Hercules-390* mainframe emulator accordingly. If it helps others, very good!

**Note**: OS/390 ADCD 2.10 is partly incompatible with large 3390 DASDs. Hence, this document shows how to spread *BOOK*s over several smaller DASD volumes.

----
## Preparation
Steps do take before upload can commence.

### FTP `~/.netrc` considerations
The `~/.netrc` file can be used to automate FTP client tasks. Its use is not mandatory but eases repetitive steps.

This is a `~/.netrc` excerpt to tell the FTP server on OS/390 how, and where to put uploaded data, by mapping DS name components to "virtual" directories:
```
machine p390
login P390
password P390
macdef init
 bin
 site VOL=BOOKS0
 site LR=4096
 site BLK=4096
 site RECF=FBS
 site COND=delete
 site BL
 site SEC
 cd ..
 cd EOY
 cd BOOKS

```
Note that an empty line **must** be added to the end of a `.netrc` stanza.

See [Using PDFs and BookManager Books on your workstation or mainframe](https://www.ibm.com/support/pages/using-pdfs-and-bookmanager-books-your-workstation-or-mainframe) for some hints about uploading *BOOK* files, and related data. To get help for the given parameters, use your FTP client, connect to the OS/390 instance in question, and issue a `quote help site` to get a long text describing the parameters I've used. And many more.

### Generating the FTP Upload-List
To upload documents to OS/390 by FTP, a list of documents (sorted descending by size for better allocation efficiency) and their sizes have to be compiled. The sizes output is used to allocate the required space individually for each dataset. *BOOK* files are by nature padded to 4 KiB blocks anyway, so a simple division suffices. This list is then converted into FTP commands:
```
ls -1Ssk |grep -v '^total' |grep -Eiv '^[0-9]+ eo[xy]0[0-9]mst\.boo$' > /tmp/books-list.txt

awk '{volno = NR % 4; print "site VOL=BOOKS" volno "\nsite PRI=" $1 / 4 "\nput " $2 " " $2 "k"}' < /tmp/books-list.txt > /tmp/books-upload.txt
```
This generates three lines per upload:
- one for setting the destination volume,
- one for setting the allocation size,
- and one for the actual upload.

Example:
```
site VOL=BOOKS0
site PRI=9
put orvvit3c.boo orvvit3c.book
site VOL=BOOKS1
site PRI=8
put zu4gf08t.boo zu4gf08t.book
…
```
Together with the `cd` commands from `.netrc` above, the DS name will be assembled to be `EOY.BOOKS.BOOKNAME.BOOK`.

Above, certain books are eliminated by `grep` from being handled. Those are part of *BookManager/READ* on OS/390, and located on the OS3DAA volume.

In case something went wrong, it might be advisable to convert the given list into a second FTP commands file for deleting uploaded files by issuing FTP delete commands:
```
awk '{print "del " $2 "k"}' < /tmp/books-list.txt > /tmp/books-delete.txt
```
Those files are to be fed to *stdin* of the `ftp` command. See below.

----
## Adding new volumes to OS/390
I'm roughly using the Jay Moseley instructions about [Adding DASD Volumes](https://www.jaymoseley.com/hercules/installMVS/addingDasdV7.htm).

The following table provides information about the most current device type, the 3390 family. It lists the name to be used on the command line parameter for the device type and respective size, for creating DASD volumes.
```
Type-Mdl |     Total Bytes
---------+-----------------------------
3390-1   |     846,236,160 ( 0.79 GiB)
3390-2   |   1,692,472,320 ( 1.58 GiB)
3390-3   |   2,538,708,480 ( 2.36 GiB)
3390-9   |   8,514,049,320 ( 7.93 GiB)
```
For details, see the [Mainframe Disk Capacity Table](https://ibmmainframes.com/references/disk.html) for more devices and their sizes. You need to relate those to the *CKD DEVICES* table in the Hercules documentation [Creating DASD](https://sdl-hercules-390.github.io/html/hercload.html#loading) regarding *devtype-model* to use on the command line.

**Note**: OS/390 ADCD 2.10 is partly incompatible with very large 3390 DASDs. It works with the 7.93 GB variant, though.

First, create the new volumes on the host side. Here, we create several 7.93 GiB volumes with the less efficient but quicker zlib compression type.
```
dasdinit64 -z books0-a92 3390-9 BOOKS0
dasdinit64 -z books1-a93 3390-9 BOOKS1
dasdinit64 -z books2-a94 3390-9 BOOKS2
dasdinit64 -z books3-a95 3390-9 BOOKS3
```
Obey probable user/group assignments on the host side, so Hercules can access the files when not running as *root*!

### Make Hercules recognize the new volumes
This can be done online. No need to Re-IPL.

- From the hercules console (not MVS console) add the volume to the virtual hardware:
```
attach 0A92 3390 dasd/books0-a92
attach 0A93 3390 dasd/books1-a93
attach 0A94 3390 dasd/books2-a94
attach 0A95 3390 dasd/books3-a95

```
- Edit `hercules.cnf` to add appropriate entries for the new volume. Syntax is the same as with the `attach` command, sans "attach". This is necessary to have the volume reappear after you quit and restart Hercules.

The next steps involve preparing the volumes from within the OS/390 environment.

- Create the VTOCs by running the JCL shown. The values given provide adequate space in the VTOC for many entries.
```
//P390INZ      JOB  1,P390,MSGCLASS=A
//             EXEC PGM=ICKDSF
//SERLOG       DD   DSN=SYS1.LOGREC,DISP=SHR
//SYSPRINT     DD   SYSOUT=*
//SYSIN        DD   *
    INIT UNITADDRESS(A92) NOVERIFY VOLID(BOOKS0) VTOC(0,1,150)
    INIT UNITADDRESS(A93) NOVERIFY VOLID(BOOKS1) VTOC(0,1,150)
    INIT UNITADDRESS(A94) NOVERIFY VOLID(BOOKS2) VTOC(0,1,150)
    INIT UNITADDRESS(A95) NOVERIFY VOLID(BOOKS3) VTOC(0,1,150)
/*
```
**Note that you need to confirm the action on the MVS console for each volume!**
- Vary the devices online, and mount them (MVS console):
```
V /0A92,ONLINE
V /0A93,ONLINE
V /0A94,ONLINE
V /0A95,ONLINE
M /0A92,VOL=(SL,BOOKS0),USE=PRIVATE
M /0A93,VOL=(SL,BOOKS1),USE=PRIVATE
M /0A94,VOL=(SL,BOOKS2),USE=PRIVATE
M /0A95,VOL=(SL,BOOKS3),USE=PRIVATE
```
- Edit `SYS1.ADCD10.PARMLIB(VATLST00)`, add an entry for `BOOKS*`-volumes reflecting the manual mount before:
```
BOOKS*,0,2,3390    ,Y
```

----
## Upload
```
ftp p390 < /tmp/books-upload.txt
```
In conjunction with the AS/400 based documents index facilities discussed in the main [README](README.md), you can look up the documents 8-char name. It's in the first column, in braces. With that information, you can then launch *BookManager/READ* to open this one *BOOK* from a TSO READY prompt:
```
BOOKMGR BOOK(EOY.BOOKS.ECSIKPLP.BOOK)
```

----
## Create a Bookshelf
A Bookmanager Bookshelf is a simple text dataset containing metadata about *BOOK* datasets.

Unfortunately, *BookManager/READ* has a limit of 2,112 datasets to be listed in one go. If you have more than this number of datasets (*BOOK*s), you need to filter the list. Since the dataset names are more or less arbitrary, that isn't of much help if you search for a certain *BOOK*.

A Bookshelf can list many more *BOOK* datasets. Thus it's a good idea to add all *BOOK*s to a Bookshelf to have an index readily available.

**Note:** There's a limitation of around 8k *BOOK*s which can be handled in the default TSO memory region. This is not about the OS running out of memory! Instead, the user's single virtual memory allocation (minus some overhead) is exhausted. Workaround: Add plenty of memory in the logon screen's *Size* field. Maximum is 2096128 (bytes).

The filter mechanism of *BookManager/READ* for listing datasets supports only simple wildcard matches, so in the end you need to iterate through the complete alphabet 26 times to eventually add all datasets to an "allbooks" shelf. So far I'm not aware if it's possible to automate this process.

To add *BOOK*s to a Bookshelf dataset,
- type `TSO BOOKMGR` into an ISPF *Option* line
- Press Enter to see the default Bookshelfs list
- Navigate to the Menubar. Choose *Books* => *3. List books...*
- Specify the *Data set filter* in the shown input field as `EOY.BOOKS.*.BOOK` and press enter
- Press enter to copy the resulting short list into a temporary Bookshelf
- After some time needed to parse the *BOOK* datasets, a list of the first 2,112 *BOOK*s is presented
- Navigate to the Menubar. Choose *Group* => *4. Select all*
- Navigate to the Menubar. Choose *Group* => *1. Put selected books on a bookshelf...*
- Specify *3. Create...*
- Specify:
```
Bookshelf name  . . . . . . ALLBOOKS
Description . . . . . . . . All Books
Search index name . . . . . ALLBOOKS
Bookshelf data set name . . EOY.BOOKS.ALLBOOKS.BKSHELF
Search index data set name  EOY.BOOKS.ALLBOOKS.BKINDEX
```
For now the *Search index* information is not used. At a later point in time, this documentation might be updated with how to create a search index for the given (very large) Bookshelf.
- Confirm the next *Data set name* in the input field.

The Bookshelf dataset has been created with default values which is enough to accommodate 2,112 *BOOK* entries. The default parameters in the screen for creating a new Bookshelf suggest that listing *BOOK*s will create a temporary Bookshelf dataset. The space allocated is enough for 2,112 *BOOK* entries.

#### Providing more space
The Bookshelf file allocation needs to be made larger, so more *BOOK*s can be added to the Bookshelf.
```
//P390CP   JOB  1,P390,NOTIFY=P390
//CPYDTA   EXEC PGM=IEBGENER
//SYSIN    DD   DUMMY
//SYSPRINT DD   SYSOUT=*
//SYSUT1   DD   DSN=EOY.BOOKS.ALLBOOKS.BKSHELF,DISP=(OLD,DELETE)
//SYSUT2   DD   DSN=EOY.BOOKS.ALLBOOKS.BKSHELF.NEW,DISP=(NEW,CATLG),
//             UNIT=SYSDA
//             SPACE=(CYL,(100,100)),
//             DCB=(DSORG=PS,RECFM=VB,LRECL=259,BLKSIZE=8000)
//*
//* Rename the new file to the old name.
//RNMF     EXEC PGM=IDCAMS
//SYSPRINT DD   SYSOUT=*
//SYSIN    DD   *
  ALTER EOY.BOOKS.ALLBOOKS.BKSHELF.NEW -
        NEWNAME(EOY.BOOKS.ALLBOOKS.BKSHELF)
/*
```
The DCB parameters have been obtained from the original file.

#### Add the rest of the *BOOK*s
First we need to know which was the last file added to the Bookshelf.
- Type `TSO BOOKMGR` into an ISPF *Option* line
- Press Enter to see the default Bookshelfs list
- Navigate the cursor to the `ALLBOOKS` Bookshelf, and press Enter to open it
- Put 2112 into the `SCROLL` input field right of the command line, and press `F8`, or `PgDown` (depending on your terminal/emulator)
- Take note of the *Book Name* being shown
- Replace the `SCROLL` input field content with the former value, either `PAGE`, or `CSR`
- Press `F3` to close the Bookshelf

The next steps are somewhat free-form and highly repetitive. Depending on the first character of the last added file, you need to first add the rest of this "character's group" to the Bookshelf, and from there work through the alphabet in the *Data set filter* until all *BOOK*s have been added. Somewhat generalized, the needed steps are:
- Navigate to the Menubar. Choose *Books* => *3. List books...*
- Specify the *Data set filter* in the shown input field as e. g. `EOY.BOOKS.A*.BOOK` and press enter
- After some time needed to parse the *BOOK* datasets, a list of *BOOK*s is presented
- Navigate to the Menubar. Choose *Group* => *4. Select all*
- Navigate to the Menubar. Choose *Group* => *1. Put selected books on a bookshelf...*
- Leave selection at *1. Add to...*
- Specify `Bookshelf name` as *ALLBOOKS*
- Press `F3` to close the temporary Bookshelf

**Note that you need to change the *Data set filter* accordingly with each iteration!**

You may choose to use two loops instead: One to create many temporary Bookshelves (alphapbetically descending) and leave them open (Steps 1..3), and in a second run, add the temporary dataset's contents to the main Bookshelf.

----
2025-04-06 poc@pocnet.net
