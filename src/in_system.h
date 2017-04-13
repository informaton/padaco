//
//  in_system.h
//
//
//  Created by InformaTon on 1/18/17.
//
//


#ifndef in_system_h
#define in_system_h

#include <stdbool.h>
#include <sys/stat.h>  // To check if we are working with regular files or directory Ref: http://pubs.opengroup.org/onlinepubs/009604499/basedefs/sys/stat.h.html
#include <dirent.h> // see http://stackoverflow.com/questions/612097/how-can-i-get-the-list-of-files-in-a-directory-using-c-or-c

#include <stdio.h> // for fprintf
#include <stdlib.h> // for malloc
#include <string.h>
#include <stdarg.h> // For variable number of arguments to be accepted.  Ref:  https://www.tutorialspoint.com/cprogramming/c_variable_arguments.htm


typedef struct{
    char * pathname;
    char * basename;
    char * extension;
    char * filename; // basename + extension
    char * fullFilename; // pathname + filename

} in_file_struct, *in_file_structPtr; /* Type definitions new name goes here */

void printFileStruct(in_file_struct * in_fp);
char * getFullfilename(in_file_structPtr in_fp);
char * createFilename(char * basename, char * extension);

unsigned long fgetlinecount(FILE * fp);
unsigned int fgetlinecountSlow(FILE *fid);

in_file_structPtr getFileParts(char * fullFilename);
void changeFileExtension(in_file_struct* fileStructPtr,char * newExtension);
char * updateFilename(in_file_structPtr in_fp);
bool is_dir(char * possiblePath);

char * fullfile(char * path, char * base);
// char * filename(int, ...);



#endif /* in_system_h */
