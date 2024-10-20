/*
 * Copyright 2021-2024 Patrik Schindler <poc@pocnet.net>.
 *
 * Licensing terms.
 * This is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 2 of the License, or (at your option) any later
 * version.
 *
 * It is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
 * Suite 330, Boston, MA  02111-1307  USA or get it at
 * http://www.gnu.org/licenses/gpl.html
 *
 * Access with:
 * http://nibbler.pocnet.net/cgi-bin/listdocs
 * - Do not add .PGM suffix
 *
 * Compile with Option 14 + additional: PGM(CGIBIN/LISTDOCS) OPTIMIZE(*FULL)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
/* https://www.ibm.com/docs/en/rdfi/9.6.0?topic=files-recioh */
#include <recio.h>
#include <unistd.h>
#include <qp0ztrc.h>

/* Files ---------------------------------------------------------------------*/

/* Important! This statement is about the compiled object, not the source! */
#pragma mapinc("LISTDOCSLF", "IBMDOCS/LISTDOCSLF(CGITBL)", "input", "_P", "")
#include "LISTDOCSLF"
#define _DOCSRECSZ sizeof(docs_data)
#pragma mapinc("IBMDOCTYPF", "IBMDOCS/IBMDOCTYPF(DOCTYPTBL)", "input", "_P", "")
#include "IBMDOCTYPF"
#define _TYPERECSZ sizeof(type_data)

/* Defines -------------------------------------------------------------------*/

int exit_flag;

/* Actual Code ---------------------------------------------------------------*/

/* Send a message to the job log, and then exit with error. ------------------*/

void die(char *s) {
    Qp0zLprintf("%s: %s\n", s, strerror(errno));
    exit(1);
}

/* Zero-terminate fixed-length strings. --------------------------------------*/

/* Note: This code assumes that we always have at least one position left
 *       to properly zero-terminate the string! Ugly but spares us the need
 *       to copy the data to a bigger buffer beforehand.
 * Note: This code changes data in the original buffer!
 */

char *fixstr(char *buf, int length) {
	int i;

    /* Iterate through the buffer from right to left, and
     *  set position next to the first non-blank to NUL.
     */
    for (i = (length - 1); i >= 0; i--) {
        if ( buf[i] != ' ' ) {
            buf[i+1] = 0x0;
            break;
        }
    }

    /* Safety measure: Set the last position to NUL in any case.
     * This might have us lose a character but is an indication of the buffer
     * being too small.
     */
    buf[length-1] = 0x0;

	return(buf);
}

/* Main. ---------------------------------------------------------------------*/

int main(int argc, char *argv[]) {
	_RFILE *docs_fp, *type_fp;
	_RIOFB_T *docs_rfb, *type_rfb;
	IBMDOCS_LISTDOCSLF_CGITBL_i_t docs_data;
	IBMDOCS_IBMDOCTYPF_DOCTYPTBL_i_t type_data;
	unsigned int errcount=0, loopcnt, keylen;


	/* Prepare HTML headings and other necessary stuff. */
	printf("Content-type: text/html\n\n");
	printf("<!DOCTYPE HTML>\n");
	printf("<html>\n<head>\n\t<title>IBM Documents List</title>\n");
	printf("\t<meta name=\"author\" content=\"Patrik Schindler\">\n");
	printf("\t<meta http-equiv=\"content-type\" content=\"text/html;");
    printf(" charset=iso-8859-1\">\n");
	printf("\t<link rel=\"stylesheet\" type=\"text/css\"");
    printf(" href=\"doctable.css\">\n");
	printf("</head>\n\n");
	printf("<body bgcolor=\"#FFFFFF\" link=\"#333399\" vlink=\"#333399\"");
    printf(" alink=\"#333399\">\n");

	/* Open file only with updating the number of read bytes in _RIOFB_T */
	if (( docs_fp = _Ropen ("IBMDOCS/LISTDOCSLF", "rr, blkrcd=y, nullcap=y, \
            riofb=n")) == NULL) {
		perror("Error opening file:");
		printf("<p>\n");
		errcount++;
	}
	if (( type_fp = _Ropen ("IBMDOCS/IBMDOCTYPF", "rr, blkrcd=y, nullcap=y, \
            riofb=n")) == NULL) {
		perror("Error opening file:");
		printf("<p>\n");
		errcount++;
	}

	/* Continue if no error happened so far. */
	if ( errcount == 0 ) {
		/* Output Table Headings. */
		printf("<table>\n");
		printf("<colgroup><col class=\"docnbr\" /><col class=\"titles\" />");
        printf("<col class=\"year\" /><col class=\"titles\" /></colgroup>\n");
		printf("<tr><th>Document:<br>Number, format, date added</th>");
        printf("<th>Title</th>");
		printf("<th>Released</th><th>Subtitle</th></tr>\n");

		/* Outer loop: Read document, title, etc. */
		while ( 0 == 0 ) {
			docs_rfb = _Rreadn(docs_fp, &docs_data, _DOCSRECSZ, __DFT);
			/* Crude EOF Check. */
			if (( docs_rfb->num_bytes == EOF )) {
				break;
			} else if (( docs_rfb->num_bytes < _DOCSRECSZ )) {
                printf(" <!-- Error: %s in outer loop -->\n",
                    strerror(errno));
				break;
			}
			printf("<tr>");

			/* Need to fix this just once,
             * because we change the original buffer.
            */
			printf("<td><b>%s</b><ul>", fixstr(docs_data.DOCNBR, 18));

			/* Required for _Rreadk(). */
			keylen = strlen(docs_data.DOCNBR);

			loopcnt = 0;
			/* Inner loop: Lookup document type(s) for the given document id. */
			while ( exit_flag == 0 ) {
				if ( loopcnt == 0 ) {
					/* If this is our first iteration, do a CHAIN. */
					type_rfb = _Rreadk(type_fp, &type_data, _TYPERECSZ, __DFT,
                        docs_data.DOCNBR, keylen);
				} else {
					/* If we already CHAINed, now use READE. */
					type_rfb = _Rreadk(type_fp, &type_data, _TYPERECSZ,
                        __KEY_NEXTEQ, "", keylen);
				}

				/* Crude EOF Check. */
				if (( type_rfb->num_bytes == EOF ||
                        type_rfb->num_bytes < _TYPERECSZ )) {
					break;
				}

				/* Output document type according to the type flags. */
				if ( (strncmp(type_data.DOCTYPE, "B", 1) == 0) ) {
					printf("<li><a href=\
\"/bookmgr/bookmgr.cgi/BOOKS/%s/CCONTENTS\" target=\"_blank\">BOOK</a>",
                        docs_data.DOCNBR);

                    fixstr(type_data.DLSNAME, 10);

                    if ( strlen(type_data.DLSNAME) > 0 ) {
                        printf(" (%s)", type_data.DLSNAME);
                    }

				} else if ( (strncmp(type_data.DOCTYPE, "P", 1) == 0) ) {
					printf("<li><a href=\"%s.pdf\">PDF</a>",
                        docs_data.DOCNBR);
				}
			
				/* Field is NULL. FIXME: We should check this properly. */
				if ( strncmp(fixstr(type_data.DATE_ADDED, 10), "0001-01-01",
                        10) != 0 ) {
					printf(" (%s)", type_data.DATE_ADDED);
				}

				loopcnt++;
			}
			printf("</ul></td>");

			/* Output remaining data (title, etc.). */
			printf("<td>%s</td>", fixstr(docs_data.TITLE, 180));
			printf("<td>%d</td>", docs_data.RELEASED);
			printf("<td>%s</td>", fixstr(docs_data.SUBTITLE, 180));

			printf("</tr>\n");
		}
		printf("</table><p>\n");
		_Rclose(type_fp);
		_Rclose(docs_fp);
	}
	printf("Documents provided have been obtained from the sunsetted IBM \
public document library server, and other sources. They are replicated \
here as a convenient place to find IBM documentation for mostly older \
products. Copyrights are retained as outlined in the individual \
documents.<p>\n");
	printf("Thanks to my Dad, Iain, and his Mom for helping with providing \
content for the initial index table. Thanks to the Bitsavers project for \
its incredible service to the community!<p>\n");
	printf("You can read BOOK files with the aid of the \
<a href=\"https://leela.pocnet.net/bookmgr/bookmgr.cgi\">IBM BookManager \
BookServer</a>. The raw components are available on \
<a href=\"https://github.com/cyberdotgent/bookmgr-docker\">GitHub</a>.<p>\n");
	printf("Contact me: \
<a href=\"mailto:webhamster@pocnet.net\">webhamster@pocnet.net</a>\n");
	printf("Program version 2023-08-26.<p>\n</body>\n</html>\n");
	return(0);
}

/* -----------------------------------------------------------------------------
 * vim: ft=c colorcolumn=81 autoindent shiftwidth=4 tabstop=4 expandtab
 */
