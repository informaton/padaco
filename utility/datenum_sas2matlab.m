function matlabDatenum = datenum_sas2matlab(sasDatenum) % sas datenum is number of seconds since Jan 1, 1960
    matlabDatenum = datenum(1960,1,1,0,0,double(sasDatenum));
end
