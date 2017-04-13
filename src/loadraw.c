// See loadrawcsv.c for build instructions.

// build object file:  gcc -Wall  loadraw.c libmx.dylib libmex.dylib -I/Applications/MATLAB/MATLAB_Runtime/v90/extern/include -L /Applications/MATLAB/MATLAB_Runtime/v90/bin/maci64 -o loadraw
// gcc -Wall  loadraw.c -llibmx.dylib -llibmex.dylib -I/Applications/MATLAB/MATLAB_Runtime/v90/extern/include -o loadraw
// http://www.cprogramming.com/tutorial/shared-libraries-linux-gcc.html
//																										/Applications/MATLAB/MATLAB_Runtime/v90/bin/maci64

// Testing
// 1.  Uncomment main() function below.
// 2.  Compile with gcc
// 3.  Run ./loadraw ~/Data/GOALS/700073t00c1.raw

#include "loadraw.h"

/*
int main(){
	unsigned int numLines = 0;
    clock_t startClock, stopClock;
    const char * csvFilename = "/Users/unknown/Data/GOALS/sample_user_test/2015_12_17/csv/raw/MOS2B21140207RAW.csv";
    printf("preparing to load %s\n",csvFilename);
    
    startClock = clock();
    //mxArray * px = mxParseRawCSVFile(csvFilename, true);
    float * px = parseRawCSVFile(csvFilename, true);
    
    stopClock = clock();
    //printf("Lines read: %u\n",numLines);
    printf("Time elapsed: %f s\n",(float)(stopClock-startClock)/CLOCKS_PER_SEC);
    
    return 0;    
}
*/


mxArray * mxParseRawCSVFile(const char * csvFilename, bool loadFastOption){
    
 	unsigned int linesRead = 0, curRead = 0;
 	const int lineSize = 100;
 	char buffer[lineSize],delimiter = ',';
    const char * scanStr = "%f/%f/%f %f:%f:%f,%f,%f,%f";
    const char * fastScanStr = "%*f/%*f/%*f %*f:%*f:%*f,%f,%f,%f";
    const char *scanStrPtr = loadFastOption? fastScanStr: scanStr;
 	header_t fileHeader;
    double rowCount = 0;
    mxArray *accelerations, *rows = NULL;
    float * pointer = NULL;
	float month,day,year,hour,min,sec,x,y,z;
    FILE *fid = NULL;
    

    printf("Opening %s for reading.\n",csvFilename);
    
    fid = fopen(csvFilename,"r");
    if(fid==NULL){
        printf("Unable to open the csv file '%s'",csvFilename);
        return 0;
    }

	// header = 'Date	 Time	 Axis1	Axis2	Axis3
	//                        scanFormat = '//s //f32 //f32 //f32'; //load as a 'single' (not double) floating-point number
	
	parseFileHeader(fid,&fileHeader);
	
	printf("Sample rate is %u\n",fileHeader.samplerate);
	printf("Duration: %f s\n",fileHeader.duration_sec);
    rowCount = fileHeader.duration_sec*(double)fileHeader.samplerate;
	printf("Expected row count: %.0f\n",rowCount);
	
	// MATLAB fills in matrices column-wise first.
	if(loadFastOption){
		accelerations = mxCreateNumericMatrix(NUM_COLUMNS_FAST,rowCount,mxSINGLE_CLASS,mxREAL);
	}else{
		accelerations = mxCreateNumericMatrix(NUM_COLUMNS,rowCount,mxSINGLE_CLASS,mxREAL);
	}
	
    pointer = (float*)mxGetData(accelerations);
    
    printf("Starting while loop!\n");
    if(loadFastOption){
    	while(!feof(fid)){
			fscanf(fid,scanStrPtr,&x,&y,&z);
			if(!feof(fid)){
				pointer[curRead] = x;
				pointer[curRead+1] = y;
				pointer[curRead+2] = z;
				curRead+=NUM_COLUMNS_FAST;
			}
		}    
    }
    else{
    	while(!feof(fid)){
			fscanf(fid,scanStrPtr,&month,&day,&year,&hour,&min,&sec,&x,&y,&z);
			if(!feof(fid)){
				pointer[curRead+0] = month;
				pointer[curRead+1] = day;
				pointer[curRead+2] = year;
				pointer[curRead+3] = hour;
				pointer[curRead+4] = min;
				pointer[curRead+5] = sec;
				pointer[curRead+6] = x;
				pointer[curRead+7] = y;
				pointer[curRead+8] = z;
				curRead+=NUM_COLUMNS;
			}
		}
    
    
    }
/*
        fscanf(fid,"%f/%f/%f %f:%f:%f,%f,%f,%f",
                &rows_ptr[linesRead][0],&rows_ptr[linesRead][1],&rows_ptr[linesRead][2],
                &rows_ptr[linesRead][3],&rows_ptr[linesRead][4],&rows_ptr[linesRead][5],
                &rows_ptr[linesRead][6],&rows_ptr[linesRead][7],&rows_ptr[linesRead][8]);
        linesRead++;
*/
        //fscanf(fid,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",&pointer[linesRead][0],&pointer[linesRead][1],&pointer[linesRead][2]);
        //		linesRead++;
	//}
    
    // wrap things up
    fclose(fid);
    //     printf("Finished!\n");
    //     printf("Read %d lines\n",linesRead);
    return accelerations;
}



/*
void setIsdst(header_t * headerStruct, int isdst);
void setIsdst(header_t * headerStruct, int isdst){		
	headerStruct->start.tm_isdst = isdst; //daylight savings is not in effect = 0;
	headerStruct->stop.tm_isdst = isdst;
}
*/

    