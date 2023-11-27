This directory contains a text-based full-screen application derived from parts of my [AS/400 Subfile Template](https://github.com/PoC-dev/as400-sfltemplates), and the accompanying table definitions for the script one directory up.

----
## License.
This document is part of the IBM Documentation Utilities, to be found on [GitHub](https://github.com/PoC-dev/ibmdocs-tools) - see there for further details. Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*.

----
## Introduction.

The application was initially thought as primary means to manually enter metadata for documents. Helper scripts running on Linux have superseded this functionality to some extent.

One notable helpful function is the handling of new document releases in regard to automatically generated template records in `ibmdocpf`. When adding metadata manually, we regularly encounter records with only a newer revision of a document but without a title. Yet, there are complete, older or newer records for the same document number, but a different revision.

Normally we must manually delete the "empty" record and duplicate the complete one, and write it with a different revision. This is cumbersome manual labour. The application helps this by checking if there is a record already existing with a given DOCNBR and `*BLANKs` in the title. Then it deletes that one, to prevent a primary key conflict. Afterwards, a new record is written.

Please note that the AS/400 UI is currently in German language only.

----
## Preparation.
For details regarding the handling/uploading of the files in this directory, please refer to the README of my above templates project. You need to
- create a library for the data: `crtlib ibmdocs` in a 5250 session,
- create a source physical file to contain the sources within said library: `crtsrcpf ibmdocs/sources rcdlen(112)` in a 5250 session,
- upload the files: `ftp as400-ip < ftpupload.txt` from your host, assumedly Linux.

**Note:** The applications rely on certain objects from the subfile templates mentioned before:
- the *genericsmsg* message file (for error message presentation),
- the menu includes in *qgpl/menuuim*.

Make sure you created those according to the instructions in the subfile template documentation.

----
## Compiling the AS/400 objects.
From a 5250 session, issue
```
chgcurlib ibmdocs
wrkmbrpdm *curlib/sources
```

There's a hierarchy of dependencies to observe. Thus, objects are to be compiled in a certain order depending on their type. In the list being shown, enter 14 into the OPT field on each line where the type matches, and press Enter to start the compile.

The order of types is:
1. PF
1. LF
1. DSPF
1. RPGLE

**Note:** The database layout and relationship is explained in the top level `README.md` of this project.

There is one source member left untreated yet, the *listdocs* CGI. Example compilation instructions are contained in the source member.

**Note:** Configuration instructions for the IBM http server are out of scope of this document. Refer to [IBM HTTP-Server for AS/400 Configuration](https://try-as400.pocnet.net/wiki/IBM_HTTP-Server_for_AS/400_Configuration) in my AS/400 Wiki.

----
## Journal the database tables for commitment control.
The two scripts *ibmdoc-db-lint.pl* and *ibmdoc-merge-docs.pl* are supposed to make changes to the database tables. Because things can go wrong and the scripts have not yet digested enough documents to really mature, I'm using commitment control to keep the database tables in a consistent state after an unexpected script termination.

Commitment control requires tables to be journaled. Create the journal related objects and start the journalling process.
```
crtjrnrcv jrnrcv(ibmdoc0001) threshold(5120)
crtjrn jrn(ibmdocjrn) jrnrcv(*curlib/ibmdoc0001) mngrcv(*system) dltrcv(*yes) rcvsizopt(*rmvintent)
strjrnpf file(*curlib/ibmdocpf *curlib/ibmdoctypf *curlib/newdocspf) jrn(*curlib/ibmdocjrn) omtjrne(*opnclo)
```
**Note:** The status of `strjrnpf` is retained between IPLs. This must be done just once.

## Use the applications.
At the moment, I do not provide a menu to run the applications. You can run them by `chgcurlib ibmdocs`, and
- `call ibmdocpg` to run the application for maintaining `ibmdocpf`,
- `call ibmdoctypg` to run the application for maintaining `ibmdoctypf`.

**Note:** Online help is not yet provided.

----
2023-11-27 poc@pocnet.net
