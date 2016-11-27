#include <stdlib.h> // for malloc
#include <stdio.h>
#include <time.h>
#include "matrix.h"

#define HEADER_LINES 11 //number of lines to skip

// ======================================================================
//> @brief Loads an accelerometer raw data file.  This function is
//> intended to be called from loadFile() to ensure that
//> loadCountFile is called in advance to guarantee that the auxialiary
//> sensor measurements are loaded into the object (obj).  The
//> auxialiary measures (e.g. lux, steps) are upsampled to the
//> sampling rate of the raw data (typically 40 Hz).
//> @param obj Instance of PAData.
//> @param fullRawCSVFilename The full (i.e. with path) filename for raw data to load.
// =================================================================

typedef struct header_t {

	int samplerate;
	time_t start;
	time_t stop;
	char firmware[10];
	char serialID[20];
	double duration_sec;    
} header_t;

void parseFileHeader(FILE * fid, header_t *header);
mxArray * mxParseRawCSVFile(const char * csvFilename);
float * parseRawCSVFile(const char * csvFilename);


