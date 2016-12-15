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
#define NUM_COLUMNS 9
#define NUM_COLUMNS_FAST 3

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

void parseFileHeader(FILE * fid, header_t *header){
	const int i=0,lineSize = 400;
 	char buffer[2][lineSize];
 	
 	struct tm startTime, stopTime;
    startTime.tm_isdst = 0;
    stopTime.tm_isdst = 0;
 	time_t startTimer, stopTimer;
	/*
		for(i=0;i<HEADER_LINES;i++){
			fscanf(fid,"%*[^\n]\n"); //ignore everything.
		}
	*/
	
	fgets(buffer[0],lineSize,fid);  //------------ Data File Created By ActiGraph GT3X+ ActiLife v6.11.8 Firmware v1.5.0 date format M/d/yyyy at 40 Hz  Filter Normal -----------
	fscanf(fid,"Serial Number: %s\n",header->serialID);  //Serial Number: MOS2B21140207
	fscanf(fid,"Start Time %u:%u:%u\n",&startTime.tm_hour, &startTime.tm_min,&startTime.tm_sec);  //Start Time 00:00:00
	fscanf(fid,"Start Date %u/%u/%u\n",&startTime.tm_mon, &startTime.tm_mday,&startTime.tm_year);  //Start Date 12/9/2015
	fgets(buffer[1],lineSize,fid);  //Epoch Period (hh:mm:ss) 00:00:00	
	fscanf(fid,"Download Time %u:%u:%u\n",&stopTime.tm_hour, &stopTime.tm_min,&stopTime.tm_sec);  //Download Time 10:07:01
	fscanf(fid,"Download Date %u/%u/%u\n",&stopTime.tm_mon, &stopTime.tm_mday,&stopTime.tm_year);  //Download Date 12/17/2015	 
	fgets(buffer[1],lineSize,fid);  //Current Memory Address: 0
	printf("%s\n",buffer[1]);
	fgets(buffer[1],lineSize,fid);  //Current Battery Voltage: 3.93     Mode = 12
	fgets(buffer[1],lineSize,fid);  //--------------------------------------------------
	fgets(buffer[1],lineSize,fid);  //Timestamp,Accelerometer X,Accelerometer Y,Accelerometer Z
	
	sscanf(buffer[0],"------------ Data File Created By ActiGraph GT3X+ ActiLife %*s Firmware %s date format M/d/yyyy at %d Hz",header->firmware,&header->samplerate);
	
	startTime.tm_mon-=1;
	startTime.tm_year-=1900;
	stopTime.tm_mon-=1;
	stopTime.tm_year-=1900;
	stopTimer = mktime(&stopTime);
	startTimer = mktime(&startTime);
	
	printf("Serial: %s\n",header->serialID);
	header->duration_sec = difftime(stopTimer,startTimer);
	
}

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



// This is the C only version.
float * parseRawCSVFile(const char * csvFilename, bool loadFastOption){
    
 	unsigned int i, linesRead = 0, curRead = 0;
 	const int lineSize = 100;
 	char buffer[lineSize]; 
 	header_t fileHeader;
    double rowCount;
    float *accelerations=NULL,
    	  *times=NULL,
    	  *days=NULL;
    FILE *fid= NULL;
    
    printf("Opening %s for reading.\n",csvFilename);
    
    fid = fopen(csvFilename,"r");
    if(fid==NULL){
        printf("Unable to open the csv file '%s'",csvFilename);
        return 0;
    }

	float x,y,z;
	char delimiter = ',';
	// header = 'Date	 Time	 Axis1	Axis2	Axis3
	//                        scanFormat = '//s //f32 //f32 //f32'; //load as a 'single' (not double) floating-point number
	
	parseFileHeader(fid,&fileHeader);
	
	printf("Sample rate is %u\n",fileHeader.samplerate);
	printf("Duration: %f s\n",fileHeader.duration_sec);
    rowCount = fileHeader.duration_sec*(double)fileHeader.samplerate;
	printf("Expected row count: %.0f\n",rowCount);
	
		// MATLAB fills in matrices column-wise first.
	if(loadFastOption){
		accelerations = malloc(NUM_COLUMNS_FAST*sizeof(float)*rowCount);
	}else{
		accelerations = malloc(NUM_COLUMNS*sizeof(float)*rowCount);
		times = malloc(NUM_COLUMNS*sizeof(float)*rowCount);
		days = malloc(NUM_COLUMNS*sizeof(float)*rowCount);
	}

    curRead = 0;
    if(loadFastOption){
		while(!feof(fid)){	
			fscanf(fid,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",(accelerations+curRead),(accelerations+curRead+1),(accelerations+curRead+2));
			curRead+=NUM_COLUMNS_FAST;
		}
    }
    else{
		while(!feof(fid)){	
			// fscanf(fid,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",&x,&y,&z);

		
			fscanf(fid,"%f/%f/%f %f:%f:%f,%f,%f,%f",
					(days+curRead),days+curRead+1,days+curRead+2,
					(times+curRead),times+curRead+1,times+curRead+2,
					(accelerations+curRead),accelerations+curRead+1,accelerations+curRead+2);

			//fscanf(fid,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",(accelerations+curRead),accelerations+curRead+1,accelerations+curRead+2);
			curRead+=3;
			//fgets(buffer,lineSize,fid);
			//		sscanf(buffer,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",&x,&y,&z);
			//	printf("%0.3f,%0.3f,%.3f\n",x,y,z);
		}
	}	
    
    // wrap things up
    fclose(fid); 
    
    return accelerations;
}


/*
void setIsdst(header_t * headerStruct, int isdst);
void setIsdst(header_t * headerStruct, int isdst){		
	headerStruct->start.tm_isdst = isdst; //daylight savings is not in effect = 0;
	headerStruct->stop.tm_isdst = isdst;
}
*/

    