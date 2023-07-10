## What do to with new BOOK files?
Occasionally, there's a large cache of BOOK files coming in. Since this is happening in an irregular but frequent manner, I tend to forget how to efficiently handle this situation. This document is meant to serve as a reminder and copy-paste snippet provider.

### License
This document is part of the IBM Documentation Utilities, to be found on [GitHub](https://github.com/PoC-dev/ibmdocs-tools) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

### Components being used
- Linux shell & friends.
- [IBM BookManager BookServer 2.3](https://github.com/cyberdotgent/bookmgr-docker) for 32-Bit Linux - (GitHub) project, but used without the container stuff.
- *BBEdit*, very friendly Mac text editor with capabilities to select not only lines but a rectangular area, and featuring regex in search/replace. Can be substituted with *vim*.
- [Tables](https://www.x-tables.eu), a minimalist Mac spreadsheet application. Can probably be substituted with *BBEdit*, or *vim* or even shell scripts with textutils.

My goal isn't to have each and every subtask being automated, but to provide a good balance between manual mouse labor, and programming effort (for the more daunting subtasks).

### Checklist
- Collect all .BOO files into a single directory, if possible without name collisions. If not, use a hierarchy.
- Use `rdfind` or a similar tool to eliminate exact duplicates. Be creative (possibly through renames) to eliminate name collisions. Keep 8-char names as much as possible.
- Copy/move the result to to `webserver:/var/www/default/pages/books-to-sort/` (directory visible/configured to the Library Server).
- Rebuild Library Server index, use admin-function in `lynx http://localhost:8080/` - running it in a regular GUI browser might lead to premature forced end of the CGI process rebuilding the index.
- Show folder contents (HTML table) in the Library Server web view.
- Mark and copy the HTML table part of the page into *Tables.app*.
- Clean up unneeded columns, headings, etc. so only title, filename, release date, and document number columns remain, containing pure data.
- Manually clean erratic book titles (UTF-8 crap, ©, \*, etc) - it might be easier to spot them thru the 5250 screen, though.
- Sort by Docnbr, Filename.
- Manually clean duplicate document numbers: Keep newest. Also delete associated files from file system.
- Copy date column, shove through `sed` or *BBEdit* search/replace for proper four-digit-year.
```
s/^[0-1][0-9]/[0-3][0-9]/([6-9][0-9]) [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$/19\1/
s/^[0-1][0-9]/[0-3][0-9]/([0-5][0-9]) [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$/20\1/
```
- Paste result back to Tables column.
- Copy/export whole *Tables* table into (tab) text document.
- FTP to AS/400 IFS (home directory).
- Run job to import into the temporary PF:
```
SBMJOB CMD(CPYFRMIMPF FROMSTMF('/home/poc/newdocs.txt') +
 TOFILE(IBMDOCS/NEWDOCSPF) RCDDLM(*CRLF) STRDLM(*NONE) FLDDLM(*TAB)) +
 JOB(IMPNEWDOCS)
RMVLNK OBJLNK('/home/poc/newdocs.txt')
```
- Show duplicates (for obtaining to delete file names):
```
SELECT filename FROM newdocspf
WHERE docnbr IN (
 SELECT docnbr FROM ibmdoctypf WHERE doctype='B'
)
```
- Manually extract the shown file names, add `.boo` extension and feed the list to `rm`.
- Delete duplicates (after file deletion):
```
DELETE FROM newdocspf
WHERE docnbr IN (
 SELECT docnbr FROM ibmdoctypf WHERE doctype='B'
)
```
- **VERY IMPORTANT! There shall be no duplicate records!!**
- Run `ibmdoc-merge-docs.pl`. Moves (!) records from *newdocspf* to real destination tables. Moving should make it possible to re-run the script after a forced `die;`. Has not been tested, and would be a good use case for using commitment control on the database tables.

When the script has run without error, you can delete the links from `webserver:/var/www/default/pages/books-to-sort/`. **Note:** a `ls -l` should show a *link count* of two for all files there, because `ibmdoc-merge-docs.pl` links the data to a new directory entry with the name of the document number.

If you want to upload the files to OS/390, better no not delete them.

----
2023-07-28 poc@pocnet.net
