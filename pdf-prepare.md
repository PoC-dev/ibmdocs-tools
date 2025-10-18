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
pdfgrep --page-range=1-3 -e '[A-Z][A-Z,0-9][0-9][0-9]-[0-9]{4}-[0-9]{2}' *.pdf |sed -E -e 's/:[ ]+/:/' -e 's/[ ]*$//' |sort -t: -k2 |uniq > /tmp/pdf-document-numbers.txt
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

### Automatic extraction of title and year
The following section describes procedures for automatic extraction of title and year. This is feasible only if the bunch of PDFs all are relatively uniform in appearance. If in doubt, manually handle the fewer exceptions, and automate the rest.

This section assumes that you have already renamed and added the respective PDFs to the database through running `ibmdoc-db-lint.pl`, and subsequently `ibmdoc-copy-unhandled-pdfs.pl` to generate a copy of not-indexed PDFs to a separate directory. All steps take place within this directory.

> **Note:** `ibmdoc-copy-unhandled-pdfs.pl` copies such "unhandled" PDFs being already in the database, but with default values, to separate directory for easier treatment:
- Empty title,
- Year of publication 1960.

First, generate a textual copy of the front page into a separate file.
```
for PDF in *.pdf; do pdftotext -f 1 -l 1 ${PDF} $(basename ${PDF} .pdf).txt; done
vi *.txt
```
Due to PDFs being free-format, the safest approach is to manually open each text file in an editor of choice, correct formatting, and save. Facing hundreds of text files to open and handle seems daunting. But manually looking through hundreds of similar PDFs, and typing the data into the 5250 form is even more daunting. Desired result is that the first line contains the document title, and the second the document subtitle, if available. If not, it should be an empty line.

Next step is to extract a possible publication year from page 4, and append this to the respective text file.
```
for PDF in *.pdf; do pdfgrep --page-range=4 -e '[1,2][0-9][0-9][0-9]' "${PDF}" |fgrep 'Edition' |sed -E 's/^.*([1,2][0-9][0-9][0-9]).*$/\1/' >> "$(basename ${PDF} .pdf).txt"; done
```

Verify that each text file now has three lines.
```
wc -l *.txt |grep -E '^[[:space:]]+[1-2]'
```

Run `file *.txt` and verify that all files are plain ASCII. Often, some UTF-8 typographical apostrophes slip through, and will cause errors when running the eventual SQL `UPDATE` statements.

Now, transform the files into SQL statements.
```
for FILE in *.txt; do sed -E -e "s/'/''/g" -e "1s/^(.*)$/UPDATE ibmdocpf SET title='\1',/" -e "2s/^(.*)$/subtitle='\1',/" -e "3s/^([0-9]{4})$/released=\1 WHERE docnbr='$(basename ${FILE} .txt)';/" ${FILE}; done |grep -v "^subtitle='',$" |fold > /tmp/sqldoit.txt
```

For the following upload, and `runsqlstm` command to succeed, it's crucial to know the maximum line length of the input data. By default, this is 92 chars for source PFs, and 80 for *runsqlstm*. From experience, this is not sufficient for some PDFs with very long titles.
```
crtsrcpf file(sqlstm) rcdlen(132)
```

Upload the file into the created file.
```
printf "ascii\nput /tmp/sqldoit.txt ibmdocs/sqlstm.sqldoit\n" |ftp as400
```

Run the import as batch job.
```
sbmjob cmd(runsqlstm srcfile(ibmdocs/sqlstm) srcmbr(sqldoit) commit(*none) dftrdbcol(ibmdocs)) job(updibmdoc)
```

----
2025-10-18 poc@pocnet.net
