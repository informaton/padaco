#define HEADER_LINES 11 //number of lines to skip
#define NUM_COLUMNS 9
#define NUM_COLUMNS_FAST 3
#define SZ_FIRMWARE 10
#define SZ_SERIALID 20

#pragma pack(1)  /* Do this to avoid padding being added to our fwrite struct blobs
                    Ref: http://stackoverflow.com/questions/3318410/pragma-pack-effect
                         http://www.catb.org/esr/structure-packing/
                */

#include <stdlib.h> // for malloc
#include <stdio.h>
#include <time.h>
#include <stdbool.h>
#include <string.h> // for strncpy
typedef struct csv_header_t {
	uint16_t samplerate;
	time_t start;
	time_t stop;
	char firmware[SZ_FIRMWARE];
	char serialID[SZ_SERIALID];
	double duration_sec;
} csv_header_t;



typedef struct bin_header_t{
    uint16_t samplerate;
    uint64_t startTime;
    uint64_t stopTime;
	char firmware[SZ_FIRMWARE];
	char serialID[SZ_SERIALID];
    double duration_sec;
    uint8_t num_signals;
    uint8_t sz_per_signal;
    uint64_t sz_remaining;
} bin_header_t;

float * parseRawBinFile(const char * binFilename, bin_header_t* fileHeader, unsigned int * recordCount);
bool parseBinaryFileHeader(FILE * fid, bin_header_t *header);
void parseCSVFileHeader(FILE * fid, csv_header_t *header);
float * parseRawCSVFile(const char * csvFilename, csv_header_t *, bool, unsigned int * rowCount);
bool write2bin(FILE *fid, csv_header_t*, float * data);
bool writeRaw2Bin(char * rawCSVFilename, char * rawBinFilename);

void printBinHeader(bin_header_t *binHeader);
