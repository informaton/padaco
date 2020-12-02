function mergeActigraphFiles(file1, file2, fileToUseForOverlap, destinationPath)  
    % fileToUserForOverlap = 1 for the first file, 2 for the second file.
    %   Default is 2, i.e. the second file is used when there is overlap.
    if nargin==0
        file1 = '/Volumes/Accel/t_1/raw_split_studies/700689t00c1RAW.csv';
        file2 = '/Volumes/Accel/t_1/raw_split_studies/700689t00c2RAW.csv';
        fileToUseForOverlap = 2;        
        destinationPath = '/Volumes/Accel/t_1/raw_merged_studies';
    else
        if nargin<4
            destinationPath = [];
        end
        if nargin < 3 || isempty(fileToUseForOverlap)
            fileToUseForOverlap = 2;
        end
    end
    f1 = loadActiFile(file1);
    f2 = loadActiFile(file2);
    
    if f2.dateTimeNum(1) < f1.dateTimeNum(1)
        fprintf('Second file given starts before first file given.  Swapping the order.\n'); 
        f3 = f1;
        f1 = f2;
        f2 = f3;
        delete(f3);

        file3 = file1;
        file1 = file2;
        file2 = file3;
        delete(file3);        
    end
    
    [path1, name1, ext1] = fileparts(file1);
    [~, name2, ~] = fileparts(file1);
    
    file_merge = fullfile(path1, sprintf('%s_%s%s',name1, name2, ext1));

    % no merge necessary
    if f2.dateTimeNum(1) > f1.dateTimeNum(end)
        copyfile(file1, file_merge);        
        end_to_start_inclusive = datenum(file1.end):datenum([0 0 0 0 0 f1.sampling_period]):f2.dateTimeNum(1);
        end_to_start_datestr = datestr(end_to_start_inclusive(2:end-1));
        write_actigraph_zeros_to_file(file_merge, end_to_start_datestr);
    else
        %need to merge then
        copyfile_actigraph_until(file1, file_merge, f2.start);        
    end
    
    if ~exist(file_merge, 'file')
        throw(MException('PADACO:ACT:FERROR','Unable to open file for writing: %s', filename));
    end
    
    append_actigraph_file(file2, file_merge);
end

function actiObj = loadActiFile(filename)
    actiObj = PASensorData();    
    actiObj.loadActigraphFile(filename);
end

function copyfile_actigraph_until(filename, copy_filename, until_datenum)
   fid_dest = fopen(copy_filename, 'w');
   fid_source = fopen(filename, 'r');
   
   headerLines = 11;
   while headerLines>0
       fprintf(fid_dest, '%s', fgets(fid_source));
       headerLines = headerLines - 1;
   end


   fclose(fid_dest);
   fclose(fid_source);    
end

function fid_source = openFileToFirstEntry(actigraph_filename)
    fclose_on_exit = false;    
    [~, fid_source] = PASensorData.getActigraphCSVFileHeader(actigraph_filename, fclose_on_exit);    
end

function append_actigraph_file(src_filename, append_filename)
    fid_source = openFileToFirstEntry(src_filename);
    fid_dest = fopen(append_filename, 'a');
    
    % copyuntilend(fid_source, fid_dest);
    while ~feof(fid_source)
        fwrite(fid_dest, fread(fid_source, 1, '*uint8'), 'uint8');
    end
    fclose(fid_dest);
    fclose(fid_source);
end

function write_actigraph_zeros_to_file(filename, num_zeros_or_dates)
    fid = fopen(filename, 'a');
    if fid>1
        if iscell(num_zeros_or_dates) || size(num_zeros_or_dates,1)>1
            dates = num_zeros_or_dates;
            if iscell(dates)
                for n=1:size(dates,1)
                    fprintf(fid, '%s,0,0,0\n', dates{n,:});
                end
            else
                for n=1:size(dates,1)
                    fprintf(fid, '%s,0,0,0\n', dates(n,:));
                end
            end            
        else
            num_zeros = num_zeros_or_dates(1);
            for n=1:num_zeros
                fprintf(fid, '0,0,0\n');
            end
        end
        fclose(fid);
    else
        throw(MException('PADACO:ACT:FERROR','Unable to open file for writing: %s', filename));
    end
end
