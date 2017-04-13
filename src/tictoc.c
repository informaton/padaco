#include "tictoc.h"
void tic(){
    tic_startTime = time(NULL);
}

/* Returns difference between start and stop times in seconds. */
double toc(){
    tic_stopTime = time(NULL);
    return difftime(tic_stopTime,tic_startTime);
}

double printToc(){
    double tocValue = toc();
    fprintf(stdout,"%0.2lf seconds elapsed.\n",tocValue);
    return tocValue;
}
