%> @file PADeriver.cpp
%> @brief PADeriver serves as model and controller for count derivation
%> working using Padaco based classes.
% ======================================================================
classdef PADeriver < handle
    
    properties(Constant)
        SOI_LABELS = {'X','Y','Z','Magnitude'};
        SOI_FIELDS = {'x','y','z','vecMag'};
        FILTER_NAMES = {'fir1' % FIR filter design using the window method.
            'fir2' % FIR arbitrary shape filter design using the frequency sampling method.
            %'kaiserord' % FIR order estimator
            'fircls1' % Low & high pass FIR filter design by constrained least-squares.
            'firls' % Linear-phase FIR filter design using least-squares error minimization.  FIR filter which has the best approximation to the desired frequency response described by F and A in the least squares sense.
            'fircls' % Linear-phase FIR filter design by constrained least-squares.
            'cfirpm' % Complex and nonlinear phase equiripple FIR filter design.
            'firpm' % Parks-McClellan optimal equiripple FIR filter design.
            'butter' % Butterworth digital and analog filter design.
            'cheby1' % Chebyshev Type I digital and analog filter design.
            'cheby2' % Chebyshev Type II digital and analog filter design.
            'ellip' % Elliptic or Cauer digital and analog filter design.
            % 'besself' % Bessel analog filter design.  Note that Bessel filters are lowpass only.
            }
        WINDOW_OPTIONS = {
            @bartlett       ,'Bartlett window.';
            @barthannwin    ,'Modified Bartlett-Hanning window.';
            @blackman       ,'Blackman window.';
            @blackmanharris ,'Minimum 4-term Blackman-Harris window.';
            @bohmanwin      ,'Bohman window.';
            @chebwin        ,'Chebyshev window.';
            @flattopwin     ,'Flat Top window.';
            @gausswin       ,'Gaussian window.';
            @hamming        ,'Hamming window.';
            @hann           ,'Hann window.';
            @kaiser         ,'Kaiser window.';
            @nuttallwin     ,'Nuttall defined minimum 4-term Blackman-Harris window.';
            @parzenwin      ,'Parzen (de la Valle-Poussin) window.';
            @rectwin        ,'Rectangular window.';
            @taylorwin      ,'Taylor window.';
            @tukeywin       ,'Tukey window.';
            @triang         ,'Triangular window.';
            }
    end
    
    properties(Access=private)
        figureH;
        handles;
        %> Struct with fields
        %> - raw Instance of PAData
        %> - count Instance of PAData
        dataObject;
        
        %> Struct with fields
        %> - raw
        %> - count
        %> - derived
        %> - filter
        %> - filtfilt
        data;
        %> Struct with fields
        %> - raw Sample rate of raw acceleration
        %> - counts Number of epochs per second
        samplerate;
        
        %> Struct of line handles
        lines;
        
        %> Struct with fields describing digital filter that is applied to
        %> raw data.
        filterOptions;
        
        %> Signal of interest, can be:
        %> - x
        %> - y
        %> - z
        %> - vecMag
        soi;  %signal of interest
        
        %> first non-zero count index
        firstNZI
        
        %> Equivalent location of first non-zero count index in the raw
        %> signal
        firstNZI_raw;
    end
    
    methods
        
        function this = PADeriver()
            this.soi = 'x';
            this.filterOptions.start = 0.25;
            this.filterOptions.stop = 2.5;
            this.filterOptions.order = 10;
            this.filterOptions.name = 'fir1';
            this.filterOptions.type = 'filtfilt';
            this.filterOptions.dB = 3;  % peak-to-peak decibals
            this.filterOptions.window = 'hamming';
            this.initGUI();
        end
        
        function updatePlots(this)
            this.disableControls();
            
            this.syncToUI();
            this.filterData();
            this.countFilterData();
            this.plotCounts();
            
            this.enableControls();
            
        end
        
    end
        
    methods(Access=private)
        
        %% Controls - load UI configuration into object parameters.
        function syncToUI(this)
            this.soi = getMenuUserData(this.handles.menu_soi);
            this.filterOptions.name = getMenuUserData(this.handles.menu_filterName);
            this.filterOptions.order = getMenuUserData(this.handles.menu_filterOrder);
            this.filterOptions.startHz = str2double(get(this.handles.edit_filterStartHz,'string'));
            this.filterOptions.stopHz = str2double(get(this.handles.edit_filterStopHz,'string'));
        end
        function plotCounts(this)
            line_tags = {'counts','rawCounts','rawFiltered','raw','error'};
            
            for l=1:numel(line_tags)
                lineTag = line_tags{l};
                axesTag = ['axes_',lineTag];
                ydata = this.data.(lineTag);
                xdata = 1:numel(ydata);
                stairs(this.handles.(axesTag),xdata,ydata);
                ylabel(this.handles.(axesTag),line_tags{l});
                %                 set(this.lines.(lineTag),'xdata',xdata,'ydata',ydata);
                %                 stem(this.handles.(axesTag),xdata,ydata);
            end 
        end
        
        function disableControls(this)
            disablehandles(this.handles.panel_filterOptions);
            set(this.handles.menu_soi,'enable','off');
            set(this.handles.push_update,'enable','off');
        end
        
        function enableControls(this)
            enablehandles(this.handles.panel_filterOptions);
            set(this.handles.menu_soi,'enable','on');
            set(this.handles.push_update,'enable','on');
        end
        
        
        %% Initializers
        function initGUI(this)
            this.figureH = deriveIt();
            this.handles = guidata(this.figureH);
            
            this.disableControls();
            
            % File panel
            set(this.handles.push_loadFile,'callback',@this.loadFileCallbackFcn);
            set(this.handles.menu_soi,'string',this.SOI_LABELS,'value',find(strcmpi(this.soi,this.SOI_FIELDS),1),'userdata',this.SOI_FIELDS,'callback',@this.menuSOICallbackFcn);
            
            % Filter panel
            orderOptions = (0:99)';
            set(this.handles.menu_filterName,'string',this.FILTER_NAMES,'userdata',this.FILTER_NAMES,'value',find(strcmpi(this.FILTER_NAMES,this.filterOptions.name),1));
            set(this.handles.menu_filterOrder,'string',num2str(orderOptions),'userdata',orderOptions,'value',find(orderOptions==this.filterOptions.order,1));
            
            set(this.handles.edit_filterStartHz,'string',num2str(this.filterOptions.start),'callback',@this.edit_positiveNumericCallbackFcn);
            set(this.handles.edit_filterStopHz,'string',num2str(this.filterOptions.stop),'callback',@this.edit_positiveNumericCallbackFcn);
            
            filtfiltFlag = strcmpi('filtfilt',this.filterOptions.type);
            set(this.handles.radio_filtfilt,'value',filtfiltFlag);
            %             set(this.handles.radio_filter,'value',~filtfiltFlag);
            
            set(this.handles.push_update,'callback',@this.updatePlotsCallbackFcn);
            
            this.initPlots();
        end
        
        function initPlots(this)
            this.labelPlots();

            %             line_tags = {'counts','rawCounts','rawFiltered','raw','error'};
            %             for l=1:numel(line_tags)
            %                 lineTag = line_tags{l};
            %                 axesTag = ['axes_',lineTag];
            %                 this.lines.(lineTag) = line([],[],'parent',this.handles.(axesTag));
            %                 ylabel(this.handles.(axesTag),lineTag);
            %             end
        end
        
        
        function labelPlots(this)
            tags = {'counts','rawCounts','rawFiltered','raw','error'};
            axesTags = strcat('axes_',tags);
            for t=1:numel(tags)
                ylabel(this.handles.(axesTags{t}),tags{t});
            end
        end
        
        %% Modeling - accessors/mutators
        function loadFile(this, count_filename)
            [filePath, ~, ~] = fileparts(count_filename);
            bin_testFile = 'activity.bin';  %firmware version 2.5.0
            
            raw_filename = fullfile(filePath,bin_testFile);
            
            
            set(this.figureH,'name','Loading binary data ...');
            drawnow();
            this.dataObject.raw = PAData(raw_filename);
            
            set(this.figureH,'name','Loading count data ...');
            drawnow();
            this.dataObject.count = PAData(count_filename);
            
            %raw - sampled at 40 Hz
            %count - 1 Hz -> though upsampled from file to 40Hz during data object
            %loading.
            
            % update controls
            %                     this.updateControls();
            %                     function updateControls(this)
            
            
            set(this.figureH,'name','Processing data ...');
            drawnow();
            
            this.samplerate.raw = this.dataObject.raw.getSampleRate();
            this.samplerate.counts = this.dataObject.count.getSampleRate();
            set(this.handles.edit_samplerateCounts,'string',num2str(this.samplerate.counts));
            set(this.handles.edit_samplerateRaw,'string',num2str(this.samplerate.raw));
            
            % example conversion
            % Count - Samples   - Derivation
            %   1      1:40       0*40+1:1*40
            %   2     41:80       1*40+1:2*40
            %   n                 (n-1)*40+1:n*40
            
            this.firstNZI = find(this.dataObject.count.accel.count.(this.soi),1); % firstNonZeroCountIndex
            this.firstNZI_raw = (this.firstNZI-1)*this.samplerate.raw+1;
            
            this.updateDataStruct();
            
        end
        
        function updateDataStruct(this)
            %let's start with a value of zero if we can.
            numPreviousSeconds = 15;
            secondsToCheck = 30;
            
            if(this.firstNZI_raw>(this.samplerate.raw*numPreviousSeconds)) % If FNCV = 11, then FNCV_At_Fs = 401;
                raw_start = this.firstNZI_raw-this.samplerate.raw*numPreviousSeconds;  % If FNCV_At_Fs = 401-400 = 1;
                count_start = this.firstNZI-numPreviousSeconds;  % then FNCV = 11 - 10 = 1 q.e.d
            else
                raw_start = 1;
                count_start = 1;
            end
            
            rawRange = raw_start:(raw_start-1)+secondsToCheck*this.samplerate.raw;
            countRange = (0:secondsToCheck*this.samplerate.counts-1)+count_start;
            
            this.data.raw = this.dataObject.raw.accel.raw.(this.soi)(rawRange);
            this.data.counts = this.dataObject.count.accel.count.(this.soi)(countRange);
        end
        
        function filterData(this)
            [this.data.filter, this.data.filtfilt] = this.acti_filter(this.data.raw,this.filterOptions.name,this.samplerate.raw,this.filterOptions.order, this.filterOptions.dB);
        end
        
        function countFilterData(this)
            if(this.isFiltfilt())
                this.data.rawFiltered = this.data.filtfilt;
            else
                this.data.rawFiltered = this.data.filter;
            end
            
            samplesToCheck = 1:numel(this.data.raw);
            x=reshape(this.data.rawFiltered(samplesToCheck),this.samplerate.raw,[]);
            this.data.rawCounts = sum(abs(x)); % sum down the columns
            
            this.data.error = this.data.counts(:) - this.data.rawCounts(:);
        end
        
        function filtfiltFlag =  isFiltfilt(this)
            filtfiltFlag = get(this.handles.radio_filtfilt,'value');
        end
        
        %% Callbacks
        function loadFileCallbackFcn(this,hObject, eventdata)
            fName = get(this.figureH,'name');
            
            testingPath = '/Users/unknown/Data/GOALS/Temp';
            % sqlite_testFile = '704397t00c1_1sec.sql';  % SQLite format 3  : sqlite3 -> .open 704397t00c1_1sec.sql; .tables; select * from settings; .quit;  (ref: https://www.sqlite.org/cli.html)
            csv_testFile = '704397t00c1.csv';
            %             raw_filename = fullfile(testingPath,bin_testFile);
            count_filename = fullfile(testingPath,csv_testFile);
            
            multiSelectFlag = 'off';
            %     fullFilename = uigetfullfile({'*.csv','Counts data (*.csv)';'*.bin','Binary acceleration data (.bin)'},'Select a file with counts or acceleration',...
            %         multiSelectFlag,initFile);
            
            count_filename = uigetfullfile({'*.csv','Counts data (*.csv)'},'Select counts file',...
                multiSelectFlag,count_filename);
            
            if(~isempty(count_filename))
                
                try
                    set(hObject,'enable','off');
                    this.loadFile(count_filename);
                    
                    this.updatePlots();
                    
                catch me
                    showME(me);
                    
                end
                set(hObject,'enable','on');
                drawnow();
                
            end
            
            set(this.figureH,'name',fName);
        end
        
        function menuSOICallbackFcn(this,hObject,~)
            this.soi = getMenuUserData(hObject);
        end
        
        function updatePlotsCallbackFcn(this,hObject,eventdata)
            this.updatePlots();
        end
        
    end
    
    methods(Static)
        function [filt_sigOut, filtfilt_sigOut] = acti_filter(sigIn,filterName, fs, n_order,peak2peakDB)
            
            if(nargin<5 || isempty(peak2peakDB))
                peak2peakDB = 3;  % reduces by 1/2
                %peak2peakDB = .1;
            end
            
            if(nargin<4 || isempty(n_order))
                n_order = 2;
            end
            
            Fmax = fs/2;
            Fpass = [0.25 2.5];
            
            Wpass = Fpass/Fmax;  %normalized frequency
            
            switch(filterName)
                case 'cheby1'
                    [h_b,h_a] = cheby1(n_order, peak2peakDB, Wpass, 'bandpass');
                case 'fir1'
                    h_b = fir1(n_order, Wpass,'bandpass');
                    h_a = 1;
                    %                     B = fir1(N,Wn,kaiser(N+1,4))
                    %                         uses a Kaiser window with beta=4. B = fir1(N,Wn,'high',chebwin(N+1,R))
                    %                         uses a Chebyshev window with R decibels of relative sidelobe
                    %                         attenuation.
                    
                case 'butter' % IIR design
                otherwise
                    [h_b,h_a] = cheby1(n_order, peak2peakDB, Wpass, 'bandpass');
            end
            
            % Filter data
            filt_sigOut = filter(h_b,h_a, sigIn);            
            filtfilt_sigOut = filtfilt(h_b,h_a, sigIn);
            
        end
        
        function edit_positiveNumericCallbackFcn(hObject,eventdata)
            newValue = str2double(get(hObject,'string'));
            if(isempty(newValue) || isnan(newValue) || newValue<0)
                fprintf(1,'Bad value entered!');
            else
                fprintf(1,'Good value entered');
            end
            
        end
        
    end
    
end