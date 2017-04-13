/*
 * loadrawcsv.c - load raw actigrap acceleration values from a .csv formated file.
 *
 *
 * The calling syntax is:
 *
 *		outMatrix = loadrawcsv(csvFilename)
 *
 * This is a MEX file for MATLAB.

 * Build instrctions using mex compiler:
 * mex loadrawcsv.c loadraw.c
 * testing: a=PAData('/Users/unknown/Data/GOALS/700073t00c1.raw');
 * tic;a=loadrawcsv('/Users/unknown/Data/GOALS/700073t00c1.raw');toc
 */

#include "mex.h"
#include "loadraw.h"
int main(){
    const char * csvFilename = "/Users/unknown/Data/GOALS/sample_user_test/2015_12_17/csv/raw/MOS2B21140207RAW.csv";
    
    return 0;    
}

//#include "mex.h"
//#include "matrix.h"

/* The gateway function */
void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    /* variable declarations here */
    char *csvFilename;
    mwSize buflen;  //or     size_t buflen; //but this requires casting to mwSize later
    int status;
    FILE *fid;
    bool loadFastOption = false;
    
    
    /* code here */
    if(nrhs < 1) {
        mexErrMsgIdAndTxt("PadacoToolbox:loadrawcsv:nrhs",
                "A single filename is required for input.");
    }
    
    if(nlhs != 1) {
        mexErrMsgIdAndTxt("PadacoToolbox:loadrawcsv:nrhs",
                "One output is required.");
    }
    if(nrhs==2){
        loadFastOption = (bool)mxGetScalar(prhs[1]);
    }
    
    /* Find out how long the input string is.  Allocate enough memory
     * to hold the converted string.  NOTE: MATLAB stores characters
     * as 2 byte Unicode ( 16 bit ASCII) on machines with multi-byte
     * character sets.  You should use mxChar to ensure enough space
     * is allocated to hold the string */

     /* Allocate enough memory to hold the converted string. */ 
     buflen = mxGetNumberOfElements(prhs[0]) + 1;
     csvFilename = mxCalloc(buflen, sizeof(mxChar));    // initialize to zero
    
     // Or this way:
     // buflen = mxGetN(prhs[0])*sizeof(mxChar)+1; // get number of columns.
     // buf = mxMalloc(buflen);  // allocate dynamic uninitialized memory.
    
     /* Copy the string data into csvFilename. */
     status = mxGetString(prhs[0], csvFilename, buflen);
     
     plhs[0] = mxParseRawCSVFile(csvFilename, loadFastOption);
     
     mxFree(csvFilename);

}

/*
// fid must not be NULL
mxArray * parseRawCSVFile(char * csvFilename){    
    FILE fid;
    mexPrintf("Opening //s for reading.\n",csvFilename);
    
    fid = fopen(csvFilename,"r");
    if(fid==NULL){
        mexPrintf("Unable to open the csv file '//s'",csvFilename);
        mexErrMsgIdAndTxt("PadacoToolbox:loadrawcsv:csvFilename",
                "Unable to open file for reading.");
    }
    // else    
    plhs[0] = parsefid(fid);
    
    // wrap things up
    fclose(fid);
    
}
*/

