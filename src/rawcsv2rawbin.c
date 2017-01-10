// gcc rawcsv2rawbin.c rawtools.c tictoc.c -o rawcsv2rawbin
#include "rawtools.h"
#include "tictoc.h"
void printUsage(char * programName){
    fprintf(stdout,"Usage: %s <raw accelerations .csv filename> <raw accelerations .bin filename>\n",programName);   
}

int main(int argc, char * argv[]){
    bool shouldPrintUsage = true;
    
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