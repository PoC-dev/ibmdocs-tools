This is a collection of scripts and other files to ease handling my huge IBM Documents collection. The collection was once available via my [IBMDocs-Website](https://ibmdocs.pocnet.net). See this page for details why this sentence is in past tense.

All of this is really really special and I'm not sure if this is of real-world value to anyone but me. So far, the helper scripts have grown over time to a tangle and putting it into a repository will certainly help to consolidate "script here, script there, step-by-step guide somewhere else to a single directory.

Same goes for the separate documentation for special-purpose topics. They've started as a checklist/reminder of sorts. I have reworked them to be more general-purpose instead of system-specific, and expanded them with more information to be hopefully of additional value to the reader.

**Please note**: The as400 subdirectory is not yet filled with "life", but this should happen very soon.

----
## License
This document is part of the IBM Documentation Utilities, to be found on [GitHub](https://github.com/PoC-dev/ibmdocs-tools) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

----
## Organization
### The documents list table
All documents (IBM proprietary *BOOK* and PDF formats) eventually end up in one directory, being named by the document number IBM is usually giving to them. There's a fair amount of PDF format documents without document numbers, not being part of the collection, yet. I have not yet decided how to deal with those.

The documents collection itself is referenced by an automatically generated single-page, huge HTML table. Content is meant to be searched with the web browser's built-in text search function. The table references an external file `doctable.css`, which must be made accessible accordingly.

The table features these fields:
- Document: Number, format, date added
- Title
- Released (year)
- Subtitle

The *Document*-column is somewhat special. The document number is always output. Depending on the available format, additional lines are generated:
- For *BOOK*s, the string `BOOK` is output as a link, followed by a more or less random 8 character string, and (optional) the date when this particular format for the document was added.
- For PDFs, the string `PDF` is output as a link, optionally followed by the date when this particular format for the document was added.

Documents without a date designation have been part of the collection since it exists. The "added" date was solely meant to help in seeing which new documents are available since when.

It's completely valid that some documents are available in both (IBM proprietary *BOOK* and PDF) formats.

#### Link destinations
Said page features links directly to available PDF documents, and to a locally installed [IBM BookManager BookServer 2.3](https://github.com/cyberdotgent/bookmgr-docker), in the first column. Unfortunately, the BookServer often opens the wrong file. Not sure how to deal with that. So far, this issue stays unsolved.

*BOOK* files usually have a DOS compatible file name (random 8 character string) to make them compatible to PC-DOS, MVS, and the OS/400 DLS. This string is also output in the first column to have quick access via other ways to view *BOOK* files. Particular options of interest are the old [AS/400 InfoSeeker](https://try-as400.pocnet.net/wiki/Reviving_InfoSeeker), and the [OS/390 based BookManager READ/MVS](os390-bookmgr-notes.md).

The HTML page is generated by a CGI program (written in C) designed to run on OS/400 under control of the [IBM http server for OS/400](https://try-as400.pocnet.net/wiki/IBM_HTTP-Server_for_AS/400_Configuration). On my model 150, this application runs for nearly two minutes, for 13,540 documents. So `ibmdoc-generate-index.sh` is provided to
- Save the long running CGI's output to a local file,
- fix owner/permissions for documents in that folder.

### The database
Multiple tables accomodate metadata for eventual creation of the index page already have been described above:
- *newdocspf* is meant to temporarily hold metadata from *BOOK* files manually being derived by following the directions described in [books-prepare.md](books-prepare.md).
- *ibmdocpf* contains metadata which is agnostic to the document's type.
- *ibmdoctypf* contains metadata which is dependent on the document's type.

All tables primarily relate through the document number.

Along with data-holding files, there are some *logical files* providing different indexes compared to the data holding files.
- *docnbrlf* supports code to "duplicate" document metadata to an already existing (autogenerated) dummy record. This helps to reduce typing effort when handling different revisions of the same document.
- *ibmdocposl* is needed by the scrolling- and position-to logic in the maintenance application.
- *listdocslf* supports the CGI and outputs only "valid" records, ordered by document title. "Valid" means, records which feature 1960 as year of release are assumed to have been automatically inserted by `ibmdoc-db-lint.pl` and not (yet) manually complemented with metadata.

DDS descriptions are found in the as400 subdirectory.

### The maintenance application
This is a text-based full-screen application derived from parts of my [German language AS/400 Subfile Template](https://github.com/PoC-dev/as400-sfltemplates-german). It was initially thought as primary means to manually enter metadata for documents.

Code is (soon to be) found in the as400 subdirectory.

----
## Files
A short explanation of the files (and directories) contained in this repository, ordered by type and then alphabetically.

### Documentation
- [`books-prepare.md`](books-prepare.md) shows procedures to handle new *BOOK* files, especially large quantities of them.
- [`os390-bookmgr-notes.md`](os390-bookmgr-notes.md) shows procedures how to make available a large number of *BOOK*s to *BookManager/READ* MVS.

### Files
- *doctable.css* is included in the main HTML table page (documents list) and needs to be accessible to the browser when loading the page.

### Scripts
Scripts accessing the AS/400 database assume a configured and functioning ODBC connection.

- `ibmdoc-copy-unhandled-pdfs.pl` copies PDF files with empty description to a directory, e. g. in ones' home directory for inspection over e. g. a Samba share with the excellent Apple *Preview.app*.
- `ibmdoc-create-8char-links.pl` creates hard links from *BOOK* files (with the document number as file name) to another directory with DLS (DOS compatible) file names. Affiliation is checked by querying the doctype database table. It does no changes to the database, only to the destination directory in the file system. Part of `ibmdoc-merge-docs.pl` is doing the reverse.
- `ibmdoc-db-lint.pl` script verifies the mutual consistency of database content vs. available files in the file system. It creates new (dummy) records for every file in the file system not being listed in the database, deletes database entries not backed by a file in the file system, checks and deletes orphaned metadata entries without being backed by any document in the documents types table, and creates new (dummy) records for every in the documents types table not having a metadata entry.
- `ibmdoc-generate-index.sh` saves the long running CGI's output to a local file, and fixes owner/permissions for documents in that folder.
- `ibmdoc-list-exceptions.sh` is a helper script to quickly identify "wrong" files erroneously ended up in the documents directory. This applies mainly files not adhering to the IBM documents naming standard, plus some hard coded exceptions.
- `ibmdoc-merge-docs.pl` must be run as part of the procedures described in `books-prepare.md`. It copies database records from a table with separately collected metadata for new *BOOK* files, and creates hard links from the "incoming" directory to the documents directory. Filesystem-wise, `ibmdoc-create-8char-links.pl` is doing the reverse.

### Directories
- as400 contains the AS/400 specific database and screen definitions, along with program code for the maintenance application. There's a [`README.md`](as400/README.md) specifically dealing with the files in there.

----
## Workflows
How to handle incoming documents with the facilities provided through this repository.

### PDFs
PDFs usually - for me - come in in small quantities, and not very often, so handling those is largely a manual process:
- open PDF documents and locate the document number
- copy/rename PDFs to the documents directory, with the document number as file name
- run `ibmdoc-db-lint.pl`, so dummy records for metadata will be created along with type records for PDFs with the current date as "date added"
- open PDF documents and manually enter found metadata (title, year released, subtitle if applicable) via the maintenance application for OS/400
- run `ibmdoc-generate-index.sh` to generate the index page

### *BOOK*s
This process is complex. See [books-prepare.md](books-prepare.md).

----
2023-08-27 poc@pocnet.net
