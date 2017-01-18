// gcc rawcsv2rawbin.c rawtools.c tictoc.c -o rawcsv2rawbin
#include "rawtools.h"
#include "tictoc.h"
#include "in_system.h"

void printUsage(char * programName){
    fprintf(stdout,"Usage: %s <raw accelerations .csv filename> <raw accelerations .bin filename>\n",programName);   
    fprintf(stdout,"Usage: %s <pathname containing raw .csv files> <pathname to place raw .bin files>\n",programName);
}

int main(int argc, char * argv[]){
    bool shouldPrintUsage = true;
    DIR * dir;
    char * srcPath, *destPath;
    if(argc==3){
        dir = opendir(argv[1]);
        if(dir!=NULL){
            srcPath = argv[1];
            destPath = is_dir(argv[2])?argv[2]:argv[1]; 
            
            
        }
        else{
            tic();
            if(writeRaw2Bin(argv[1],argv[2])){
                printToc();
                shouldPrintUsage = false;
            }
            else{
                fprintf(stderr,"FAIL\n");
            }
        }
    }
    
    if(shouldPrintUsage){
        printUsage(argv[0]);
        return -1;
    }

    return 0;
}