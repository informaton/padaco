#define HEADER_LINES 11 //number of lines to skip
#define NUM_COLUMNS 9
#define NUM_COLUMNS_FAST 3

#include <stdlib.h> // for malloc
#include <stdio.h>
#include <time.h>
#include <stdbool.h>
typedef struct csv_header_t {
	int samplerate;
	time_t start;
	time_t stop;
	char firmware[10];
	char serialID[20];
	double duration_sec;    
} csv_header_t;

typedef struct bin_header_t{
    uint8_t samplerate;
    time_t startTime;
    time_t stopTime;
	char firmware[10];
	char serialID[20];
	unsigned duration_sec:32;
    unsigned num_signals:8;
    unsigned sz_per_signal:8;
    unsigned sz_remaining:32;
} bin_header_t;

void parseFileHeader(FILE * fid, csv_header_t *header);
float * parseRawCSVFile(const char * csvFilename, csv_header_t *, bool);
bool write2bin(FILE *fid, csv_header_t*, float * data);
bool writeRaw2Bin(char * rawCSVFilename, char * rawBinFilename);