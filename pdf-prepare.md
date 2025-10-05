## What do to with new PDF files?
Occasionally, there's a large cache of PDF files coming in. Since this is happening in an irregular but frequent manner, I tend to forget how to efficiently handle this situation. This document is meant to serve as a reminder and copy-paste snippet provider.

### License
This document is part of the IBM Documentation Utilities, to be found on [GitHub](https://github.com/PoC-dev/ibmdocs-tools) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

#### Preface
PDFs found on some InfoCenter CDs are already - kind of - named by document number. They usually lack the "version" of the document to still fit into the old PC-DOS 8+3 naming scheme. For that, it's not beneficial to use those names compared to the procedure described below.

Also noteworthy is that some PDFs on said InfoCenter CDs have a size of 0 bytes. Sort those out prior to doing anything else.
```
find . -type f -a -name "*.pdf" -a -size 0 -exec rm -v {} \;
```

### Components being used
- Linux shell & friends.
- `pdfgrep`.
- *Preview.app* on my Mac.
- *BBEdit*, very friendly Mac text editor with capabilities to select not only lines but a rectangular area, and featuring regex in search/replace. Can be substituted with *vim*.

My goal isn't to have each and every subtask being automated, but to provide a good balance between manual mouse labor, and programming effort (for the more daunting subtasks).

### Checklist
- Collect all PDF files into a single directory, if possible without name collisions. If not, use a hierarchy.
- Use `rdfind` or a similar tool to eliminate exact duplicates. Be creative (possibly through renames) to eliminate name collisions.
- Create an index text file. Because the document number is found almost every time on the first three pages of a PDF, there's a very high probability that the document number can be derived automatically:
```
pdfgrep --page-range=1-3 -e '[A-Z][A-Z,0-9][0-9][0-9]-[0-9]{4}-[0-9]{2}' *.pdf > /tmp/pdf-document-numbers.txt
```
- Delete unnecessary white space:
```
sed -Ei -e 's/:[ ]+/:/' -e 's/[ ]*$//' /tmp/pdf-document-numbers.txt
```
- Manually inspect the resulting text file. Sometimes, one PDF file yields multiple matches. Ideally, there should be one line with a file name, a colon, and the document number. Clean excess matches per file. Sometimes there seems to be complete garbage being found. Remove those lines completely. The PDFs in question then need to be inspected by opening them and looking inside.
- Change the colon to a blank, e. g. within `vim`:
```
:%!tr ':' ' '
```
- Use the result to create symlinks into an empty directory:
```
cat /tmp/pdf-document-numbers.txt |while read FILE DOCNBR; do
 ln -v ${FILE} ../newpdfs/${DOCNBR}.pdf
done
```
- Move the appropriately named PDF files to their final destination, but don't overwrite existing ones:
```
cd ../newpdfs
yes n |mv -i * /var/www/default/pages/ibmdocs/
```
- You are now left with a bunch of duplicates by document number. Those can safely be deleted.
```
cd ..
rm -rf newpdfs
```
- Handle the leftover PDF files needing manual inspection. Rename them to their document number and move the result to the final destination directory. Don't overwrite existing files. See above.
- If the file does not have any document number, save it elsewhere.
- Run `ibmdoc-db-lint.pl`. This creates appropriate entries in the database for new (PDF) files.
- Manually inspect the database for missing titles. You need to manually open each document with an empty metadata record in the database, and type/copy-paste the title and release year along with a probable subtitle (most often for RedBooks) to the database. This is what the AS/400 frontend is mainly meant for.
- Finally run `ibmdoc-generate-index.sh` to publish the new database entries to the documents table.

### For future enhancements
Perhaps it might help automatic extraction of title and year to have a copy of the front page in a text file.
```
ls -1 |while read PDF; do pdftotext -f 1 -l 1 ${PDF} $(basename ${PDF} .pdf).txt; done
```
This is currently under investigation.

**Note:** `ibmdoc-copy-unhandled-pdfs.pl` copies such "unhandled" PDFs being already in the database, but with default values, to separate directory for easier treatment:
- Empty title,
- Year of publication 1960.

----
2023-11-05 poc@pocnet.net
