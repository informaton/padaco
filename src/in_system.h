//
//  in_system.h
//  
//
//  Created by (unknown) on 1/18/17.
//
//


#ifndef in_system_h
#define in_system_h

#include <stdbool.h>
#include <sys/stat.h>  // To check if we are working with regular files or directory Ref: http://pubs.opengroup.org/onlinepubs/009604499/basedefs/sys/stat.h.html
#include <dirent.h> // see http://stackoverflow.com/questions/612097/how-can-i-get-the-list-of-files-in-a-directory-using-c-or-c

#include <stdarg.h> // For variable number of arguments to be accepted.  Ref:  https://www.tutorialspoint.com/cprogramming/c_variable_arguments.htm

const char PATH_SEPARATOR =
#ifdef WIN32
'\';
#else
'/';
#endif

typedef struct{
    char * pathname;
    char * basename;
    char * extension;
    char * fullFilename;
    
    char * getFullfilename(){
        
        
    }
    void printOut(){
        fprintf(stdout,"Pathname = %s\n
                        "Basename = %s\n"
                        "extension = %s\n"
                        "fullFilename = %s\n"
                "getFullfilename = %s", pathname, basename, extension, fullFilename,this.getFullfilename());
    }
    
} in_file_struct, *in_file_structPtr; /* Type definitions new name goes here */


in_file_structPtr getFileParts(char * fullFilename);
bool is_dir(char * possiblePath);
char * fullfile(char * path, char * base);

char * filename(int, ...);
















#endif /* in_system_h */
