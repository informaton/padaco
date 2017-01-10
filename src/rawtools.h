#define HEADER_LINES 11 //number of lines to skip
#define NUM_COLUMNS 9
#define NUM_COLUMNS_FAST 3
#define SZ_FIRMWARE 10
#define SZ_SERIALID 20


#include <stdlib.h> // for malloc
#include <stdio.h>
#include <time.h>
#include <stdbool.h>
#include <string.h> // for strncpy
typedef struct csv_header_t {
	int samplerate;
	time_t start;
	time_t stop;
	char firmware[SZ_FIRMWARE];
	char serialID[SZ_SERIALID];
	double duration_sec;    
} csv_header_t;



typedef struct bin_header_t{
    uint16_t samplerate;
    time_t startTime;
    time_t stopTime;
	char firmware[10];
	char serialID[20];
	unsigned duration_sec:32;
    unsigned num_signals:8;
    unsigned sz_per_signal:8;
    unsigned sz_remaining:32;
} bin_header_t;

float * parseRawBinFile(const char * binFilename, bin_header_t* fileHeader, unsigned int * recordCount);
bool parseBinaryFileHeader(FILE * fid, bin_header_t *header);
void parseCSVFileHeader(FILE * fid, csv_header_t *header);
float * parseRawCSVFile(const char * csvFilename, csv_header_t *, bool, unsigned int * rowCount);
bool write2bin(FILE *fid, csv_header_t*, float * data);
bool writeRaw2Bin(char * rawCSVFilename, char * rawBinFilename);
