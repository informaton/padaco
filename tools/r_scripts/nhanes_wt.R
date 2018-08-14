# This function runs weartime detection using the NHANES algorithm
# We apply it to the 3 axes and the step counts
weartimeNHANESperMinute <- function(acc)
{
    # set up workspace
    library("accelerometry")
    
    # set number of seconds to be aggregated for nhanes analysis (60)
    nsec = 1 # this is is 1 minute intervals now already, so don't convert.

    # convert the accelerometry data to 1 minute intervals
    nhanes = data.frame(
    X = convertNHANES(acc, 'Axis1', nsec, 1),
    Y = convertNHANES(acc, 'Axis2', nsec, 1),
    Z = convertNHANES(acc, 'Axis3', nsec, 1),
    steps = convertNHANES(acc, 'Steps', nsec, 1))

    # detect the weartime using the nhanes algorithm

    nhanes$weartimeX <- accel.weartime(nhanes$X, window = 60, tol = 2, tol.upper=100, nci = TRUE, days.distinct = FALSE, skipchecks=FALSE)
    nhanes$weartimeY <- accel.weartime(nhanes$Y, window = 60, tol = 2, tol.upper=100, nci = TRUE, days.distinct = FALSE, skipchecks=FALSE)
    nhanes$weartimeZ <- accel.weartime(nhanes$Z, window = 60, tol = 2, tol.upper=100, nci = TRUE, days.distinct = FALSE, skipchecks=FALSE)
    nhanes$weartimeS <- accel.weartime(nhanes$step, window = 60, tol = 2, tol.upper=100, nci = TRUE, days.distinct = FALSE, skipchecks=FALSE)

    # compute the daily physical activity
    #dailyPA <- accel.process.tri(counts.tri = nhanes[, 1:3], steps = nhanes[, 4], Nci.methods=TRUE)

	# This was uncommented, but nci=TRUE has no meaning here.  
	#    dailyPA <- accel.process.tri(counts.tri = nhanes[, 1:3], steps = nhanes[, 4], nci = TRUE)
	# 	dailyPA <- accel.process.tri(counts.tri = nhanes[, 1:3], steps = nhanes[, 4], nci = TRUE, nonwear.tol = 2);
	dailyPA <- accel.process.tri(counts.tri = nhanes[, 1:3], nci.methods = TRUE);
    
    # clean up workspace
    detach("package:accelerometry", unload=TRUE)
    
    ret_list <- list("nhanes" = nhanes, "dailyPA" = dailyPA)
    return (ret_list)
}

# Convert 1 second intervals to larger intervals, of size specified by numsec,
# and makes a matrix with numcol elements per row
convertNHANES <- function(acc, fieldname, numsec, numcol)
{
    counts1sec <- acc[,fieldname]
    d = length(counts1sec)
    d1 = numsec # should be 60 for aggregation to 1 minute
    d2 = numcol # should be 60 if d1 is 60, to have 1 hour represented per row, where each col represents 1 minute aggregates
    d3 = ceiling(length(counts1sec)/(d1*d2))
    if (length(counts1sec) > d1*d2*d3) {
        counts1sec <- counts1sec[1:(d1*d2*d3),]
    }
    if(d1>d1*d2*d3){
	    counts1sec[(d+1):(d1*d2*d3)] = 0
	}
    dim(counts1sec) <- c(d1,d2,d3)
    # If M is a 3D matrix and d1=dim(M)[1], d2=dim(M)[2] then
    #    M[i,j,k]==M[ i+ (j-1)*d1 + (k-1)*d1*d2 ]
    nhanes <- colSums(counts1sec, dims = 1)
    nhanes <- t(nhanes)
    return (nhanes)
}


### Main program
args = commandArgs(trailingOnly=TRUE)


for (i in args){
    print(i)
}

actigraphfile = args[1];
weartimefile = args[2];

#directory <- '~/git/padaco/tools/r_scripts/demo'
#subid <- 'Scenario_1'

#actigraphfile <- paste(directory, paste(subid, '.csv', sep=''), sep='/')
#weartimefile <- paste(directory, paste(subid, '_nhanes_weartime.csv', sep=''), sep='/')

acc <- read.table(file = actigraphfile, sep = ",", header = T, stringsAsFactors = F, skip = 10)

# get the weartime and daily statistics
ret_list <- weartimeNHANESperMinute(acc)

# write tables
write.table(ret_list$nhanes, weartimefile, sep = ',', row.names = F, col.name = T)
print(paste("Wear time file saved to",weartimefile))