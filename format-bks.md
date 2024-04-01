The *Book Shelf* is a text based file for grouping *BOOK* files in a directory: A shelf.

The file contains
- a header
- *BOOK* entries. FIXME: Are 0 entries allowed?

FIXME: EBCDIC, or ASCII required?

## Header.
Example:
```
BKSHELF=CBLLE
BKSTITLE=Programming: ILE COBOL
BKSDATETIME=01/22/24 17:51:23
BKSINDEX=
BKIDATETIME=
BKSLEXIS=
BKIBOOKS=     0
```
- `BKSHELF` is a short name for the shelf. FIXME: Length? Character restrictions?
- `BKSTITLE` is a friendly name for the shelf. FIXME: Length?
- `BKSDATETIME` is a time stamp in US format `MM/DD/YY HH:MM:SS`. FIXME: Creation time? Last changed?
- `BKSINDEX` is the name of an Book Shelf Index. FIXME: Much more additional information needed.
- `BKIDATETIME` is a time stamp in US format `MM/DD/YY HH:MM:SS`. FIXME: Creation time? Last changed?
- `BKSLEXIS` FIXME: What is this?
- `BKIBOOKS` is a right adjusted, six digit field. FIXME: Purpose?

## BOOK entry.
Example:
```
SHSC09-2539-01
ST  ILE COBOL for AS/400 Reference
BKNAME=SC092539
BKDATETIME=03/12/99 11:20:08
BKFLAG=I
```
- `SH` is the starting sequence listing the IBM internal document number (ID) for a *BOOK*.
- `ST` is the starting sequence listing the *BOOK* title.
- `BKNAME` is the file name of the referenced *BOOK*.
- `BKDATETIME` is a time stamp in US format `MM/DD/YY HH:MM:SS`. FIXME: Creation time? Last changed?
- `BKFLAG` FIXME: What is this?

----
2024-04-02 poc@pocnet.net
