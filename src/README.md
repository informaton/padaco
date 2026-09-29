# Native helpers

This directory contains an Actigraph raw CSV-to-binary converter and legacy MATLAB MEX sources. Run the build commands below from `src/`.

## CSV-to-binary converter

`rawcsv2rawbin.c` provides the command-line entry point. It uses `rawtools.c` for data parsing and binary output, `in_system.c` for file and directory helpers, and `tictoc.c` for timing.

Build with a C compiler and POSIX system headers (for example, on macOS):

```sh
gcc rawcsv2rawbin.c in_system.c rawtools.c tictoc.c -o rawcsv2rawbin
```

Convert a single Actigraph raw CSV file:

```sh
./rawcsv2rawbin /path/to/recording.csv /path/to/recording.bin
```

Or convert a directory of input files into an existing output directory:

```sh
mkdir -p /path/to/output
./rawcsv2rawbin /path/to/input /path/to/output
```

Directory mode attempts to parse regular files, without filtering by extension. Use a directory containing only the intended raw CSV input files. If the output directory does not exist, the converter falls back to writing alongside the input files.

Running `./rawcsv2rawbin` without arguments prints usage and exits with a nonzero status.

Build verification: the command above compiled successfully with Apple's compiler via `gcc` on macOS on September 28, 2026. Existing warnings concern structure packing and a pointer comparison. The no-argument usage check was also verified; conversion with real sensor data was not tested.

## MATLAB MEX loader

`loadrawcsv.c` defines the MATLAB entry point; `loadraw.c` implements the matrix loader. Building a MEX file requires MATLAB and a supported C compiler configured with `mex -setup C`.

The historical command in the source comments is:

```matlab
mex loadrawcsv.c loadraw.c
```

This command needs source repairs before it can be used with the current checkout: `loadraw.c` refers to `header_t` and `parseFileHeader`, while `rawtools.h` declares `csv_header_t` and `parseCSVFileHeader`. The historical command also omits `rawtools.c`, which contains the CSV header parser. MATLAB was unavailable during this documentation update, so the MEX build and application startup were not verified.

Once a working MEX loader is available on the MATLAB path, its calling syntax is:

```matlab
data = loadrawcsv('/path/to/recording.csv');
accelerationAxes = loadrawcsv('/path/to/recording.csv', true);
```

The optional second argument selects the three acceleration axes only. The loader stores samples in columns; `PASensorData` transposes its result for row-oriented use.

The repository includes `loadrawcsv.mexmaci64` binaries for Intel macOS in both `src/` and `utility/`. `pathsetup` adds `utility/` to the application path. These binaries are platform-specific.

## Development programs

`testtools.c` is a manual development harness for the native helpers, and `test.c` is a separate graphics experiment. They are not an automated test suite.
