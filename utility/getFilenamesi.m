function [filenames,fullfilenames, fileDatenums] = getFilenamesi(pathname,ext,sortByDateFlag)
    %> function [filenames,fullfilenames, fileDatenums] = getFilenamesi(pathname,ext,sortByDateFlag)
    %>  Case insensitive version of getFilenames.  This was created because some
    %>  OS are case sensitive so that dir('*.txt') would not catch the file
    %>  help.TXT.
    %>  @param pathname is a string of the folder to search
    %>  [filenames] = getFilenames(pwd,'m');
    %>      filenames contains the filenames with 'm' extension in the current
    %>      directory
    %> @param ext (string, optional, default is '') File extension to
    %> filter/search for.
    %> @param sortByDateFlag (boolean, optional, defaults to false) when true,
    %> filenames are sorted by date from most recent to least recent (i.e.
    %> newest to oldest)
    %> @note Leading '.' in ext will be removed.
    %> @note For example if ext = '.m', the method will correct it to 'm' for
    %> you.  Thus, the following commands are equivalent:
    %> - [filenames] = getFilenames(pwd,'m');
    %> - [filenames] = getFilenames(pwd,'.m');
    
    % copyright Hyatt Moore IV
    
    if(nargin<3)
        sortByDateFlag = false;
        if(nargin<2)
            ext = '';
        end
    end
    dirPull = dir(pathname);
    
    datenums = datenum(cells2mat(dirPull.date));
    if(sortByDateFlag)
        [datenums, sortInd] = sort(datenums,'descend');
        fields = fieldnames(dirPull);
        
        % sort the structure
        for f=1:numel(fields)
            dirPull.(fields{f}) = dirPull.(fields{f})(sortInd);
        end
    end
    
    directory_flag = cells2mat(dirPull.isdir);
    names = cells2cell(dirPull.name);
    filenames = names(~directory_flag);
    datenums = datenums(~directory_flag);
    
    if(~isempty(ext) && ext(1)=='.')
        ext(1)=[];
    end
    
    % Mac OS does some extra things to keep track of files in each directory which interfere here.
    if(ismac)
        fileMatchesCell = regexpi(filenames,strcat('^[^\._].*',ext,'$'));
    else
        fileMatchesCell = regexpi(filenames,strcat('.*',ext,'$'));
    end
    
    
    
    fileMatchesVec = ~cellfun(@isempty,fileMatchesCell);
    % fileMatchesVec = false(size(fileMatchesCell));
    % %I really don't like MATLAB's regexp cell output format... ah well
    % for f=1:numel(fileMatchesCell)
    %     fileMatchesVec(f) = ~isempty(fileMatchesCell{f});
    % end
    
    filenames(~fileMatchesVec) = [];
    if(nargout>1)
        fullfilenames = cell(size(filenames));
        for k=1:numel(filenames)
            fullfilenames{k} = fullfile(pathname,filenames{k});
        end
        
        if(nargout>2)
            fileDatenums = datenums(fileMatchesVec);
        end
    end
end

