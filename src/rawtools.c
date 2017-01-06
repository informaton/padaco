#include <stdbool.h>
#include "rawtools.h"

void parseFileHeader(FILE * fid, csv_header_t *header){
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

// This is the C only version.
float * parseRawCSVFile(const char * csvFilename, csv_header_t* fileHeader,bool loadFastOption){
    
 	unsigned int i, linesRead = 0, curRead = 0;
 	const int lineSize = 100;
 	char buffer[lineSize];
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
	
	parseFileHeader(fid,fileHeader);
	
	printf("Sample rate is %u\n",fileHeader->samplerate);
	printf("Duration: %f s\n",fileHeader->duration_sec);
    rowCount = fileHeader->duration_sec*(double)fileHeader->samplerate;
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

bool writeRaw2Bin(char * rawCSVFilename, char * rawBinFilename){
    bool loadFast = true;
    bool didWrite = false;
    csv_header_t csvFileHeader;
    FILE * binFID = NULL;
    float * accelerations = parseRawCSVFile(rawCSVFilename,&csvFileHeader,loadFast);
    if(accelerations==NULL){
        didWrite = false;
    }
    else{
        if((binFID=fopen(rawBinFilename,"wb")) == NULL){
            didWrite = false;
            fprintf(stderr,"Could not open file for writing: %s\n",rawBinFilename);
        }
        else{
            didWrite =  write2bin(binFID, &csvFileHeader, accelerations);
            fclose(binFID);
        }
    }
    return didWrite;
}


bool write2bin(FILE *fid, csv_header_t*csvFileHeader, float * data){
    bin_header_t binFileHeader;
    bool goodFile = fseek(fid,0,SEEK_SET); // https://www-s.acm.illinois.edu/webmonkeys/book/c_guide/2.12.html#fopen
    size_t elementsWritten = 0;
    if(!goodFile){
        return false;
    }
    
    binFileHeader.samplerate = csvFileHeader->samplerate;
    binFileHeader.startTime = csvFileHeader->start;
    binFileHeader.stopTime = csvFileHeader->stop;
    binFileHeader.firmware = csvFileHeader->firmware;
    binFileHeader.duration_sec = csvFileHeader->duration_sec;
    binFileHeader.num_signals = 3;
    binFileHeader.sz_per_signal = sizeof(float);
    binFileHeader.sz_remaining = binFileHeader.num_signals*binFileHeader.sz_per_signal*binFileHeader.samplerate*binFileHeader.duration_sec;
    if(fwrite(&binFileHeader,sizeof(binFileHeader),1,fid)!=1)
        return false;
    return fwrite(data,binFileHeader.sz_remaining,1,fid)==1;
}
