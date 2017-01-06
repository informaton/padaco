#include "matrix.h"
#include "mex.h"
#include <string.h>
#include "rawtools.h"

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
mxArray * mxParseRawCSVFile(const char * csvFilename, bool);



