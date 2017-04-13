// gcc rawcsv2rawbin.c in_system.c rawtools.c tictoc.c -o rawcsv2rawbin
#include "rawtools.h"
#include "tictoc.h"
#include "in_system.h"

void printUsage(char * programName){
    fprintf(stdout,"Usage: %s <raw accelerations .csv filename> <raw accelerations .bin filename>\n",programName);   
    fprintf(stdout,"Usage: %s <pathname containing raw .csv files> <pathname to place raw .bin files>\n",programName);
}

int main(int argc, char * argv[]){
    bool shouldPrintUsage = true;
    char * srcPathOrFile, *destPathOrFile, * srcPath, *destPath,*srcFilename, *destFilename;
    DIR * dir;
    struct dirent *entry;
    in_file_structPtr fileStructPtr;
    int fileCount = 0, skipCount=0;
    double timeElapsed=0;
    if(argc==3){
        srcPathOrFile = argv[1];
        destPathOrFile = argv[2];
        dir = opendir(srcPathOrFile);
        if(dir!=NULL){
            srcPath = srcPathOrFile;
            destPath = is_dir(destPathOrFile)?destPathOrFile:srcPath;
            // process files
            while((entry=readdir(dir))!=NULL){
                if(entry->d_type==DT_REG){ //http://www.gnu.org/software/libc/manual/html_node/Directory-Entries.html   Be careful here, because this is not defined on all systems.
                    srcFilename = fullfile(srcPath,entry->d_name);
                    
                    // make an in_file_struct in order to maninpulate the file extension and
                    // create our destination filename
                    fileStructPtr = getFileParts(srcFilename);
                
                    // skip files like '.DS_STORE'
                    if(strlen(fileStructPtr->basename)==0){
                        continue;
                    }
                    changeFileExtension(fileStructPtr,".bin");
                    //changeFilePath(fileStructPtr,destPath);
                    destFilename = fullfile(destPath,fileStructPtr->filename);
                    tic();
                    printf("%s --> %s\n",srcFilename,destFilename);                    
                    if(writeRaw2Bin(srcFilename,destFilename)){
                        printf("File %i completed (%s):\t",++fileCount,entry->d_name);
                    }
                    else{
                        printf("File %i failed to complete (%s):\t",++fileCount,entry->d_name);
                        skipCount++;
                    }
                    timeElapsed+=printToc();
                    free(srcFilename);
                    free(destFilename);
                }
            }
            printf("Files encountered:\t %u\n"
                    "Files skipped:\t %u\n"
                    "Total time:\t %0.2f minutes\n",
                    fileCount,skipCount,timeElapsed/60);
            closedir(dir);
            shouldPrintUsage = false;
        }
        else{
            tic();
            if(writeRaw2Bin(srcFilename=srcPathOrFile, destFilename=destPathOrFile)){
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
