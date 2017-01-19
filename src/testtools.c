// gcc testtools.c rawtools.c tictoc.c -o rawcsv2rawbin
// gcc -std=iso9899:1990 -pedantic testtools.c rawtools.c tictoc.c -o testtools
#include "rawtools.h"
#include "tictoc.h"
#include "in_system.h"

void printUsage(char * programName){
    //fprintf(stdout,"Usage: %s <raw accelerations .csv filename> <raw accelerations .bin filename>\n",programName);   
}

void testFileparts(char * filename){
    printFileStruct(getFileParts(filename));    
}



int main(int argc, char * argv[]){
    bool shouldPrintUsage = true;
    float * accelData = NULL;
    bin_header_t binHeader;
    unsigned int recordCount = 0;
    fprintf(stdout,"sizeof(time_t)=%lu\n"
            "sizeof(unsigned long)=%lu\n",sizeof(time_t),sizeof(unsigned long));
    if(argc==2){
        tic();
        tic();
        
        accelData = parseRawBinFile(argv[1], &binHeader, &recordCount);
        if(accelData==NULL){
            fprintf(stderr,"FAIL\n");
        }
        else{
            printToc();
            printBinHeader(&binHeader);
            shouldPrintUsage = false;
        }        
    }
    else
        if(argc==3){
            tic();
            if(writeRaw2Bin(argv[1],argv[2])){
                printToc();
                shouldPrintUsage = false;
            }
            else{
                fprintf(stderr,"FAIL\n");
            }
        }
    
    if(shouldPrintUsage){
        printUsage(argv[0]);
        return -1;
    }

    return 0;
}
