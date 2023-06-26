## Comfortably read *BOOK* files in OS/390 BookManager/READ
OS/390 ADCD 2.10 contains *BookManager/READ*, a text based alternative to reading *BOOK*s with the Microsoft Windows based [IBM Softcopy Reader](https://www.ibm.com/support/pages/ibm-softcopy-reader-windows-v40-0). Using 3270 instead of the [AS/400 5250 based InfoSeeker](https://try-as400.pocnet.net/wiki/Reviving_InfoSeeker) has the advantage of providing not just 24 lines of text, but 43 - thus giving a better overview.

A third alternative is to use the [IBM BookManager BookServer 2.3](https://github.com/cyberdotgent/bookmgr-docker). Unfortunately, this software is incompatible with reverse-proxies, leading to spurious complaints about some temporary file not being found. Also if you open a *BOOK* directly by URL (example `/bookmgr/bookmgr.cgi/BOOKS/GC28-1251-08/CCONTENTS`) the actual *BOOK* being shown is a different one.

### License
This document is part of the IBM Documentation Utilities, to be found on [GitHub](https://github.com/PoC-dev/ibmdocs-tools) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

### Preface
Occasionally, there's a more or less large cache of *BOOK* files coming in. Since this is happening in an irregular but frequent manner, I tend to forget how to efficiently handle this situation. This document is primarily meant to serve as a reminder, and copy-paste snippet provider how to prepare/expand the OS/390 environment running in the *Hercules-390* mainframe emulator accordingly. If it helps others, very good!

----
## Preparation
Steps do take before upload can commence.

### FTP `~/.netrc` considerations
The `~/.netrc` file can be used to automate FTP client tasks. Its use is not mandatory but eases repetitive steps.

This is a `~/.netrc` excerpt to tell the FTP server on OS/390 how, and where to put uploaded data:
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
 cd ENU

```
Note that an empty line **must** be added to the end of a `.netrc` stanza.

### Generating the FTP Upload-List
To upload documents to OS/390 by FTP, a list of documents (sorted descending by size for better allocation efficiency) and their sizes have to be compiled. The sizes output is used to allocate the required space individually for each dataset. *BOOK* files are by nature padded to 4k blocks anyway, so a simple division suffices. This list is then converted into FTP commands:
```
ls -1Ssk |grep -v '^total' > /tmp/books-list.txt
awk '{print "site PRI=" $1 / 4 "\nput " $2 " " $2 "k"}' < /tmp/books-list.txt > /tmp/books-upload.txt
```
In case something went wrong, it might be advisable to convert the given list into a second FTP commands file for deleting uploaded files:
```
awk '{print "del " $2 "k"}' < /tmp/books-list.txt > /tmp/books-delete.txt
```
Those files are to be fed to *stdin* of the `ftp` command.

----
## Adding a new volume to OS/390
I'm roughly using the Jay Moseley instructions about [Adding DASD Volumes](https://www.jaymoseley.com/hercules/installMVS/addingDasdV7.htm).

First, create the new volume on the host side:
```
dasdinit64 -bz2 books0-a92 3390-9 BOOKS0
```
Obey probable user/group assignments. A 3390-9 provides 8.5 GB of space. See [IBM: Disk Storage Sizes](https://www.ibm.com/docs/en/zvse/6.2?topic=SSB27H_6.2.0/fe6rf_optimizing_casize_disksizes.htm) for a table of possible sizes.

### Make Hercules recognize the new volume
This can be done online. No need to Re-IPL.

- From the hercules console (not MVS console) add the volume to the virtual hardware:
```
attach 0A92 3390 dasd/books0-a92
```
- Edit `hercules.cnf` to add an appropriate entry for the new volume. Syntax is the same as with the `attach` command, sans "attach".

The next steps involve preparing the volume from within the OS/390 environment.

- Create the VTOC by running the JCL shown. The values given provide adequate space in the VTOC for around 10,400 entries. In my example case, 6,464 datasets occupy 62% of the VTOC.
```
//P390M        JOB  1,P390,NOTIFY=P390
//             EXEC PGM=ICKDSF
//SERLOG       DD   DSN=SYS1.LOGREC,DISP=SHR
//SYSPRINT     DD   SYSOUT=*
//SYSIN        DD   *
    INIT UNITADDRESS(A92) NOVERIFY VOLID(BOOKS0) OWNERID(P390) -
       VTOC(0,1,210)
/*
```
**Note that you need to confirm the action on the MVS console!**
- Vary the device online, and mount it (MVS console):
```
V /0A92,ONLINE
M /0A92,VOL=(SL,BOOKS0),USE=PRIVATE
```
- Edit `SYS1.ADCD10.PARMLIB(VATLST00)`, add an entry for `BOOKS*`-volumes reflecting the manual mount before:
```
BOOKS*,0,2,3390    ,Y
```
- Create a user catalog on the volume by running the JCL shown. The values are expanded to provide more space in the user catalog and should be fine to around 10,000 entries:
```
//P390UCA      JOB  1,P390,NOTIFY=P390
//             EXEC PGM=IDCAMS
//SERLOG       DD   DSN=SYS1.LOGREC,DISP=SHR
//SYSPRINT     DD   SYSOUT=*
//BOOKS0       DD   UNIT=3390,VOL=SER=BOOKS0,DISP=OLD
//SYSIN        DD   *

  DEFINE USERCATALOG ( -
         NAME (UCBOOKS0) -
         VOLUME (BOOKS0) -
         CYLINDERS (40) -
         BUFFERSPACE (16384) )
/*
```

----
## Upload
```
ftp p390 < /tmp/books-upload.txt
```
In conjunction with the AS/400 based documents index facilities, you can look up the documents 8-char name. It's in the first column, in braces. With that information, you can then launch *BookManager/READ* to open this one *BOOK* from a TSO READY prompt:
```
BOOKMGR BOOK(EOY.ENU.ECSIKPLP.BOOK)
```

----
## Create a Bookshelf
A Bookmanager Bookshelf is a simple text dataset containing metadata about *BOOK* datasets.

Unfortunately, *BookManager/READ* has a limit of 2,112 datasets to be listed in one go. If you have more than this number of datasets (*BOOK*s), you need to filter the list. Since the dataset names are more or less arbitrary, that isn't of much help if you search for a certain *BOOK*.

A Bookshelf can list many more *BOOK* datasets. Thus it's a good idea to add all *BOOK*s to a Bookshelf to have an index readily available.

The filter mechanism of *BookManager/READ* for listing datasets supports only simple wildcard matches, so in the end you need to iterate through the complete alphabet 26 times to eventually add all datasets to an "allbooks" shelf. So far I'm not aware if it's possible to automate this process.

To add *BOOK*s to a Bookshelf dataset,
- type `TSO BOOKMGR` into an ISPF *Option* line
- Press Enter to see the default Bookshelfs list
- Navigate to the Menubar. Choose *Books* => *3. List books...*
- Specify the *Data set filter* in the shown input field as `EOY.ENU.*.BOOK` and press enter
- After some time needed to parse the *BOOK* datasets, a list of the first 2,112 *BOOK*s is presented
- Navigate to the Menubar. Choose *Group* => *4. Select all*
- Navigate to the Menubar. Choose *Group* => *1. Put selected books on a bookshelf...*
- Specify *3. Create...*
- Specify:
```
Bookshelf name  . . . . . . ALLBOOKS
Description . . . . . . . . All Books
Search index name . . . . . ALLBOOKS
Bookshelf data set name . . EOY.ENU.ALLBOOKS.BKSHELF
Search index data set name  EOY.ENU.ALLBOOKS.BKINDEX
```
For now the *Search index* information is not used. At a later point in time, this documentation might be updated with how to create a search index for the given (very large) Bookshelf.
- Confirm the next *Data set name* in the input field.

The Bookshelf dataset has been created with default values which is enough to accommodate 2,112 *BOOK* entries. The default parameters in the screen for creating a new Bookshelf suggest that listing *BOOK*s will create a temporary Bookshelf dataset. The space allocated is enough for 2,112 *BOOK* entries.

#### Providing more space
The Bookshelf file allocation needs to be made larger, so the rest of the *BOOK*s collection can be added to the Bookshelf. To have each and all *BOOK* things on one volume, creating this on the `BOOKS0` DASD might be advisable. Most likely, the default dataset has been allocated on some arbitrary volume, anyway. Correct all of this by running the following JCL:
```
//P390CP   JOB  1,P390,NOTIFY=P390
//CPYDTA   EXEC PGM=IEBGENER
//SYSIN    DD   DUMMY
//SYSPRINT DD   SYSOUT=*
//SYSUT1   DD   DSN=EOY.ENU.ALLBOOKS.BKSHELF,DISP=(OLD,DELETE)
//SYSUT2   DD   DSN=EOY.ENU.ALLBOOKS.BKSHELF.NEW,DISP=(NEW,CATLG),
//             UNIT=SYSDA,VOL=SER=BOOKS0,
//             SPACE=(CYL,(50,50)),
//             DCB=(DSORG=PS,RECFM=VB,LRECL=259,BLKSIZE=8000)
//*
//* Rename the new file to the old name.
//RNMF     EXEC PGM=IDCAMS
//SYSPRINT DD   SYSOUT=*
//SYSIN    DD   *
  ALTER EOY.ENU.ALLBOOKS.BKSHELF.NEW -
        NEWNAME(EOY.ENU.ALLBOOKS.BKSHELF)
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
- Specify the *Data set filter* in the shown input field as e. g. `EOY.ENU.A*.BOOK` and press enter
- After some time needed to parse the *BOOK* datasets, a list of *BOOK*s is presented
- Navigate to the Menubar. Choose *Group* => *4. Select all*
- Navigate to the Menubar. Choose *Group* => *1. Put selected books on a bookshelf...*
- Leave selection at *1. Add to...*
- Specify `Bookshelf name` as *ALLBOOKS*
- Press `F3` to close the temporary Bookshelf

**Note that you need to change the *Data set filter* accordingly with each iteration!**

You may choose to use two loops instead: One to create many temporary Bookshelves (alphapbetically descending) and leave them open (Steps 1..3), and in a second run, add the temporary dataset's contents to the main Bookshelf.

----
2023-06-26 poc@pocnet.net
