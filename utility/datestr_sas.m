function str = datestr_sas(sasDatenum, varargin) % sas datenum is number of seconds since Jan 1, 1960
    str = datestr(datenum(1960,1,1,0,0,double(sasDatenum)), varargin{:});
end
