// gcc rawcsv2bin.c rawtools.c -o rawcsv2rawbin
#include "rawtools.h"

void printUsage(char * programName){
    fprintf(stdout,"%s usage: \n",programName);
    
}

int main(int argc, char * argv[]){
    bool shouldPrintUsage = true;
    
    if(argc!=3)
        shouldPrintUsage = true;
    else{
        if((shouldPrintUsage = writeRaw2Bin(argv[1],argv[2]))==false){
            fprintf(stderr,"FAIL\n");
        }
    }
        
    
    if(shouldPrintUsage){
        printUsage(argv[0]);
        return -1;
    }

    return 0;
}