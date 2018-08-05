function fields = getHeader(filename,separator)
    fields = {};
    
    if(exist(filename,'file'))
        if(nargin<2)
            separator = ',';
        end
        fid = fopen(filename,'r');
        
        if(fid>1)
            try
                
                fields = strsplit(fgetl(fid),separator);
                fclose(fid);
            catch me
                showME(me);
                fclose(fid);
            end
        end
    end

end