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
    fprintf(1,'Loading %s\n', file1);
    f1 = loadActiFile(file1);
    fprintf(1,'Loading %s\n', file2);
    f2 = loadActiFile(file2);
    
    if f2.dateTimeNum(1) < f1.dateTimeNum(1)
        error('Second file given starts before first file given.  Swap the order and verify fileToUseForOverlap is correct.'); 
        % don't both swapping them as we don't know what to do with the file to use for overlap: Should it be swapped as well if the 
        % person made a mistake on the input?
    end
    
    [path1, name1, ext1] = fileparts(file1);
    [~, name2, ~] = fileparts(file2);
    
    if isempty(destinationPath) || ~isdir(destinationPath)
        destinationPath = path1;
    end
    
    merged_filename = fullfile(destinationPath, sprintf('%s_%s%s',name1, name2, ext1));
    
    if f1.sampleRate~=f2.sampleRate
        error('Sample rates must be the same (%d, %d)', f1.sampleRate, f2.sampleRate);
    end
    datenum_delta = datenum(0, 0, 0, 0, 0, 1/f1.sampleRate);
    fileHeader = PASensorData.getActigraphCSVFileHeader(file1);
    
    % This is necessary to determine if time stamps are written or not.
    actilife_version = fileHeader.actilife;

    % no merge necessary
    if f2.dateTimeNum(1) > f1.dateTimeNum(end) || fileToUseForOverlap==1
        fprintf(1,'Copying %s to %s\n', file1, merged_filename);
        tic
        copyfile(file1, merged_filename);        
        toc
        %         end_to_start_inclusive = datenum(file1.end):datenum([0 0 0 0 0 f1.sampling_period]):f2.dateTimeNum(1);
        %         end_to_start_datestr = datestr(end_to_start_inclusive(2:end-1));
        %         write_actigraph_zeros_to_file(merged_filename, end_to_start_datestr);
        fprintf(1,'Appending %s to %s with zero padding if applicable\n', file2, merged_filename);
        tic
        f2.writeActigraphRawCSV(merged_filename, 'include_header', false, 'dry_run', false, 'start_datenum',f1.dateTimeNum(end)+datenum_delta, 'actilife_version', actilife_version);
        toc
    else
        %need to merge then
        %copyfile_actigraph_until(file1, file_merge, f2.start);
        fprintf(1,'Writing %s to %s until merge point\n', file1, merged_filename);
        tic
        f1.writeActigraphRawCSV(merged_filename, 'include_header', true, 'dry_run', false, 'end_datenum', f2.dateTimeNum(start)-datenum_delta, 'actilife_version', actilife_version);
        toc
        fprintf(1,'Appending %s to %s\n', file2, merged_filename);
        tic
        f2.writeActigraphRawCSV(merged_filename, 'include_header', false, 'dry_run', true);
        toc
    end
    
%     if ~exist(file_merge, 'file')
%         throw(MException('PADACO:ACT:FERROR','Unable to open file for writing: %s', filename));
%     end
    
    % append_actigraph_file(file2, file_merge);
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
