#include <stdbool.h>
#include "rawtools.h"
#include "in_system.h"


/***************
 *  Binary portion
 ***************/



// Reading
bool parseBinaryFileHeader(FILE * fid, bin_header_t *header){
    bool goodFile = fseek(fid,0,SEEK_SET)==0; // https://www-s.acm.illinois.edu/webmonkeys/book/c_guide/2.12.html#fopen
    // could also try rewind, but then I do not get a success or error code as rewind is a void function.  
    size_t elementsWritten = 0;
    if(!goodFile){
        fprintf(stderr,"Not a good file.\n");
        return false;
    }
    return fread(header,sizeof(bin_header_t),1,fid)==1;
}


// Expecting each record to contain three float values.
float * parseRawBinFile(const char * binFilename, bin_header_t* fileHeader, unsigned int * recordCount){
    unsigned int i, linesRead = 0, curRead = 0, actualRowCount = 0, expectedRowCount = 0;
    const int lineSize = 100;
    char buffer[lineSize];
    float *accelerations=NULL;// x, y, z floats
    FILE *fid= NULL;
    
    printf("Opening %s for reading.\n",binFilename);
    
    fid = fopen(binFilename,"rb");
    if(fid==NULL){
        printf("Unable to open the binary file '%s'",binFilename);
        return NULL;
    }
    
    // header = 'Date	 Time	 Axis1	Axis2	Axis3
    // scanFormat = '//s //f32 //f32 //f32'; //load as a 'single' (not double) floating-point number
    
    if(!parseBinaryFileHeader(fid,fileHeader)){
        fprintf(stderr,"Could not parse header information from %s\n",binFilename);
        fclose(fid);
        return NULL;
    }
    else{
        *recordCount = fileHeader->sz_remaining/3/sizeof(float);
        
        accelerations = malloc(fileHeader->sz_remaining);
        if(fread(accelerations,fileHeader->sz_remaining,1,fid)!=1){
            fprintf(stderr,"Expected number of records not found!  %s may be corrupted!\n",binFilename);
            *recordCount = 0;

        }
        else{
            *recordCount = fileHeader->sz_remaining/3/sizeof(float);
            fprintf(stdout,"Read %u records.\n",*recordCount);
            
        }
        
        fclose(fid);
        return accelerations;
    }
}


// Writing

// @brief Streams a .csv file of raw acceleration values to a binary file.
// @retval @c bool True on success; false otherwise
bool writeRaw2Bin(char * rawCSVFilename, char * rawBinFilename){
    bool loadFast = true;
    bool didWrite = false;
    csv_header_t csvFileHeader;
    FILE * binFID = NULL;
    unsigned int rowCount = 0;

    float * accelerations = parseRawCSVFile(rawCSVFilename,&csvFileHeader,loadFast, &rowCount);
    
    
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
        
        free(accelerations);
    }
    
    
    return didWrite;
}


bool write2bin(FILE *fid, csv_header_t*csvFileHeader, float * data){
    bin_header_t binFileHeader;
    bool goodFile = fseek(fid,0,SEEK_SET)==0; // https://www-s.acm.illinois.edu/webmonkeys/book/c_guide/2.12.html#fopen
    // could also try rewind, but then I do not get a success or error code as rewind is a void function.
    size_t elementsWritten = 0;
    if(!goodFile){
        fprintf(stderr,"Not a good file.\n");
        return false;
    }
    
    binFileHeader.samplerate = csvFileHeader->samplerate;
    strncpy(binFileHeader.startTimeStr,ctime(&csvFileHeader->start),SZ_TIME_STR);
    //binFileHeader.start_tm = *localtime(&csvFileHeader->start);
    //binFileHeader.start_tm = *localtime(&csvFileHeader->start);
    //binFileHeader.stopTime = csvFileHeader->stop;
    strncpy(binFileHeader.firmware,csvFileHeader->firmware,SZ_FIRMWARE);
    strncpy(binFileHeader.serialID,csvFileHeader->serialID,SZ_SERIALID);
    binFileHeader.duration_sec = csvFileHeader->duration_sec;
    binFileHeader.num_signals = 3;
    binFileHeader.sz_per_signal = sizeof(float);
    binFileHeader.sz_remaining = binFileHeader.num_signals*binFileHeader.sz_per_signal*binFileHeader.samplerate*binFileHeader.duration_sec;
    
    /*
    fprintf(stdout,"sizeof(binFileHeader)=%lu\n"
            "sizeof(bin_header_t)=%lu\n",sizeof(binFileHeader),sizeof(bin_header_t));
    
    fwrite(&(binFileHeader.samplerate),sizeof(binFileHeader.samplerate),1,fid);
    fprintf(stdout,"samplerate:%lu\n",ftell(fid));
    fwrite(&(binFileHeader.startTime),sizeof(binFileHeader.startTime),1,fid);
    fprintf(stdout,"startTime: %lu\n",ftell(fid));
    fwrite(&(binFileHeader.stopTime),sizeof(binFileHeader.stopTime),1,fid);
    fprintf(stdout,"stopTime: %lu\n",ftell(fid));
    fwrite(&(binFileHeader.firmware),sizeof(binFileHeader.firmware),1,fid);
    fprintf(stdout,"firmware: %lu\n",ftell(fid));
    fwrite(&(binFileHeader.serialID),sizeof(binFileHeader.serialID),1,fid);
    fprintf(stdout,"serialID: %lu\n",ftell(fid));
    
    */
    
    
    if(fwrite(&binFileHeader,sizeof(binFileHeader),1,fid)!=1){
        fprintf(stderr,"Incomplete streaming of binary file header.\n");
        return false;
    }
    
    if(fwrite(data,binFileHeader.sz_remaining,1,fid)==1){
        fprintf(stderr,"Finished streaming %llu bytes of binary data.\n",binFileHeader.sz_remaining);
        return true;
    }
    else{
        fprintf(stderr,"Incomplete streaming of binary data records (did not write all %llu bytes).\n",binFileHeader.sz_remaining);
        return false;
    }
}

/***************
 *  .csv portion
 ***************/
// Reading
void parseCSVFileHeader(FILE * fid, csv_header_t *header){
    
	const int i=0,lineSize = 400;
 	char buffer[2][lineSize];
 	
 	struct tm startTime, stopTime;
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
    
    //printf("Start Date %u/%u/%u\n",startTime.tm_mon, startTime.tm_mday,startTime.tm_year);  //

    fgets(buffer[1],lineSize,fid);  //Epoch Period (hh:mm:ss) 00:00:00
	fscanf(fid,"Download Time %u:%u:%u\n",&stopTime.tm_hour, &stopTime.tm_min,&stopTime.tm_sec);  //Download Time 10:07:01
	fscanf(fid,"Download Date %u/%u/%u\n",&stopTime.tm_mon, &stopTime.tm_mday,&stopTime.tm_year);  //Download Date 12/17/2015	 
	fgets(buffer[1],lineSize,fid);  //Current Memory Address: 0
	
    //printf("%s",buffer[1]);
	
    fgets(buffer[1],lineSize,fid);  //Current Battery Voltage: 3.93     Mode = 12
	//printf("%s",buffer[1]);
	fgets(buffer[1],lineSize,fid);  //--------------------------------------------------
	//printf("%s",buffer[1]);
	fgets(buffer[1],lineSize,fid);  //Timestamp,Accelerometer X,Accelerometer Y,Accelerometer Z
	//printf("%s",buffer[1]);
	
	sscanf(buffer[0],"------------ Data File Created By ActiGraph GT3X+ ActiLife %*s Firmware %s date format M/d/yyyy at %hu Hz",header->firmware,&header->samplerate);
    
    //fprintf(stdout,"ID: %s\nFirmware: %s\n",header->serialID,header->firmware);
    
    
	startTime.tm_mon-=1;
	startTime.tm_year-=1900;
	stopTime.tm_mon-=1;
	stopTime.tm_year-=1900;

    // daylight savings is unknown
    startTime.tm_isdst = -1;
    stopTime.tm_isdst = -1;
    
    startTimer = mktime(&startTime);
    stopTimer = mktime(&stopTime);

    /*
    printf("Start time: %s",asctime(&startTime));
    printf("Stop time: %s",asctime(&stopTime));
    
	printf("Start time: %s",asctime(localtime(&startTimer)));
	printf("Start time: %s %s",asctime(localtime(&startTimer)),asctime(localtime(&stopTimer)));
	printf("Serial: %s\n",header->serialID);
    */
    
    header->start = startTimer;
    header->stop = stopTimer;    
	header->duration_sec = difftime(stopTimer,startTimer);
    
}

// This is the C only version.
float * parseRawCSVFile(const char * csvFilename, csv_header_t* fileHeader,bool loadFastOption, unsigned int * recordCount){
    // struct tm *tmp_time;
 	unsigned int i, linesRead = 0, curRead = 0, actualRowCount = 0, expectedRowCount = 0, rowCount=0;
    unsigned long lineCountLeft = 0;
 	const int lineSize = 100;
 	char buffer[lineSize];
    float *accelerations=NULL,
    	  *times=NULL,
    	  *days=NULL;
    FILE *fid= NULL;
    float x,y,z;
    char delimiter = ',';
    
    printf("Opening %s for reading.\n",csvFilename);
    
    fid = fopen(csvFilename,"r");
    if(fid==NULL){
        printf("Unable to open the csv file '%s'",csvFilename);
        return 0;
    }
	
	parseCSVFileHeader(fid,fileHeader);
	
	/*
     printf("Sample rate is %u\n",fileHeader->samplerate);
     printf("Duration: %u s\n",fileHeader->duration_sec);
    */
    expectedRowCount = (unsigned int)fileHeader->duration_sec*fileHeader->samplerate;
	printf("Expected row count: %u\t",expectedRowCount);
    lineCountLeft =fgetlinecount(fid);
    printf("|\tLines found: %lu\t",lineCountLeft);
    expectedRowCount = expectedRowCount>lineCountLeft?expectedRowCount: lineCountLeft;  // returns the max of two values
    printf("|\tAllocating for %u rows\n", expectedRowCount);

	
		// MATLAB fills in matrices column-wise first.
	if(loadFastOption){
		accelerations = malloc(NUM_COLUMNS_FAST*sizeof(float)*expectedRowCount);
	}else{
		accelerations = malloc(NUM_COLUMNS*sizeof(float)*expectedRowCount);
		times = malloc(NUM_COLUMNS*sizeof(float)*expectedRowCount);
		days = malloc(NUM_COLUMNS*sizeof(float)*expectedRowCount);
	}

    curRead = 0;
    if(loadFastOption){
	/*	while(!feof(fid)){	
			fscanf(fid,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",(accelerations+curRead),(accelerations+curRead+1),(accelerations+curRead+2));
			curRead+=NUM_COLUMNS_FAST;
		}*/
        // added the rowCount++ check to make sure we don't read more data than we have buffered for.
        while((rowCount++ < expectedRowCount) &&
              EOF!=fscanf(fid,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",(accelerations+curRead),(accelerations+curRead+1),(accelerations+curRead+2)))
        {
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
			curRead+=NUM_COLUMNS_FAST;
			//fgets(buffer,lineSize,fid);
			//		sscanf(buffer,"%*2u/%*2u/%*4u %*2u:%*2u:%*f,%f,%f,%f",&x,&y,&z);
			//	printf("%0.3f,%0.3f,%.3f\n",x,y,z);
		}
    }
    
    // wrap things up
    fclose(fid); 
    actualRowCount = curRead/NUM_COLUMNS_FAST;
    *recordCount = actualRowCount;
    if(actualRowCount!=expectedRowCount){
        fprintf(stderr,"The CSV file, %s, may be corrupted: only %u of %u records found!\n",csvFilename,actualRowCount, expectedRowCount);
        fileHeader->duration_sec = actualRowCount/fileHeader->samplerate; /* Want this to be a whole number, so do not type cast */
        *recordCount = fileHeader->duration_sec*fileHeader->samplerate;  /* This will curtail any additional records beyond the 1-sec boundary */
        
        fprintf(stderr,"New duration seconds: %u\n",fileHeader->duration_sec);
        //tmp_time  = localtime(&fileHeader->start);
        //tmp_time->tm_sec+=fileHeader->duration_sec;
        //fileHeader->stop = mktime(tmp_time);
        fprintf(stderr,"New stop time caculated as: %s",ctime(&fileHeader->stop));
        //fprintf(stderr,"New stop time caculated as: %s\n",asctime(localtime(&fileHeader->stop)));
    }
    return accelerations;
}


/***************
 *  Utility methods
 ***************/


void printBinHeader(bin_header_t *binHeader)
{
    fprintf(stdout,"samplerate:\t%hu\n",binHeader->samplerate);
    //fprintf(stdout,"startTime:\t%llu\n",binHeader->startTime);
    //fprintf(stdout,"stopTime:\t%llu\n",binHeader->stopTime);
    fprintf(stdout,"firmware:\t%s\n",binHeader->firmware);
    fprintf(stdout,"serialID:\t%s\n",binHeader->serialID);
    fprintf(stdout,"duration_sec:\t%iu\n",binHeader->duration_sec);
    fprintf(stdout,"num_signals:\t%hhu\n",binHeader->num_signals);
    fprintf(stdout,"sz_per_signal:\t%hhu\n",binHeader->sz_per_signal);
    fprintf(stdout,"sz_remaining:\t%llu\n",binHeader->sz_remaining);
}

