/*
 * Copyright (c) 2005 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#include "Archive.h"
#include "Depot.h"
#include "Utils.h"

#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>

void usage(char* progname) {
	fprintf(stderr, "usage:    %s [-v] [-p DIR] [command] [args]          \n", progname);
	fprintf(stderr, "                                                               \n");
	fprintf(stderr, "options:                                                       \n");
	fprintf(stderr, "          -p DIR     operate on roots under DIR (default: /)   \n");
	fprintf(stderr, "          -v         verbose (use -vv for extra verbosity)     \n");
	fprintf(stderr, "                                                               \n");
	fprintf(stderr, "commands:                                                      \n");
	fprintf(stderr, "          install    <path>                                    \n");
	fprintf(stderr, "          list                                                 \n");
	fprintf(stderr, "          files      <uuid>                                    \n");
	fprintf(stderr, "          uninstall  <uuid>                                    \n");
	fprintf(stderr, "          verify     <uuid>                                    \n");
	exit(1);
}

// our globals
uint32_t verbosity;

int main(int argc, char* argv[]) {
	char* progname = strdup(basename(argv[0]));      

	char* path;
	int custom_path = 0;

	int ch;
	while ((ch = getopt(argc, argv, "p:v")) != -1) {
		switch (ch) {
		case 'v':
			verbosity <<= 1;
			verbosity |= VERBOSE;
			break;
		case 'p':
		        if (strlen(optarg) > (PATH_MAX - 1)) {
			        fprintf(stderr, "Error: -p option value is too long \n");
				exit(3);
			}
			path = optarg;
			custom_path = 1;
			break;
		case '?':
		default:
			usage(progname);
		}
	}
	argc -= optind;
	argv += optind;

	int res = 0;

	if (!custom_path) {
		asprintf(&path, "/");
	}
	Depot* depot = new Depot(path);
	if (!depot->is_locked()) {
	        fprintf(stderr, 
			"Error: unable to access and lock %s. " \
			"The directory must exist and be writable.\n", depot->prefix());
		exit(2);
	}


	if (argc == 2 && strcmp(argv[0], "install") == 0) {
		char uuid[37];
		Archive* archive = ArchiveFactory(argv[1]);
		if (archive) {
			res = depot->install(archive);
			if (res == 0) {
				uuid_unparse_upper(archive->uuid(), uuid);
				fprintf(stdout, "%s\n", uuid);
			} else {
				fprintf(stderr, "An error occurred.\n");
				res = 1;
			}
		} else {
			fprintf(stderr, "Archive not found: %s\n", argv[1]);
		}
	} else if (argc == 1 && strcmp(argv[0], "list") == 0) {
		depot->list();
	} else if (argc == 1 && strcmp(argv[0], "dump") == 0) {
		depot->dump();
	} else if (argc == 2 && strcmp(argv[0], "files") == 0) {
		Archive* archive = depot->archive(argv[1]);
		if (archive) {
			res = depot->files(archive);
			delete archive;
		} else {
			fprintf(stderr, "Archive not found: %s\n", argv[1]);
			res = 1;
		}
	} else if (argc == 2 && strcmp(argv[0], "uninstall") == 0) {
		Archive* archive = depot->archive(argv[1]);
		if (archive) {
			res = depot->uninstall(archive);
			if (res != 0) {
				fprintf(stderr, "An error occurred.\n");
				res = 1;
			}
			delete archive;
		} else {
			fprintf(stderr, "Archive not found: %s\n", argv[1]);
			res = 1;
		}
	} else if (argc == 2 && strcmp(argv[0], "verify") == 0) {
		Archive* archive = depot->archive(argv[1]);
		if (archive) {
			res = depot->verify(archive);
			if (res != 0) {
				fprintf(stderr, "An error occurred.\n");
				res = 1;
			}
			delete archive;
		} else {
			fprintf(stderr, "Archive not found: %s\n", argv[1]);
			res = 1;
		}
	} else {
		usage(progname);
	}
	if (!custom_path) {
		free(path);
	}
	exit(res);
	return res;
}
