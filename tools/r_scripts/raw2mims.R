# Enusre we have necessary mims package for the conversion.

# Kudos to Henry - https://stackoverflow.com/questions/9341635/check-for-installed-packages-before-running-install-packages
mimsPackageName <- "MIMSunit"
if(mimsPackageName %in% rownames(installed.packages()) == FALSE) {
  # install.packages(mimsPackageName)  
  # remove.packages(mimsPackageName)
  if(!require(devtools)) install.packages("devtools")
  repo = paste('informaton', mimsPackageName, sep='/')
  devtools::install_github(repo=repo)
}

##source('/Users/known/git/MIMSunit/R/mims_unit.R')
##source('/Users/known/git/MIMSunit/R/import_data.R')

library(mimsPackageName, character.only=TRUE)
# library(mimsPackageName, character.only = TRUE, lib.loc = '/Users/known/git/MIMSunit')
# Setup for parallel use
if(!require(doParallel)) install.packages("doParallel")
library(doParallel)

isormkdir <- function(path) {
  if (!dir.exists(path)){
    dir.create(path, recursive = TRUE)
  }
  return(dir.exists(path))
}

ext_pattern <- function(ext){
  return(paste('\\.',ext, sep=''))
}

raw2mims <- function(raw_file, raw_pathname, mims_pathname){
  mims_file = file.path(mims_pathname, paste(tools::file_path_sans_ext(raw_file),'.', mims_ext, sep=''))
  cat(raw_file) #, fill = TRUE)
  
  if(file.exists(mims_file) & !SKIP_EXISTING_OUTPUT){
    cat(' - SKIPPING.  Conversion file exists:',mims_file)  
  }
  else{
    cat(' - Converting ...')
    # Obtain the mims value on a per second peoch
    full_raw_filename = file.path(raw_pathname, raw_file)
    has_timestamp = FALSE # this is the case for files on Sherlock
    elapsed_sec = system.time(mims_sec<-mims_unit_from_files(full_raw_filename, epoch="1 sec", dynamic_range=c(-6,6), file_type="actigraph", output_mims_per_axis=TRUE, has_ts=FALSE, use_gui_progress=FALSE))[3]
    cat(' done - ',elapsed_sec/60,'minutes elapsed.  Exporting to', mims_file)
    # Write to a .csv
    elapsed_sec = system.time(write.csv(mims_sec, mims_file, row.names = FALSE))[3]
    cat(' done - ',elapsed_sec/60, 'minutes elapsed.')
  }
  cat(fill = TRUE)
}

# https://stackoverflow.com/questions/1608130/equivalent-of-throw-in-r
# help(tryCatch)
# ?list.files
# ?dir

raw_pathname = '/Volumes/Accel/t_1/raw'
mims_pathname = '/Volumes/Accel/t_1/mims'

raw_pathname = '/Volumes/accel/t_1/no_ts_split_studies'
mims_pathname = '/Volumes/accel/t_1/no_ts_split_studies/mims'

scratch_raw_pathname = '/scratch/users/hyatt4/goals_0'
scratch_mims_pathname= '/scratch/users/hyatt4/goals_0/mims'

# raw_pathname = scratch_raw_pathname
# mims_pathname = scratch_mims_pathname

raw_ext = 'csv'
mims_ext = 'mims'

SKIP_EXISTING_OUTPUT = TRUE

# Verify that we have input and output paths available
stopifnot(dir.exists(raw_pathname))
stopifnot(isormkdir(mims_pathname))

raw_files = list.files(path = raw_pathname, pattern = ext_pattern(raw_ext))
mims_files = list.files(path = mims_pathname, pattern = ext_pattern(mims_ext))

cat(length(raw_files),raw_ext, 'files found in', raw_pathname,fill = TRUE)

USE_PARALLEL = FALSE
if(USE_PARALLEL){
  numCores = Sys.getenv("SLURM_NTASKS_PER_NODE")
  numCores = 4
  registerDoParallel(cores=(numCores))
  parallel_time <- system.time(
    foreach(i = 1:length(raw_files), .combine=cbind) %dopar% {
      raw2mims(raw_file[i], raw_pathname, mims_pathname)
    })[3]
  
  cat('going parallel')
  # show the number of parallel workers to be used
  getDoParWorkers()
  parallel_time
  
}else{
  for(raw_file in raw_files){
    raw2mims(raw_file, raw_pathname, mims_pathname)
  }
}

#  if(raw_file %in% raw_files){  # https://stackoverflow.com/questions/1169248/test-if-a-vector-contains-a-given-element
#    cat('fil')
#  }

# mimsOutfile = paste(tools::file_path_sans_ext(rawFilename),'.mims', sep='')