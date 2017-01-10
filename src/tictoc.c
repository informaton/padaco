#include "tictoc.h"
void tic(){
    startTime = time(NULL);
}

// Returns difference between start and stop times in seconds.
double toc(){
    stopTime = time(NULL);
    return difftime(stopTime,startTime); 
}

void printToc(){
    fprintf(stdout,"%0.2lf seconds elapsed.\n",toc());
}