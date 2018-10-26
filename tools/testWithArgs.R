### Main program
args = commandArgs(trailingOnly=TRUE)

cat("The following arguments were received:")
for (i in args){
    cat('\n',i)
}