% ======================================================================
%> @file PAData.cpp
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The PAData class helps loads and stores accelerometer data used in the
%> physical activity monitoring project.  The project is aimed at reducing
%> obesity and improving health in children.
% ======================================================================
classdef PADeriverData < PAData
    properties
        
    end
    methods
        function obj = PADeriverData(varargin)
            obj = obj@PAData(varargin{:});
            
        end
    end
    
    methods (Access = protected)
        
        % ======================================================================
        %> @brief Loads raw accelerometer data from binary file produced via
        %> actigraph Firmware 2.5.0 or 3.1.0.  This function is
        %> intended to be called from loadFile() to ensure that
        %> loadCountFile is called in advance to guarantee that the auxialiary
        %> sensor measurements are loaded into the object (obj).  The
        %> auxialiary measures (e.g. lux, steps) are upsampled to the
        %> sampling rate of the raw data (typically 40 Hz).
        %> @param obj Instance of PAData.
        %> @param fullRawActivityBinFilename The full (i.e. with path) filename for raw data,
        %> stored in binary format, to load.
        %> @param firmwareVersion String identifying the firmware version.
        %> Currently only '2.5.0' and '3.1.0' are supported.
        % Testing:  logFile = /Volumes/SeaG 1TB/sampledata_reveng/T1_GT3X_Files/700851/log.bin
        %> @retval recordCount - The number of records (or samples) found
        %> and loaded in the file.
        % =================================================================
        function recordCount = loadRawActivityBinFile(obj,fullRawActivityBinFilename,firmwareVersion)
            if(exist(fullRawActivityBinFilename,'file'))
                
                recordCount = 0;
                
                fid = fopen(fullRawActivityBinFilename,'r','b');  %I'm going with a big endian format here.
                
                if(fid>0)
                    
                    encodingEPS = 1/341; %from trial and error - or math:  341*3 == 1023; this is 10 bits across three vlues
                    precision = 'ubit12=>double';
                    
                    % Testing for ver 2.5.0
                    % fullRawActivityBinFilename = '/Volumes/SeaG 1TB/sampledata_reveng/700851.activity.bin'
                    %                sleepmoore:T1_GT3X_Files hyatt4$ head -n 15 ../../sampleData/raw/700851t00c1.raw.csv
                    %                 ------------ Data File Created By ActiGraph GT3X+ ActiLife v6.11.1 Firmware v2.5.0 date format M/d/yyyy at 40 Hz  Filter Normal -----------
                    %                 Serial Number: NEO1C15110103
                    %                 Start Time 00:00:00
                    %                 Start Date 10/25/2012
                    %                 Epoch Period (hh:mm:ss) 00:00:00
                    %                 Download Time 16:48:59
                    %                 Download Date 11/2/2012
                    %                 Current Memory Address: 0
                    %                 Current Battery Voltage: 3.74     Mode = 12
                    %                 --------------------------------------------------
                    %                 Timestamp,Axis1,Axis2,Axis3
                    %                 10/25/2012 00:00:00.000,-0.044,0.361,-0.915
                    %                 10/25/2012 00:00:00.025,-0.044,0.358,-0.915
                    %                 10/25/2012 00:00:00.050,-0.047,0.361,-0.915
                    %                 10/25/2012 00:00:00.075,-0.044,0.361,-0.915
                    % Use big endian format
                    try
                        % both fw 2.5 and 3.1.0 use same packet format for
                        % acceleration data.
                        if(strcmp(firmwareVersion,'2.5.0')||strcmp(firmwareVersion,'3.1.0')||strcmp(firmwareVersion,'2.2.1')||strcmp(firmwareVersion,'1.5.0'))
                            tic
                            axesPerRecord = 3;
                            checksumSizeBytes = 1;
                            if(strcmp(firmwareVersion,'2.5.0'))
                                % The following, commented code is for determining
                                % expected record count.  However, the [] notation
                                % is used as a shortcut below.
                                % bitsPerByte = 8;
                                % fileSizeInBits = ftell(fid)*bitsPerByte;
                                % bitsPerRecord = 36;  %size in number of bits
                                % numberOfRecords = floor(fileSizeInBits/bitsPerRecord);
                                % axesUBitData = fread(fid,[axesPerRecord,numberOfRecords],precision)';
                                % recordCount = numberOfRecords;
                                
                                % reads are stored column wise (one column, then the
                                % next) so we have to transpose twice to get the
                                % desired result here.
                                axesUBitData = fread(fid,[axesPerRecord,inf],precision)';
                                
                            elseif(strcmp(firmwareVersion,'3.1.0')||strcmp(firmwareVersion,'2.2.1') || strcmp(firmwareVersion,'1.5.0'))
                                % endian format: big
                                % global header: none
                                % packet encoding:
                                %   header:  8 bytes  [packet code: 2][time stamp: 4][packet size (in bytes): 2]
                                %   accel packets:  36 bits each (format: see ver 2.5.0) + 1 byte for checksum
                                
                                triaxialAccelCodeBigEndian = 7680;
                                trixaialAccelCodeLittleEndian = 7686; %?
                                triaxialAccelCodeLittleEndian = 30;
                                triaxialAccelCode = triaxialAccelCodeBigEndian;
                                %                                packetCode = 7686 (popped up in a firmware version 1.5
                                bitsPerByte = 8;
                                bitsPerAccelRecord = 36;  %size in number of bits (12 bits per acceleration axis)
                                recordsPerByte = bitsPerByte/bitsPerAccelRecord;
                                timeStampSizeBytes = 4;
                                % packetHeader.size = 8;
                                % go through once to determine how many
                                % records I have in order to preallocate memory
                                % - should look at meta data record to see if I can
                                % shortcut this.
                                while(~feof(fid))
                                    
                                    packetCode = fread(fid,1,'uint16=>double');
                                    fseek(fid,timeStampSizeBytes,0);
                                    packetSizeBytes = fread(fid,2,'uint8');  % This works for firmware version 1.5 packetSizeBytes = fread(fid,1,'uint16','l');
                                    if(~feof(fid))
                                        packetSizeBytes = [1 256]*packetSizeBytes;
                                        if(packetCode == triaxialAccelCode)  % This is for the triaxial accelerometers
                                            packetRecordCount = packetSizeBytes*recordsPerByte;
                                            if(packetRecordCount>1)
                                                recordCount = recordCount+packetRecordCount;
                                            else
                                                fprintf('Record count <=1 at file position %u\n',ftell(fid));
                                            end
                                        end
                                        if(packetSizeBytes~=0)
                                            fseek(fid,packetSizeBytes+checksumSizeBytes,0);
                                        else
                                            fprintf('Packet size is 0 bytes at file position %u\n',ftell(fid));
                                        end
                                    end
                                end
                                
                                frewind(fid);
                                curRecord = 1;
                                axesUBitData = zeros(recordCount,axesPerRecord);
                                obj.timeStamp = zeros(recordCount,1);
                                while(~feof(fid) && curRecord<=recordCount)
                                    packetCode = fread(fid,1,'uint16=>double');
                                    if(packetCode==triaxialAccelCode)  % This is for the triaxial accelerometers
                                        obj.timeStamp(curRecord) = fread(fid,1,'uint32=>double');
                                        packetSizeBytes = [1 256]*fread(fid,2,'uint8');
                                        
                                        packetRecordCount = packetSizeBytes*recordsPerByte;
                                        
                                        axesUBitData(curRecord:curRecord+packetRecordCount-1,:) = fread(fid,[axesPerRecord,packetRecordCount],precision)';
                                        curRecord = curRecord+packetRecordCount;
                                        checkSum = fread(fid,checksumSizeBytes,'uint8');
                                    elseif(packetCode==0)
                                        
                                    else
                                        fseek(fid,timeStampSizeBytes,0);
                                        packetSizeBytes = fread(fid,2,'uint8');
                                        if(~feof(fid))
                                            packetSizeBytes = [1 256]*packetSizeBytes;
                                            fseek(fid,packetSizeBytes+checksumSizeBytes,0);
                                        end
                                    end
                                end
                                
                                curRecord = curRecord -1;  %adjust for the 1 base offset matlab uses.
                                if(recordCount~=curRecord)
                                    fprintf(1,'There is a mismatch between the number of records expected and the number of records found.\n\tPlease check your data for corruption.\n');
                                end
                            end
                            
                            
                            axesFloatData = (-bitand(axesUBitData,2048)+bitand(axesUBitData,2047))*encodingEPS;
                            obj.accel.ubit.x = axesUBitData(:,1);
                            obj.accel.ubit.y = axesUBitData(:,2);
                            obj.accel.ubit.z = axesUBitData(:,3);
                            obj.accel.ubit.vecMag = sqrt(obj.accel.ubit.x.^2+obj.accel.ubit.y.^2+obj.accel.ubit.z.^2);
                            
                            obj.accel.raw.x = axesFloatData(:,1);
                            obj.accel.raw.y = axesFloatData(:,2);
                            obj.accel.raw.z = axesFloatData(:,3);
                            obj.accel.raw.vecMag = sqrt(obj.accel.raw.x.^2+obj.accel.raw.y.^2+obj.accel.raw.z.^2);
                            recordCount = size(axesFloatData,1);
                            obj.durSamples = recordCount;
                            
                            toc;
                        end
                        fclose(fid);
                        
                        fprintf('Skipping resample count data step\n');
                        %                        obj.resampleCountData();
                        
                    catch me
                        showME(me);
                        fclose(fid);
                    end
                else
                    fprintf('Warning - could not open %s for reading!\n',fullRawActivityBinFilename);
                end
            else
                fprintf('Warning - %s does not exist!\n',fullRawActivityBinFilename);
            end
        end
    end
    
    
end