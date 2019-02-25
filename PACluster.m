% ======================================================================
%> @file PACluster.cpp
%> @brief Class for clustering results data produced via padaco's batch
%> processing.
% ======================================================================
classdef PACluster < PAData
    properties(Constant)
        WEEKDAY_ORDER = 0:6;  % for Sunday through Saturday
        WEEKDAY_LABELS = {'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};            
        WEEKDAY_SCORE = [-1, 0, 1, 1, 1, 0, -1];  % for Sunday through Saturday
        WEEKDAY_WEIGHT = [1.5, 1.5, 1, 1, 1, 1.5, 1.5]
    end
    
    %> @brief The sort order can be difficult to understand.  First, the
    %> adaptive k-means algorithm is applied and centroids are found.  The
    %> centroids are labeled arbitrarily according to the index or position
    %> in which they are discovered.  There 'popularity' is determined by the
    %> number of member shapes a centroid has compared to other centroids.  
    %> Clusters are ordered according to popularity from least to greatest
    %> number of member shapes (most popular).  This is the sort order,
    %> where 1 is the least popular and N (for N centroids found) is the
    %> most popular.  A centroid of index or COI is any centroid that is of
    %> interest to the user.  Users are typically presented with centroids
    %> in order of their popularity as this provides more meaning than the
    %> initial index given to the centroid during the adaptive k-means
    %> processing.  To go from popularity 'p' (where p = 1 for least popular to p = N for most popular)
    %> to the centroid's index use @c coiSortOrderToIndex(p).  
    %> To determine the popularity of centroid at initial index c, use
    %> coiIndex2SortOrder(c), where a value of 1 is least pouplar and a
    %> value of N is most popular.
    properties(Access=private)
        
        %> Nx1 vector of centroid index for loadShape profile associated with its row.
        loadshapeIndex2centroidIndexMap;
        
        % silhouette(X, idx,'distance','euclidean');
        % silhouette(this.loadShapes, this.loadshapeIndex2centroidIndexMap,'distance','euclidean');
        
        
        
        %> Nx1 vector that maps the constructor's input load shapes matrix
        %> to the sorted  @c loadShapes matrix.
        %sortIndices;  % centroidShapes(sortIndices(1),:) is the most popular centroid
        
        %> Cx1 vector that maps load shapes' original cluster indices to
        %> the equivalent cluster index after clusters have been sorted
        %> by their load shape count.  Analog to coiSortOrder2Index
        centroidSortMap;
        
        %> Alias for centroidSortMap
        %> map for going from sort order to coi index.  Use the desired sort
        %> order as the index into coiSortOrder2Index to retrieve the 
        %> original, unsorted index.
        coiSortOrder2Index;  % To get original index of the most popular cluster (sort order =1 ) use index =  coiSortOrder2Index(1)
         
        
        coiIndex2SortOrder; % To get the popularity order based off the original cluster index.
        
        
        
        %> The sort order index for the centroid of interest (coi) 
        %> identified for analysis.  It is 
        %> initialized to the most frequent centroid upon successful
        %> class construction or subsequent, successful call of
        %> calculateClusters.  (i.e. A value of 1 refers to the centroid with fewest members,
        %> while a value of C refers to the centroid with the most members (as seen in histogram)
        coiSortOrder;  
        
        %> logical sort order index for the centroids of interest (cois)
        %> identified for analysis and possible comparison.  It is 
        %> initialized to the coiSortOrder's index being true, and the
        %> remaining indices being false.
        coiToggleOrder;

        %> A line handle for updating clustering performace.  Default is
        %> -1, which means that clustering performance is not displayed.
        %> This value is initialized in the constructor based on input
        %> arguments.
        performanceLineHandle;
        
        %> Similar to performance line, but is an axes handle.
        performanceAxesHandle;
        
        %> Text handle to send status updates to via set(textHandle,'string',statusString) type calls.
        statusTextHandle;
 

    end
    
    properties(SetAccess=protected)
        %> Struct with cluster calculation settings.  Fields include
        %> - @c minClusters
        %> - @c maxClusters
        %> - @c clusterThreshold        
        %> - @c method - {'kmeans' (Default),'kmedoids','kmedians'}
        settings;
        
        
        %> struct with X, Y data, and last statusStr calculated during
        %> adaptive k means.
        performanceProgression;
        
        distanceMetric; %> For clustering.  Default is squared euclidean ('sqeuclidean');
        
        %> NxM array of N profiles of length M (M is the centroid
        %> dimensionality)
        loadShapes;
        
        loadShapeIDs;  % more accurrately, the loadShapeParentID or the ID of the subject a load shape is associated with.
        uniqueLoadShapeIDs; % unique participants or load shape generators.
        loadShapeDayOfWeek;  %Nx1 vector with values in [0,6] representing [Sunday, Monday, Tuesday ..., Saturday]
        daysOfInterest; % 7x1 boolean vector representing if the correspondning day of week is of interest.  [1] => Sunday, [2]=> Monday, ... , [7]=> Saturday
        
        
        %> CxM array of C centroids of size M.  Ordered by clustering
        %> output; the original ordering.  Not ordered from 1 to C based on popularity.  To get
        %> popularity index from highest popularity (1) to lowest (C) use:
        %>  coi_index = this.coiSortOrder2Index(sortOrder); 
        %> which converts to match the index the centroid load shape corresponds to.
        centroidShapes;
        
        clusterMemberIndices; %  Cx1 cell with logical indices to load shapes that are members of the centroid of index
        
        sumD;
        
        %> Sorted distribution of centroid shapes by frequency of children load shape members.
        %> (Cx1 vector - where is C is the number centroids)
        histogram;
        
        %> Weekday scores for cluster shapes, sorted according to frequency
        %> of load shape popularity *see histogram note.
        %> (Cx1 vector - where is C is the number clusters)
        weekdayScores;
        
        %> @brief Numeric value indicating current state: values include
        %> - 0 Ready
        %> - -1 Failed to converge
        %> - 1 Calculating
        %> - -2 User cancelled
        %> - 2 Converged successfully
        calculationState;  
        calinskiIndex;
        silhouetteIndex;
        performanceMetric; %> String which can be one of: {'',''}
        
        %> Criterion for measuring cluster performance.
        performanceCriterion;  %{'CalinskiHarabasz' , 'DaviesBouldin' , 'gap' , 'silhouette'}

        %> Measure of performance.  Currently, this is the Calinski index.
        performanceMeasure;  
        
        % 1xM cell.  Values indicate the 24 hour clock time of each
        % dimension (e.g.     '00:00'    '04:40'    '09:30'    '14:10'
        % '19:00'    '23:50')
        loadShapeTimes;
    end
    
            
    methods        
        function didSet =  setShapeTimes(this, cellOfTimes)
            didSet = false;
            if(iscell(cellOfTimes) && size(cellOfTimes,2)==size(this.loadShapes,2))
                this.loadShapeTimes = cellOfTimes;
                didSet = true;                
            end
        end
         
        % returns the popularity of each cluster, ordered by original
        % index.  Nx1 array with popularity(1) referring to the popularity
        % of cluster index 1.
        function popularity = getPopularityOrder(this)
            popularity = this.coiIndex2SortOrder;
        end
        
        function index = popularity2index(this, sortOrder)
            index = this.coiSortOrder2Index;
            if(nargin>1 && ~isempty(sortOrder))
                index = index(sortOrder);
            end
        end        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c clusterThreshold [1.5]                  
        %> - @c method - {'kmeans','kmedoids','kmedians'}; clustering method.  Default
        %> is kmeans.
        %> @param axesOrLineH Optional axes or line handle for displaying clustering progress.
        %> - If argument is a handle to a MATLAB @b axes, then a line handle
        %> will be added to the axes and adjusted with clustering progress.
        %> - If argument is a handle to a MATLAB @b line, then the handle
        %> will be manipulated directly in its current context (i.e. whatever
        %> axes it currently falls under).
        %> - If argument is not included, empty, or is not a line or
        %> axes handle then progress will only be displayed to the console
        %> (default)
        %> @note Including a handle increases processing time as additional calculations
        %> are made to measuring clustering separation and performance.
        %> @param textHandle Optional text handle to send status updates to via set(textHandle,'string',statusString) type calls.
        %> Status updates are sent to the command window by default.
        %> @param loadShapeIDs Optional Nx1 cell string with load shape source
        %> identifiers (e.g. which participant they came from).
        %> @param loadShapeDayOfWeek Optional Nx1 vector with entries defining day of week
        %> corresponding to the load shape entry found at the same row index
        %> in the loadShapes matrix.  
        %> @param delayedStart Boolean.  If true, the centroids are not
        %> automatically calculated, instead 'calculateClusters()' needs to
        %> be  called directly from the instantiated class.  The default is
        %> 'false': centroids are calculated in the constructor.
        %> @retval Instance of PACluster on success.  Empty matrix on
        %> failure.
        %> @note PACluster can be used apart from Padaco.  For example
        %> obj = PACluster(loadShapes,settings,[],[],loadShapeIDs,loadShapeDayOfWeek)
        % ======================================================================        
        function this = PACluster(loadShapes,settings,axesOrLineH,textHandle,loadShapeIDs,loadShapeDayOfWeek, delayedStart)    
            
            this.init();
            if(nargin<7)
                delayedStart = false;
                if(nargin<6)
                    loadShapeDayOfWeek = [];
                    if(nargin<5)
                        loadShapeIDs = [];
                        if(nargin<4)
                            textHandle = [];
                            if(nargin<3)
                                axesOrLineH = [];
                                if(nargin<2)
                                    settings = [];
                                end
                            end
                        end
                    end
                end
            end

            defaultSettings = PAStatTool.getDefaultParameters();
            if(isempty(settings))
                this.settings = defaultSettings;
            else
                % This call ensures that we have at a minimum, the default parameter field-values in widgetSettings.
                % And eliminates later calls to determine if a field exists
                % or not in the input widgetSettings parameter
                this.settings = mergeStruct(defaultSettings,settings);
            end
            
            if(~isempty(textHandle) && ishandle(textHandle) && strcmpi(get(textHandle,'type'),'uicontrol') && strcmpi(get(textHandle,'style'),'text'))
                this.statusTextHandle = textHandle;
            else
                this.statusTextHandle = -1;
            end
            this.distanceMetric = 'sqeuclidean'; %> For clustering.  Default is squared euclidean ('sqeuclidean');
            %'sqeuclidean','cityblock','cosine','correlation','hamming'
            if(~isempty(axesOrLineH) && ishandle(axesOrLineH))
                handleType = get(axesOrLineH,'type');
                if(strcmpi(handleType,'axes'))
                    this.performanceAxesHandle = axesOrLineH;
                    this.performanceLineHandle = line('parent',axesOrLineH,'xdata',nan,'ydata',nan,'linestyle',':','marker','o','markerfacecolor','b','markeredgecolor','k','markersize',10);
                elseif(strcmpi(handleType,'line'))
                    this.performanceLineHandle = axesOrLineH;
                    set(this.performanceLineHandle,'xdata',nan,'ydata',nan,'linestyle',':','marker','o','markerfacecolor','b','markeredgecolor','k','markersize',10);
                    this.performanceAxesHandle = get(axesOrLineH,'parent');
                else
                    this.performanceAxesHandle = -1;
                    this.performanceLineHandle = -1;
                end
            else
                this.performanceLineHandle = -1;
            end

            this.performanceCriterion = 'CalinskiHarabasz';
            this.performanceCriterion = 'silhouette';
            
            this.performanceMeasure = [];
            
            
            %/ Do not let K start off higher than 
            % And don't let it fall to less than 1.
            this.settings.minClusters = max(1,min(floor(size(loadShapes,1)/2),settings.minClusters));
            this.settings.maxClusters = ceil(size(loadShapes,1)/2);
            
            this.loadShapes = loadShapes;
            this.loadShapeIDs = loadShapeIDs;
            this.loadShapeDayOfWeek = loadShapeDayOfWeek;
            this.uniqueLoadShapeIDs = unique(loadShapeIDs);
            
            this.calculationState = 0; % we are ready.
            if(~delayedStart)
                this.calculateClusters();
            end
        end
        
        
        function [didExport, resultMsg] = exportToDisk(this, clusterSettingsStruct, nonwearStruct, exportPath)
            didExport = false;
            
            if(nargin>3)
                if(isdir(exportPath))
                    this.setExportPath(exportPath);
                else
                    % keep the passed exportPath, which will fail below: ~isdir(exportPath)
                end
            else
                exportPath = this.getExportPath();
            end
            if(~isdir(exportPath))                
                msg = sprintf('Export path does not exist.  Nothing done.\nExport path: %s',exportPath);
            else
                if(nargin<4)
                    nonwearStruct = [];
                end
                
                [covHeader, covDataStr] = this.exportFrequencyCovariates();
                [weekdayCovHeader, weekdayCovDataStr] = this.exportWeekDayCovariates(nonwearStruct);                
                [shapesHeaderStr, shapesStr] = this.exportClusterShapes();
                [summaryHeaderStr, summaryStr] = this.exportClusterSummary();                
                
                timeStamp = datestr(now,'DDmmmYYYY');
                
                cov2Filename = fullfile(exportPath,sprintf('cluster_by_weekday_%s.csv',timeStamp));
                covFilename = fullfile(exportPath,sprintf('cluster_frequency_%s.csv',timeStamp));
                shapesFilename = fullfile(exportPath,sprintf('cluster_shapes_%s.csv',timeStamp));
                summaryFilename = fullfile(exportPath,sprintf('cluster_summary_%s.csv',timeStamp));
                settingsFilename = fullfile(exportPath,sprintf('padaco_config_%s.txt',timeStamp));
                
                covFid = fopen(covFilename,'w');
                
                if(covFid>1)
                    fprintf(covFid,'%s\n',covHeader);
                    fprintf(covFid,covDataStr);
                    msg = sprintf('Cluster frequency data saved to:\n\t%s\n',covFilename);
                    fclose(covFid);
                else
                    msg = sprintf('Cluster frequency data NOT saved.  Could not open file (%s) for writing!\n ',covFilename);
                end
                
                cov2Fid = fopen(cov2Filename,'w');
                
                if(cov2Fid>1)
                    fprintf(cov2Fid,'%s\n',weekdayCovHeader);
                    fprintf(cov2Fid,weekdayCovDataStr);
                    msg = sprintf('%sCluster by weekday data saved to:\n\t%s\n',msg,cov2Filename);
                    fclose(cov2Fid);
                else
                    msg = sprintf('%sCluster by weekday data NOT saved.  Could not open file (%s) for writing!\n ',msg,cov2Filename);
                end
                
                shapesFid = fopen(shapesFilename,'w');
                if(shapesFid>1)
                    fprintf(shapesFid,'%s\n%s',shapesHeaderStr,shapesStr);
                    msg = sprintf('%sCluster shapes saved to:\n\t%s\n',msg,shapesFilename);
                    fclose(shapesFid);
                else
                    msg = sprintf('%sCluster shapes NOT saved.  Could not open file (%s) for writing!\n ',msg,shapesFilename);
                end
                
                summaryFid = fopen(summaryFilename,'w');
                if(summaryFid>1)
                    fprintf(summaryFid,'%s\n%s',summaryHeaderStr,summaryStr);
                    msg = sprintf('%sCluster summary saved to:\n\t%s\n',msg,summaryFilename);
                    fclose(summaryFid);
                else
                    msg = sprintf('%sCluster summary NOT saved.  Could not open file (%s) for writing!\n ',msg,summaryFilename);
                end                
                
                settingsFid = fopen(settingsFilename,'w');
                
                if(settingsFid>1)                    
                    fprintf(settingsFid,['-Last saved: %s',newline,newline],datestr(now)); %want to include the '-' sign to prevent this line from getting loaded in the loadFromFile function (i.e. it breaks the regular expression pattern that is used to load everything else).
                
                    PASettings.saveStruct(settingsFid,clusterSettingsStruct);
                    msg = sprintf('%sPadaco cluster settings saved to:\n\t%s\n',msg,settingsFilename);
                    fclose(settingsFid);
                    didExport = true;
                else
                    msg = sprintf('%sPadaco cluster settings NOT saved.  Could not open file (%s) for writing!\n ',msg,settingsFilename);
                end
            end
            resultMsg = msg;
        end
        
        function [headerStr, dataStr] = exportWeekDayCovariates(this, nwStruct)
            csMat = this.getCovariateMat();
            headerStr = sprintf('# memberID, Day of week (Sun=0 to Sat=6), Cluster index, cluster popularity (1 is most and %d is least)',max(csMat(:,end)));
            strFmt = ['%i',repmat(', %i',1,size(csMat,2)-1),'\n'];  % Make rows ('\n') of comma separated integers (', %i')
            
            if(nargin>1 && ~isempty(nwStruct) && isstruct(nwStruct) && ~isempty(nwStruct.rows))
               headerStr = sprintf('%s, Contains nonwear (%s)',headerStr,nwStruct.method); 
               strFmt = [strFmt(1:end-2),',%d\n'];               
               if(isfield(nwStruct,'featureStruct') && ~isempty(nwStruct.featureStruct))
                   nwFeatureStruct = nwStruct.featureStruct;
                   missingValues = zeros(size(nwFeatureStruct.studyIDs,1),2);
                   nwMat = [nwFeatureStruct.studyIDs(:),nwFeatureStruct.startDaysOfWeek(:),missingValues];

                   nonwearFlags = [ zeros(size(csMat,1),1)
                       ones(size(nwMat,1),1)     ];                   
                   csMat = [csMat
                            nwMat];
               else
                   nonwearFlags = nwStruct.rows;
               end
               csMat = [csMat, nonwearFlags];
            end
            dataStr = sprintf(strFmt,csMat'); % Need to transpose here because arguments to sprintf are taken in column order, but I am output by row.
        end
        
        function [headerStr, membersStr] = exportFrequencyCovariates(this,frequencyOf)
            cs = this.getCovariateStruct();
            if(nargin<2 || isempty(frequencyOf))
                frequencyOf = 'id';
            end
            if(strcmpi(frequencyOf,'id'))                
                headerStr = sprintf('# Cluster frequency (by index) for members listed in first column.  ''Cluster #'' refers to the centroid ID listed in the companion text file.  The values in these columns represent the number of times the subject ID was a member of that cluster index.\n# memberID');       
            else
               headerStr = sprintf('# Cluster frequency (by popularity) for members listed in first column.  ''Popularity #'' refers to the popularity of the centroid ID listed in the companion text file.  The values in these columns represent the number of times the subject ID was a member of the cluster with that popularity.\n');
            end
            
            for c=1:numel(cs.(frequencyOf).colnames)
                colName = cs.(frequencyOf).colnames{c};
                headerStr = sprintf('%s, %s', headerStr, colName);
            end

            
            %id (index) or popularity;
            allData = [cs.memberIDs,cs.(frequencyOf).values];
            
            strFmt = ['%i',repmat(', %i',1,size(allData,2)-1),'\n'];  % Make rows ('\n') of comma separated integers (', %i') 
            membersStr = sprintf(strFmt,allData'); % Need to transpose here because arguments to sprintf are taken in column order, but I am output by row.
        end
        
        %> @brief Returns centroid shape in comma separated value (csv) format.
        %> @param this Instance of PACluster
        %> @retval headerStr Header line; helpful to place at the top of a
        %> file.  Contains centroid index and popularity followed by
        %> time stamps corresponding to centroid shape values.
        %> @retval centroidStr String containg N lines for N centroids.
        %> The nth line describes the nth centroid
        function [headerStr, shapeStr] = exportClusterShapes(this)
            shapeStr = '';
            
            if(this.getNumClusters<=0)
                headerStr = '# No clusters found!';
            else
                shapeTimesInCSV = cell2str(this.loadShapeTimes,',');
                headerStr = sprintf('# Cluster index, Popularity (1 = highest), %s',shapeTimesInCSV);
                
                for sortOrder=1:this.getNumClusters()
                    coi = this.getClusterOfInterest(sortOrder);
                    coiStr = sprintf('%i, %i',coi.index,coi.sortOrder);
                    coiShapeStr = sprintf(', %f',coi.shape);
                    shapeStr = sprintf('%s%s%s\n',shapeStr,coiStr,coiShapeStr);
                end                
            end
        end
        
        %> @brief Returns text summarizing centroid membership distributions
        %> in a comma separated value (csv) format.
        %> @param this Instance of PACluster
        %> @retval headerStr Header line; helpful to place at the top of a
        %> file.  
        %> @retval summaryStr String containg N lines for N centroids.
        %> The nth line describes the nth centroid according to the descriptions given
        %> by the header string.
        function [headerStr, summaryStr] = exportClusterSummary(this)            
            summaryStr = '';
            
            if(this.getNumClusters<=0)
                headerStr = '# No clusters found!';
            else
                % print header
                headerStr = sprintf('# Cluster index, popularity (1 = highest), loadshapes, unique participants, weekday score');
                for d=1:numel(this.WEEKDAY_ORDER)
                    headerStr = sprintf('%s, %s (%d)',headerStr,this.WEEKDAY_LABELS{d},this.WEEKDAY_ORDER(d));
                end

                for sortOrder=1:this.getNumClusters()
                    coi = this.getClusterOfInterest(sortOrder);
                    coiStr = sprintf('%i, %i, %i, %i, %+0.3f',coi.index,coi.sortOrder,coi.numMembers,coi.numUniqueParticipants, coi.weekdayScore);
                    dayStr = sprintf(', %i',coi.dayOfWeek.count);
                    summaryStr = sprintf('%s%s%s\n',summaryStr,coiStr,dayStr);
                end
            end
        end
        
        function value = getParam(this, paramName)
            switch(lower(paramName))
                case 'silhouetteindex'
                    %value = this.getSilhouetteIndex();                                        
                    value = this.silhouetteIndex;                    
                
                case {'numclusters','clustercount'}
                    value = this.getNumClusters();
                case {'numloadshapes','loadshapecount'}
                    value = this.getNumLoadShapes();
                case {'calinskiindex','calinski','calinskiharabasz'}
                    value = this.calinskiIndex;
                otherwise
                    fprintf(1,'Unrecognized named parameter ''%s''',paramName);
                    value = nan;
            end
        end
                            
        function silhouetteIndex = getSilhouetteIndex(this)
            silhouetteIndex = mean(this.getSilhouette());
        end
        
        function [silh, varargout] = getSilhouette(this)
            if(this.numClusters==0)
                silh = NaN;
                fprintf(1,'Warning no centroids exist.  Silhouette returning NaN\n');
            else                         
                if(nargout>1)
                    [silh, varargout{1}] = silhouette(this.loadShapes, this.loadshapeIndex2centroidIndexMap,this.distanceMetric);
                else
                    silh = silhouette(this.loadShapes, this.loadshapeIndex2centroidIndexMap,this.distanceMetric);
                end
                    % silhouette(X, idx,'distance','sqEuclidean');
                    % 
            end
        end        
                
        %> @brief Validation metric for cluster separation.   Useful in determining if clusters are well separated.  
        %> If clusters are not well separated, then the Adaptive K-means threshold should be adjusted according to the segmentation resolution desired.
        %> @note See Calinski, T., and J. Harabasz. "A dendrite method for cluster analysis." Communications in Statistics. Vol. 3, No. 1, 1974, pp. 1?27.
        %> @note See also http://www.mathworks.com/help/stats/clustering.evaluation.calinskiharabaszevaluation-class.html 
        %> @param Vector of output from mapping loadShapes to parent
        %> centroids.
        %> @param Clusters calculated via kmeans
        %> @param sum of euclidean distances
        %> @retval The Calinzki-Harabasz index
        function calinskiIndex = getCalinskiHarabaszIndex(this,loadShapeMap,centroids,sumD)
            if(this.numClusters==0)
                calinskiIndex = NaN;
                fprintf(1,'Warning no clusters exist.  Calinski index returning NaN\n');
            else             
                calinskiIndex = calinski(loadShapeMap, centroids, sumD);
            end
        end
        
        
        %> @brief Removes any graphic handle to references.  This is
        %> a helpful precursor to calling 'save' on the object, as it
        %> avoids the issue of recreating the figure handles when the
        %> object is later loaded with a 'load' call.
        function removeHandleReferences(this)
            this.statusTextHandle = 1;
            this.performanceAxesHandle = -1;
            this.performanceLineHandle = -1; 
            % any listeners?
        end
        
        
        % ======================================================================
        %> @brief Sets the calculationState property to the cancel state value (-2).
        %> @param this Instance of PACluster.
        % ======================================================================
        function cancelCalculations(this, varargin)
            this.calculationState = -2;  %User cancelled
        end
        
        % ======================================================================
        %> @brief Checks if we have a user cancel state
        %> @param this Instance of PACluster.
        %> @retval userCancel Boolean: true if calculationState is equal to
        %> user cancel value (-2)
        % ======================================================================
        function  userCancel = getUserCancelled(this)
            userCancel = this.calculationState == -2;  
        end
        
        % ======================================================================
        %> @brief Determines if clustering failed or succeeded (i.e. do centroidShapes
        %> exist)
        %> @param Instance of PACluster        
        %> @retval failedState - boolean
        %> - @c true - The clustering failed
        %> - @c false - The clustering succeeded.
        % ======================================================================
        function failedState = failedToConverge(this)
            failedState = isempty(this.centroidShapes);
        end        
        
        
        % If sortOrder is true, then weekdayScores are returned in the same
        % order as the clusters when sorted by popularity.  Otherwise,
        % weekdayScores are returned in the same order as original cluster
        % index the score corresponds to.
        function scores = getWeekdayScores(this, sortOrder)
            if(nargin<2)
                sortOrder = false;
            end
            scores = this.weekdayScores;
            if(sortOrder)
                % Scores are in order of original index,  so if you want
                % them sorted, and give it a sorted index (e.g. 1 for most
                % popular, then this will transform it such the 1 will give
                % you the most popular index, perhaps 37 for example.
                % Whereas histogram is already in sorted order, so
                % histogram(1) will be the most popular item, and
                % scores(this.coiSortOrder2Index(1)) will provide the
                % matching weekday score for it. @hyatt 2/15/2019
                scores = scores(this.coiSortOrder2Index);
            end
        end
        
        function distribution = getHistogram(this,histogramOf)
            if(nargin<2 || isempty(histogramOf))
                histogramOf = 'loadshapes';
            end
            if(strcmpi(histogramOf,'participants'))
                distribution = this.histogram.participants;
            else
                distribution = this.histogram.loadshapes;
            end
        end
        
        % ======================================================================
        %> @brief Returns the number of centroids/clusters obtained.
        %> @param Instance of PACluster        
        %> @retval Number of centroids/clusters found.
        % ======================================================================
        function n = numClusters(this)
            n = size(this.centroidShapes,1);
        end
        
        % ======================================================================
        %> @brief Alias for numClusters.
        %> @param Instance of PACluster        
        %> @retval Number of centroids/clusters found.
        % ======================================================================
        function n = getNumClusters(this)
            n = this.numClusters();
        end
        
        % ======================================================================
        %> @brief Returns the number of load shapes clustered.
        %> @param Instance of PACluster        
        %> @retval Number of load shapes clustered.
        % ======================================================================
        function n = numLoadShapes(this)
            n = size(this.loadShapes,1);
        end        
        
        % ======================================================================
        %> @brief Alias for numLoadShapes.
        %> @param Instance of PACluster        
        %> @retval Number of load shapes clustered.
        % ======================================================================
        function n = getNumLoadShapes(this)
            n = this.numLoadShapes();
        end
        
        % ======================================================================
        %> @brief Initializes (sets to empty) member variables.  
        %> @param Instance of PACluster        
        %> @note Initialzed member variables include
        %> - loadShape2ClusterShapeMap
        %> - centroidShapes
        %> - histogram
        %> - loadShapes
        % %> - sortIndices
        %> - coiSortOrder        
        % ======================================================================                
        function init(this)
            this.loadshapeIndex2centroidIndexMap = [];
            this.centroidShapes = [];
            this.histogram.loadshapes = [];
            this.histogram.participants = [];            
            this.weekdayScores = [];
            this.loadShapes = [];
            % this.sortIndices = [];
            this.coiSortOrder = [];
            this.coiToggleOrder = [];
            this.loadShapeDayOfWeek = [];  %Nx1 vector with values in [0,6] representing [Sunday, Monday, Tuesday ..., Saturday]
            this.daysOfInterest = true(7,1); % 7x1 boolean vector representing if the correspondning day of week is of interest.  [1] => Sunday, [2]=> Monday, ... , [7]=> Saturday
            
        end
                
        function didChange = toggleOnNextCOI(this)
            didChange = this.toggleOnCOISortOrder(this.coiSortOrder+1);            
        end
        
        function didChange = toggleOnPreviousCOI(this)
            didChange = this.toggleOnCOISortOrder(this.coiSortOrder-1);
        end
        
        %> @brief This sets the given index into coiToggleOrder to true
        %> and also sets the coiSortOrder value to the given index.  This
        %> performs similarly to setCOISortOrder, but here the
        %> coiToggleOrder is not reset (i.e. all toggles turned off).
        %> @param this Instance of PACluster
        %> @param sortOrder
        %> @retval didChange A boolean response
        %> - @b True if the coiToggleOrder(sortOrder) was set to true
        %> and coiSortOrder was set equal to sortOrder
        %> - @b False otherwise
        function didChange = toggleOnCOISortOrder(this, sortOrder)
            sortOrder = round(sortOrder);
            if(sortOrder<=this.numClusters() && sortOrder>0)
                this.coiSortOrder = sortOrder;
                this.coiToggleOrder(sortOrder) = true;
                didChange = true;
            else
                didChange = false;
            end
        end
        
        function didChange = increaseCOISortOrder(this)
            didChange = this.setCOISortOrder(this.coiSortOrder+1);
        end
        
        function didChange = decreaseCOISortOrder(this)
            didChange = this.setCOISortOrder(this.coiSortOrder-1);
        end
        
        function didChange = setCOISortOrder(this, sortOrder)
            sortOrder = round(sortOrder);
            if(sortOrder<=this.numClusters() && sortOrder>0)
                this.coiSortOrder = sortOrder;                
                this.coiToggleOrder = false(1,this.getNumClusters());
                %  this.coiToggleOrder = false(size(sortOrder));
                this.coiToggleOrder(sortOrder) = true;
                didChange = true;
                
            % handle corner case at the edges when we are trying to
            % increase the sort order past the maximum value, which is not
            % allowed, but have multiple centroids shown currently (which
            % is allowed) and want the centroids to be deselected (Which is
            % allowed) except for the most current one (this.coiSortOrder).
            elseif(sum(this.coiToggleOrder(:)==true)>1)
                this.coiToggleOrder(:) = false;
                this.coiToggleOrder(this.coiSortOrder)=true;
                didChange = true;
                
            else
                didChange = false;
            end
        end  
        
        function toggleCOISortOrder(this, toggleSortIndex)
            if(toggleSortIndex>0 && toggleSortIndex<=this.numClusters())
                this.coiToggleOrder(toggleSortIndex) = ~this.coiToggleOrder(toggleSortIndex);
                if(this.coiToggleOrder(toggleSortIndex))
                    this.coiSortOrder = toggleSortIndex;
                else
                    this.coiSortOrder = find(this.coiToggleOrder,1);
                    
                    % toggle back on if there is only one..
                    if(isempty(this.coiSortOrder))
                        this.toggleCOISortOrder(toggleSortIndex);
                    end
                        
                end
            end
        end
        
        function daysOfInterest = getDaysOfInterest(this)
            daysOfInterest = this.daysOfInterest;
        end
        
        function didToggle = toggleDayOfInterestOrder(this, dayOfInterest)
            if(nargin > 1 && ~isempty(dayOfInterest) && dayOfInterest>=0 && dayOfInterest<=6)
                dayOfInterest = dayOfInterest+1;
                this.daysOfInterest(dayOfInterest) = ~this.daysOfInterest(dayOfInterest);
                didToggle = true;
            else
                didToggle = false;
            end
        end
        
        function performance = getClusteringPerformance(this)
            performance = this.performanceMeasure;
        end
                
        %==================================================================
        %> @brief Returns all member shapes and associated day of week
        %> for the corresponding memberID
        %> @param this Instance of PACluster.
        %> @param memberID The ID of the member shapes to retrieve.
        %> @retval NxM matrix of N member shapes of length M attributed to memberID
        %> @retval Nx1 vector containing day of week that the nth load shape occurred on.  
        %> @retval Nx1 vector containing centroid index corresponding to the nth loadshape.
        %> @retval NxM matrix of N centroids associated with the N member shapes attributed to memberID        
        function [memberLoadShapes, memberLoadShapeDayOfWeek, memberClusterInd, memberClusterShapes] = getMemberShapesForID(this, memberID)
            matchInd = memberID==this.loadShapeIDs;
            memberLoadShapes = this.loadShapes(matchInd,:);
            memberLoadShapeDayOfWeek = this.loadShapeDayOfWeek(matchInd);
            
            memberClusterInd = this.loadshapeIndex2centroidIndexMap(matchInd);
            
            %> CxM array of C centroids of size M.
            memberClusterShapes = this.centroidShapes(memberClusterInd,:);
        end
        
        %==================================================================
        %> @brief Returns the index of centroid matching the current sort
        %> order value (i.e. of member variable @c coiSortOrder) or of the
        %> input sortOrder provided.
        %> @param this Instance of PACluster.
        %> @param sortOrder (Optional) sort order for the centroid of interest to
        %> retrive the index of.  If not provided, the value of member variable @c coiSortOrder is used.
        %> @retval coiIndex The centroid index or tag. 
        %> @note The coiIndex is the original index given to it during clustering.  
        %> The sortOrder is the centroids rank in comparison to all
        %> centroids found during clustering, with 1 being the least popular
        %> and N (the number of centroids found) being the most popular.
        %==================================================================
        function coiIndex = getCOIIndex(this,sortOrder)
            if(nargin<2 || isempty(sortOrder) || sortOrder<0 || sortOrder>this.numClusters())
                sortOrder = this.coiSortOrder;
            end
            % convert to match the index the centroid load shape corresponds to.
            coiIndex = this.coiSortOrder2Index(sortOrder);           
             
        end
        
        function sortOrder = getCOISortOrder(this,coiIndex)
            if(nargin<2 || isempty(coiIndex) || coiIndex<0 || coiIndex>this.numClusters())
                sortOrder = this.coiSortOrder;
            else
                sortOrder = this.coiIndex2SortOrder(coiIndex);
            end
        end
        
        % Returns an array of sort order values, one per centroids of
        % interest.  (or just a single value when only one COI exists).
        function sortOrders = getAllCOISortOrders(this)
            sortOrders = find(this.coiToggleOrder);            
        end
        
        function toggleOrder = getCOIToggleOrder(this)
            toggleOrder = this.coiToggleOrder;
        end
        
        % ======================================================================
        %> @brief Returns a descriptive struct for the centroid of interest (coi) 
        %> which is determined by the member variable coiSortOrder.
        %> @param Instance of PACluster
        %> @param sortOrder Optional index to use to obtain a centroid of
        %> interest according to the given sort order ; default is to use the
        %> value of this.coiSortOrder.
        %> @retval Structure for centroid of interest.  Fields include
        %> - @c sortOrder The sort order of coi.  If all centroids are placed in
        %> a line numbering from 1 to the number of centroids in increasing order of
        %> the number of load shapes the centroid has clustered to it, then the sort order
        %> is the value of the number on the line for the coi.  The sort order of
        %> a coi having the fewest number of load shape members is 1, while the sort
        %> sort order of a coi having the largest proportion of load shape members has 
        %> the value C (centroid count).
        %> - @c index - id of the coi.  This is its original, unsorted
        %> index value which is the range of [1, C]
        %> - @c shape - 1xM vector.  The coi.
        %> - @c memberIndices = Lx1 logical vector indices of member shapes
        %> obtained from the loadShapes member variable, for the coi.  L is
        %> the number of load shapes (see numLoadShapes()).
        %> @note memberShapes = loadShapes(memberIndices,:)
        %> - @c memberShapes - NxM array of load shapes clustered to the coi.
        %> - @c numMembers - N, the number of load shapes clustered to the coi.
        % ======================================================================        
        function coi = getClusterOfInterest(this, sortOrder)
            if(nargin<2 || isempty(sortOrder) || sortOrder<0 || sortOrder>this.numClusters())
                sortOrder = this.coiSortOrder;
            end
            
            % order is sorted from 1: most popular to numClusters: least popular
            coi.sortOrder = sortOrder;
            
            % convert to match the index the centroid load shape corresponds to.
            coi.index = this.coiSortOrder2Index(coi.sortOrder);     
            
            % centroid shape for the centroid index.
            coi.shape = this.centroidShapes(coi.index,:);
            
            % member shapes which have that same index.  The
            % loadshapeIndex2centroidIndexMap row index corresponds to the member index,
            % while the value at that row corresponds to the centroid
            % index.  We want the rows with the centroid index:            
            coi.memberIndices = (coi.index==this.loadshapeIndex2centroidIndexMap);
            
            % Now we can pull the member variables that were
            % clustered to the centroid index of interest.
            coi.memberShapes = this.loadShapes(coi.memberIndices,:);
            coi.memberIDs = this.loadShapeIDs(coi.memberIndices,:);
            coi.numMembers = size(coi.memberShapes,1); 
            % coi.numMembers = this.histogram.loadshapes(coi.sortOrder);            
            coi.numUniqueParticipants = this.histogram.participants(coi.sortOrder);
            coi.weekdayScore = this.weekdayScores(coi.index);
            coi.dayOfWeek.memberIndices = coi.memberIndices  & ismember(this.loadShapeDayOfWeek,this.WEEKDAY_ORDER(this.daysOfInterest));
            coi.dayOfWeek.memberShapes = this.loadShapes(coi.dayOfWeek.memberIndices,:);
            coi.dayOfWeek.memberIDs = this.loadShapeIDs(coi.dayOfWeek.memberIndices,:);
            coi.dayOfWeek.numMembers = size(coi.dayOfWeek.memberShapes,1);
            coi.dayOfWeek.startDays = this.loadShapeDayOfWeek(coi.memberIndices);
            coi.dayOfWeek.count = histc(coi.dayOfWeek.startDays,this.WEEKDAY_ORDER);

%              coi.dayOfWeek.score = this.WEEKDAY_WEIGHT*coi.dayOfWeek.count(:)/sum(coi.dayOfWeek.count);
             coi.dayOfWeek.score = (this.WEEKDAY_SCORE.*this.WEEKDAY_WEIGHT*coi.dayOfWeek.count(:))/(this.WEEKDAY_WEIGHT*coi.dayOfWeek.count(:));
        end

        %> @brief Returns the loadshape IDs.  These are the identifiers number of centroids that are currently of
        %> interest, based on the number of positive indices flagged in
        %> coiToggleOrder.
        %> @param this Instance of PACluster.
        %> @retval loadShapeIDs Parent identifier for each load shape.
        %> Duplicate values in loadShapeIDs represent the same source (e.g. a
        %> specific person).
        function loadShapeIDs = getLoadShapeIDs(this)
            loadShapeIDs = this.loadShapeIDs;
        end
                
        function uniqueLoadShapeIDs = getUniqueLoadShapeIDs(this)
            uniqueLoadShapeIDs = this.uniqueLoadShapeIDs;
        end
        
        function uniqueCount = getUniqueLoadShapeIDsCount(this)
            uniqueCount = numel(this.uniqueLoadShapeIDs);
        end
        
        %> @brief Returns the number of centroids that are currently of
        %> interest, based on the number of positive indices flagged in
        %> coiToggleOrder.
        %> @param this Instance of PACluster.
        %> @retval numCOIs Number of centroids currently of interest: value
        %> is in the range [1, this.numClusters].
        function numCOIs = getClustersOfInterestCount(this)
            numCOIs = sum(this.coiToggleOrder);
        end
        
        %> @brief Returns the number of centroids that are currently of
        %> interest, based on the number of positive indices flagged in
        %> coiToggleOrder.
        %> @param this Instance of PACluster.
        %> @retval cois Cell of centroid of interest structs.  See
        %> getClusterOfInterest for description of centroid of interest
        %> struct.
        function cois = getClustersOfInterest(this)
            numCOIs = this.getClustersOfInterestCount();
            if(numCOIs<=1)
                cois = {this.getClusterOfInterest()};
            else
                cois = cell(numCOIs,1);
                coiSortOrders = find(this.coiToggleOrder);
                for c=1:numel(coiSortOrders)
                    cois{c} = this.getClusterOfInterest(coiSortOrders(c));
                end
            end
        end
        
        % ======================================================================
        %> @brief Clusters input load shapes by centroid using adaptive
        %> k-means, determines the distribution of centroids by load shape
        %> frequency, and stores the sorted centroids, load shapes, and
        %> distribution, and sorted indices vector as member variables.
        %> See reset() method for a list of instance variables set (or reset on
        %> failure) from this method.
        %> @param Instance of PACluster
        %> @param inputLoadShapes
        %> @param Structure of centroid configuration parameters.  These
        %> are passed to adaptiveKmeans method.        
        % ======================================================================
        function calculateClusters(this, inputLoadShapes, inputSettings)
            this.calculationState = 1;  % Calculating centroid
            if(nargin<3)
                inputSettings = this.settings;
                if(nargin<2)
                    inputLoadShapes = this.loadShapes;
                end
            end
            
            %             inputSettings.clusterMethod = 'kmedians';
            % inputSettings.clusterMethod = 'kmedoids';
            if(strcmpi(inputSettings.clusterMethod,'kmedians'))
                if(ishandle(this.statusTextHandle))
                    set(this.statusTextHandle ,'string',{sprintf('Performing accelerated k-medians clustering of %u loadshapes with a threshold of %0.3f',this.numLoadShapes(),this.settings.clusterThreshold)});
                end
                [this.loadshapeIndex2centroidIndexMap, this.centroidShapes, this.performanceMeasure, this.performanceProgression, this.sumD] = deal([],[],[],[],[]);
                fprintf(1,'Empty results given.  Use ''kemedoids'' instead.\n');
            elseif(strcmpi(inputSettings.clusterMethod,'kmedoids'))
                if(ishandle(this.statusTextHandle))
                    set(this.statusTextHandle ,'string',{sprintf('Performing adaptive k-medoids clustering of %u loadshapes with a threshold of %0.3f',this.numLoadShapes(),this.settings.clusterThreshold)});
                end
                [this.loadshapeIndex2centroidIndexMap, this.centroidShapes, this.performanceMeasure, this.performanceProgression, this.sumD] = this.adaptiveKmedoids(inputLoadShapes,inputSettings,this.performanceAxesHandle,this.statusTextHandle);
            elseif(strcmpi(inputSettings.clusterMethod,'kmeans'))
                
                if(ishandle(this.statusTextHandle))
                    set(this.statusTextHandle ,'string',{sprintf('Performing adaptive k-means clustering of %u loadshapes with a threshold of %0.3f',this.numLoadShapes(),this.settings.clusterThreshold)});
                end
                [this.loadshapeIndex2centroidIndexMap, this.centroidShapes, this.performanceMeasure, this.performanceProgression, this.sumD] = this.adaptiveKmeans(inputLoadShapes,inputSettings,this.performanceAxesHandle,this.statusTextHandle);
            end
            
            if(~isempty(this.centroidShapes))          
                
                % It is possible that we overdid it and have unassigned
                % clusters here.  
                uniqueIndices = unique(this.loadshapeIndex2centroidIndexMap);
                possibleIndices = 1:size(this.centroidShapes,1);
                % Return values that are possible but not found;  Note, the order matters here; need possible to go first
                unassignedIndices = setdiff(possibleIndices,uniqueIndices); 
                numUnassigned = numel(unassignedIndices);
                
                % Potential problem here: if unassigned indices are not the last
                % row indices of centroid shapes and we remove them,
                % then the unique indices are no longer going to be valid,
                % but point to indices outside the now consolidated
                % centroid shapes matrix.  Catch this possibility with an
                % if statement for now, and *perhaps* come back later and
                % more robustly handle this case with a remapping of the
                % centroid shapes and load shape map vector.
                if(numUnassigned>0 && min(unassignedIndices)>max(uniqueIndices))
                    this.centroidShapes(unassignedIndices,:)=[];
                    msg = sprintf('Removing %d unassigned centroids.', numUnassigned);
                    if(ishandle(this.statusTextHandle))
                        set(this.statusTextHandle ,'string',{msg});
                    end
                    fprintf(1,'%s\n',msg);
                end
                [this.histogram.loadshapes, this.centroidSortMap] = this.calculateAndSortDistribution(this.loadshapeIndex2centroidIndexMap);%  was -->       calculateAndSortDistribution(this.loadshapeIndex2centroidIndexMap);
                
                this.histogram.participants = zeros(size(this.histogram.loadshapes));
                
                this.coiSortOrder2Index = this.centroidSortMap;  % coiSortOrder2Index(c) contains the original centroid index that corresponds to the c_th most popular position 
                [~,this.coiIndex2SortOrder] = sort(this.centroidSortMap,1,'ascend');
                
                K = this.getNumClusters();
                % May need to look into a sparse matrix at some point here ...
                this.clusterMemberIndices = false(K,this.getNumLoadShapes());
                this.weekdayScores = nan(K,1);
                for k = 1:K
                    this.clusterMemberIndices(k,:) = k==this.loadshapeIndex2centroidIndexMap;
                    dayOfWeek.startDays = this.loadShapeDayOfWeek(this.clusterMemberIndices(k,:));
                    dayOfWeek.count = histc(dayOfWeek.startDays,this.WEEKDAY_ORDER);
                    
                    %                     this.weekdayScores(k) = this.WEEKDAY_WEIGHT*dayOfWeek.count(:)/sum(dayOfWeek.count);
                    this.weekdayScores(k) = (this.WEEKDAY_SCORE.*this.WEEKDAY_WEIGHT*dayOfWeek.count(:))/(this.WEEKDAY_WEIGHT*dayOfWeek.count(:));
                    
                    dayOfWeek.memberIDs = this.loadShapeIDs(this.clusterMemberIndices(k,:));
                    
                    % Keep it in the same order as histogram.loadshapes
                    this.histogram.participants(this.coiIndex2SortOrder(k)) = numel(unique(dayOfWeek.memberIDs));
                end
                
                %this.weekdayScores =
                
                % Consider
                % original centroid index, centroid count, (sort order ,/= coiSortOrder2Index)
                % 1, 404, 1, 1
                % 2, 233, 3, 3
                % 3, 50, 4, 4
                % 4, 354, 2, 2
                
                % sorted order, centroid count, original centroid index, coiSortOrder2Index   
                % 1, 404, 1, 1 
                % 2, 354, 4, 4
                % 3, 233, 2, 2
                % 4, 50, 3, 3

                %  [a,b]=sort([1,23,5,6],'ascend');
                %  [c,d] = sort(b,'ascend');  %for testings
                if(~this.setCOISortOrder(1))  % Modified on 1/17/2017 from  ~this.setCOISortOrder(this.numClusters()))
                    fprintf(1,'Warning - could not set the centroid of interest sort order to %u\n',this.numClusters);
                end
                
                if(~this.getUserCancelled())
                    this.calculationState = 2;  % finished calculation.  
                end
                
                idx = this.loadshapeIndex2centroidIndexMap;
                if(strcmpi(this.performanceCriterion,'silhouette'))
                    this.calinskiIndex = this.getCalinskiHarabaszIndex(idx,this.centroidShapes,this.sumD);
                    this.silhouetteIndex = this.performanceMeasure;            
                    fprintf('Calinski Index = %0.2f\n',this.calinskiIndex);
                else
                    this.calinskiIndex = this.performanceMeasure;
                    this.silhouetteIndex = mean(silhouette(this.loadShapes,idx));                    
                    fprintf('Silhouette Index = %0.4f\n',this.silhouetteIndex);
                end
            else
                fprintf('Clustering failed!  No clusters found!\n');
                this.calculationState = -1;  % Calculation failed
                this.calinskiIndex = nan;
                this.silhouetteIndex = nan;
                this.init();     
            end
        end
        
        function [h, yLabelStr] = plotPerformance(this, axesH)
            X = this.performanceProgression.X;
            Y = this.performanceProgression.Y;
%             axesSettings.font = get(axesH,'font');
            fontSettings.fontName = get(axesH,'fontname');
            fontSettings.fontsize = get(axesH,'fontsize');
            
            h=this.plot(axesH,X,Y);
            yLabelStr = this.performanceProgression.criterion;
            ylabel(axesH,yLabelStr);
            
            set(axesH,'xlim',[min(X)-0.5,max(X)+0.5],'ylimmode','auto','ygrid','on',...
                'ytickmode','auto','xtickmode','auto',...
                'xticklabelmode','auto','yticklabelmode','auto',...
                fontSettings);
            title(axesH,this.performanceProgression.statusStr,'fontsize',14);
        end          

        %> @brief Calculates within-cluster sum of squares (WCSS); a metric of cluster tightness.  
        %> @note This measure is not helpful when clusters are not well separated (see @c getCalinskiHarabaszIndex).
        %> @param Instance PACluster
        %> @retval The within-cluster sum of squares (WCSS); a metric of cluster tightness
        function wcss = getWCSS(varargin)
            fprintf(1,'To be finished');
            wcss = [];
        end
        
        %> @brief Returns struct useful for logisitic or linear regression modeling.
        %> @param Instance of PACluster.
        %> @param Optional coi sort order index - index or indices to retrieve
        %> covariate structures of.
        %> @retval Struct with fields defining dependent variables to use in the
        %> model.  Fields include:
        %> - @c values NxM array of counts for M centroids (the covariate index) for N subject
        %> keys.  Clusters are presented in order of popularity (i.e. sort
        %> order).  Thus the first centroid is the most popular.
        %> - @c memberIDs Nx1 array of unique keys corresponding to each row.
        %> - @c colnames 1xM cell string of names describing the covariate columns.
        function covariateStruct = getCovariateStruct(this,optionalCOISortOder)
            subjectIDs = this.getUniqueLoadShapeIDs(); %    unique(this.loadShapeIDs);
            numSubjects = numel(subjectIDs);
            
            centroidPopularityCount = zeros(numSubjects,this.numClusters);
            centroidIDCount = centroidPopularityCount;
            
            for row=1:numSubjects
                try
                    curSubject = subjectIDs(row);
                    centroidIDForSubject = this.loadshapeIndex2centroidIndexMap(this.loadShapeIDs==curSubject);
                    centroidSortOrderForSubject = this.coiIndex2SortOrder(centroidIDForSubject);
                    %centroidSortOrderForSubject = this.coiIndex2SortOrder(this.loadshapeIndex2centroidIndexMap(this.loadShapeIDs==curSubject));
                    
                    for c=1:numel(centroidSortOrderForSubject)
                        coiSO = centroidSortOrderForSubject(c);
                        coiID = centroidIDForSubject(c);
                        centroidPopularityCount(row,coiSO) = centroidPopularityCount(row,coiSO)+1;
                        centroidIDCount(row, coiID) = centroidIDCount(row,coiID)+1;
                    end
                catch me
                    showME(me);
                    rethrow(me);
                end
            end
            
            % This *used* to state that the columns should be in sorted order with #1
            % first (on the left) and #K on the end (far right).  This *was*
            % okay because we have converted centroid indices to centroid
            % sort order indices in the above for loop.
            
            idOrder = 1:this.numClusters;
            sortOrder = this.coiIndex2SortOrder(idOrder);
            idColnames = regexp(sprintf('Cluster #%u\n',idOrder),'\n','split');
            idColnames(end) = [];  %remove the last cell entry which will be empty.
            popularityColnames = regexp(sprintf('Popularity #%u\n',sortOrder),'\n','split');
            popularityColnames(end) = [];  %remove the last cell entry which will be empty.
            

            if(nargin>1 && ~isempty(optionalCOISortOder))
                throw(MException('PA:Cluster:Covariates','Unhandled case with optional sort order.  Needs to be updated in code base'));
                optionalIndexOrder = this.coiSortOrder2Index(optionalCOISortOrder);
                centroidPopularityCount = centroidPopularityCount(:,optionalCOISortOder);
                colnames = colnames(optionalCOISortOder);
            end
            covariateStruct.memberIDs = subjectIDs;
            covariateStruct.id.values = centroidIDCount;
            covariateStruct.id.colnames = idColnames;
            covariateStruct.id.varnames = strrep(strrep(covariateStruct.id.colnames,'#',''),' ',''); % create valid variable names for use with MATLAB table and dataset constructs.
            covariateStruct.popularity.values = centroidPopularityCount;
            covariateStruct.popularity.colnames = popularityColnames;
            covariateStruct.popularity.varnames = strrep(strrep(covariateStruct.popularity.colnames,'#',''),' ',''); % create valid variable names for use with MATLAB table and dataset constructs.
        end
        
        %> @brief Returns Nx3 matrix useful for logisitic or linear regression modeling.
        %> @param Instance of PACluster.
        %> @retval cMat Covariate matrix with following column values
        %> - cMat(:,1) load shape parent ids
        %> - cMat(:,2) load shape day of week (0= sunday, 1 = monday, ... 6 = saturday)
        %> - cMat(:,3) centroid index for that load shape
        %> - cMat(:,4) popularity of the centroid index in that row
        function cMat = getCovariateMat(this)
            clusterIDs = this.loadshapeIndex2centroidIndexMap;
            clusterPopularity = this.coiIndex2SortOrder(clusterIDs);
            cMat = [this.loadShapeIDs, this.loadShapeDayOfWeek, clusterIDs, clusterPopularity];
        end        
        
    end

    methods(Access=protected)
        % ======================================================================
        %> @brief Performs adaptive k-medoids clustering of input data.
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c clusterThreshold [1.5]
        %> - @c method  'kmedoids'
        %> - @c useDefaultRandomizer boolean to set randomizer seed to default
        %> -- @c true Use 'default' for randomizer (rng)
        %> -- @c false (default) Do not update randomizer seed (rng).
        %> @param performanceAxesH GUI handle to display Calinzki index at each iteration (optional)
        %> @note When included, display calinski index at each adaptive k-mediods iteration which is slower.
        %> @param textStatusH GUI text handle to display updates at each iteration (optional)
        %> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
        %> @retval centroids - KxC matrix of cluster centroids.
        %> @retval The Calinski index for the returned idx and centroids
        %> @retrval Struct of X and Y fields containing the progression of
        %> cluster sizes and corresponding Calinski indices obtained for
        %> each iteration of k means.
        % ======================================================================
        function [idx, medoids, performanceIndex, performanceProgression, sumD] = adaptiveKmedoids(this,loadShapes,settings,performanceAxesH,textStatusH)
            performanceIndex = [];
            X = [];
            Y = [];
            idx = [];
            sumD = [];
            % argument checking and validation ....
            if(nargin<5)
                textStatusH = -1;
                if(nargin<4)
                    performanceAxesH = -1;
                    if(nargin<3)                        
                        settings = this.getDefaultParameters();
                        settings.maxClusters = size(loadShapes,1)/2;
                        settings.clusterMethod = 'kmedoids';
                    end
                end
            end
            
            
            if(settings.useDefaultRandomizer)
                rng('default');  % To get same results from run to run...
            end
            
            if(ishandle(textStatusH) && ~(strcmpi(get(textStatusH,'type'),'uicontrol') && strcmpi(get(textStatusH,'style'),'text')))
                fprintf(1,'Input graphic handle is of type %s, but ''text'' type is required.  Status measure will be output to the console window.',get(textStatusH,'type'));
                textStatusH = -1;
            end
            
            if(ishandle(performanceAxesH) && ~strcmpi(get(performanceAxesH,'type'),'axes'))
                fprintf(1,'Input graphic handle is of type %s, but ''axes'' type is required.  Performance measures will not be shown.',get(performanceAxesH,'type'));
                performanceAxesH = -1;
            end
            
            % Make sure we have an axes handle.
            if(ishandle(performanceAxesH))
                %performanceAxesH = axes('parent',calinskiFig,'box','on');
                %calinskiLine = line('xdata',nan,'ydata',nan,'parent',performanceAxesH,'linestyle','none','marker','o');
                xlabel(performanceAxesH,'K');
                ylabel(performanceAxesH,sprintf('%s Index',this.performanceCriterion'));
            end
            
            K = settings.minClusters;
            
            N = size(loadShapes,1);
            firstLoop = true;
            if(settings.maxClusters==0 || N == 0)
                performanceProgression.X = X;
                performanceProgression.Y = Y;
                performanceProgression.statusStr = 'Did not converge: empty data set received for clustering';
                medoids = [];
                
            else
                % prime loop condition since we don't have a do while ...
                numNotCloseEnough = settings.minClusters;
                
                while(numNotCloseEnough>0 && K<=settings.maxClusters && ~this.getUserCancelled())
                    if(~firstLoop)
                        if(numNotCloseEnough==1)
                            statusStr = sprintf('1 cluster was not close enough.  Setting desired number of clusters to %u.',K);
                        else
                            statusStr = sprintf('%u clusters were not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);
                        end
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end-1:end);statusStr]);
                        end
                        
                    else
                        statusStr = sprintf('Initializing desired number of clusters to %u.',K);
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        
                    end
                    
                    tic
                               
                    if(firstLoop)
                        % prime the kmedoids algorithms starting centroids
                        % - Turn this off for reproducibility
                        if(settings.initClusterWithPermutation)
                            medoids = loadShapes(pa_randperm(N,K),:);
                            [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'distance',this.distanceMetric);
                        else
                            [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'distance',this.distanceMetric);
                        end
                        firstLoop = false;
                    else
                        [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'distance',this.distanceMetric);
                    end

                    if(ishandle(performanceAxesH))
                        if(strcmpi(this.performanceCriterion,'silhouette'))
                            performanceIndex  = mean(silhouette(loadShapes,idx,this.distanceMetric));

                        else
                            performanceIndex  = this.getCalinskiHarabaszIndex(idx,medoids,sumD);
                        end
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        PACluster.plot(performanceAxesH,X,Y);
                        
                        %statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);
                        statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                        
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end-1:end);statusStr]);
                        end
                        
                        drawnow();
                        %plot(calinskiAxes,'xdata',X,'ydata',Y);
                        %set(calinskiLine,'xdata',X,'ydata',Y);
                        %set(calinkiAxes,'xlim',[min(X)-5,
                        %max(X)]+5,[min(Y)-10,max(Y)+10]);
                    end
                    
                    
                    removed = sum(isnan(medoids),2)>0;
                    numRemoved = sum(removed);
                    if(numRemoved>0)
                        statusStr = sprintf('%u clusters were dropped during this iteration.',numRemoved);
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        
                        medoids(removed,:)=[];
                        K = K-numRemoved;
                        [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'onlinephase','off','distance',this.distanceMetric);
                        
                        % We performed another clustering step just now, so
                        % show these results.
                        if(ishandle(performanceAxesH))
                            if(strcmpi(this.performanceCriterion,'silhouette'))
                                performanceIndex  = mean(silhouette(loadShapes,idx,this.distanceMetric));
                                
                            else
                                performanceIndex  = this.getCalinskiHarabaszIndex(idx,medoids,sumD);
                            end
                            X(end+1)= K;
                            Y(end+1)=performanceIndex;
                            PACluster.plot(performanceAxesH,X,Y);
                            
                            statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                            
                            fprintf(1,'%s\n',statusStr);
                            if(ishandle(textStatusH))
                                curString = get(textStatusH,'string');
                                set(textStatusH,'string',[curString(end);statusStr]);
                            end
                            
                            drawnow();
                            
                            %set(calinskiLine,'xdata',X,'ydata',Y);
                            %set(calinkiAxes,'xlim',[min(X)-5,
                            %max(X)]+5,[min(Y)-10,max(Y)+10]);
                        end
                    end
                    
                    toc
                    
                    point2centroidDistanceIndices = sub2ind(size(pointToClusterDistances),(1:N)',idx);
                    distanceToClusters = pointToClusterDistances(point2centroidDistanceIndices);
                    sqEuclideanClusters = (sum(medoids.^2,2));
                    
                    clusterThresholds = settings.clusterThreshold*sqEuclideanClusters;
                    notCloseEnoughPoints = distanceToClusters>clusterThresholds(idx);
                    notCloseEnoughClusters = unique(idx(notCloseEnoughPoints));
                    
                    numNotCloseEnough = numel(notCloseEnoughClusters);
                    if(numNotCloseEnough>0)
                        medoids(notCloseEnoughClusters,:)=[];
                        for k=1:numNotCloseEnough
                            curClusterIndex = notCloseEnoughClusters(k);
                            clusteredLoadShapes = loadShapes(idx==curClusterIndex,:);
                            numClusteredLoadShapes = size(clusteredLoadShapes,1);
                            if(numClusteredLoadShapes>1)
                                try
                                    [~,splitClusters] = kmedoids(clusteredLoadShapes,2,'distance',this.distanceMetric);
                                    
                                catch me
                                    showME(me);
                                end
                                medoids = [medoids;splitClusters];
                            else
                                if(numClusteredLoadShapes~=1)
                                    echo(numClusteredLoadShapes); %houston, we have a problem.
                                end
                                numNotCloseEnough = numNotCloseEnough-1;
                                medoids = [medoids;clusteredLoadShapes];
                            end
                        end
                        
                        % reset cluster centers now / batch update
                        K = K+numNotCloseEnough;
                        [~, medoids] = kmedoids(loadShapes,K,'Start',medoids,'onlinephase','off','distance',this.distanceMetric);
                    end
                end  % end adaptive while loop
                
                if(numNotCloseEnough~=0 && ~this.getUserCancelled())
                    statusStr = sprintf('Failed to converge using a maximum limit of %u clusters.',settings.maxClusters);
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end);statusStr]);
                        drawnow();
                    end
                    
                    [performanceIndex, X, Y, idx, medoids] = deal([]);
                else
                    if(this.getUserCancelled())
                        statusStr = sprintf('User cancelled - completing final clustering operation ...');
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'distance',this.distanceMetric);
                    end
                    % This may only pertain to when the user cancelled.
                    % Not sure if it is needed otherwise...
                    if(ishandle(performanceAxesH))
                        if(strcmpi(this.performanceCriterion,'silhouette'))
                            performanceIndex  = mean(silhouette(loadShapes,idx));

                        else
                            performanceIndex  = this.getCalinskiHarabaszIndex(idx,medoids,sumD);                            
                        end
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        PACluster.plot(performanceAxesH,X,Y);
                        
                        statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                        
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        
                        drawnow();
                        
                        %set(calinskiLine,'xdata',X,'ydata',Y);
                        %set(calinkiAxes,'xlim',[min(X)-5,
                        %max(X)]+5,[min(Y)-10,max(Y)+10]);
                    end
                    if(strcmpi(this.performanceCriterion,'silhouette'))
                        fmtStr = '%0.4f';
                    else
                        fmtStr = '%0.2f';
                    end
                        
                    if(this.getUserCancelled())
                        statusStr = sprintf(['User cancelled with final cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex); 
                    else
                        statusStr = sprintf(['Converged with a cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
                    end
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end);statusStr]);
                    end
                end
                
                performanceProgression.X = X;
                performanceProgression.Y = Y;
                performanceProgression.statusStr = statusStr;
                performanceProgression.criterion = sprintf('%s Index',sentencecase(this.performanceCriterion));
                
            end
        end
        
        % ======================================================================
        %> @brief Performs adaptive k-means clustering of input data.
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c clusterThreshold [1.5]
        %> - @c method  'kmeans'
        %> - @c useDefaultRandomizer (boolean) Set randomizer seed to default
        %> -- @c true Use 'default' for randomizer (rng)
        %> -- @c false (default) Do not update randomizer seed (rng).
        %> @param performanceAxesH GUI handle to display Calinzki index at each iteration (optional)
        %> @note When included, display calinski index at each adaptive k-mediods iteration which is slower.
        %> @param textStatusH GUI text handle to display updates at each iteration (optional)
        %> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
        %> @retval centroids - KxC matrix of cluster centroids.
        %> @retval The Calinski index for the returned idx and centroids
        %> @retrval Struct of X and Y fields containing the progression of
        %> cluster sizes and corresponding Calinski indices obtained for
        %> each iteration of k means.
        % ======================================================================
        function [idx, centroids, performanceIndex, performanceProgression, sumD] = adaptiveKmeans(this,loadShapes,settings,performanceAxesH,textStatusH)
            performanceIndex = [];
            X = [];
            Y = [];
            idx = [];
            sumD = [];
            
            % argument checking and validation ....
            if(nargin<5)
                textStatusH = -1;
                if(nargin<4)
                    performanceAxesH = -1;
                    if(nargin<3)
                        settings = this.getDefaultParameters();
                        settings.maxClusters = size(loadShapes,1)/2;
                        settings.clusterMethod = 'kmeans';                        
                    end
                end
            end
            
            if(settings.useDefaultRandomizer)
                rng('default');  % To get same results from run to run...
            end
            
            if(ishandle(textStatusH) && ~(strcmpi(get(textStatusH,'type'),'uicontrol') && strcmpi(get(textStatusH,'style'),'text')))
                fprintf(1,'Input graphic handle is of type %s, but ''text'' type is required.  Status measure will be output to the console window.',get(textStatusH,'type'));
                textStatusH = -1;
            end
            
            
            if(ishandle(performanceAxesH) && ~strcmpi(get(performanceAxesH,'type'),'axes'))
                fprintf(1,'Input graphic handle is of type %s, but ''axes'' type is required.  Performance measures will not be shown.',get(performanceAxesH,'type'));
                performanceAxesH = -1;
            end
            
            
            
            % Make sure we have an axes handle.
            if(ishandle(performanceAxesH))
                %performanceAxesH = axes('parent',calinskiFig,'box','on');
                %calinskiLine = line('xdata',nan,'ydata',nan,'parent',performanceAxesH,'linestyle','none','marker','o');
                xlabel(performanceAxesH,'K');
                ylabel(performanceAxesH,sprintf('%s Index',this.performanceCriterion));
            end
            
            K = settings.minClusters;
            
            N = size(loadShapes,1);
            firstLoop = true;
            if(settings.maxClusters==0 || N == 0)
                performanceProgression.X = X;
                performanceProgression.Y = Y;
                performanceProgression.statusStr = 'Did not converge: empty data set received for clustering';
                centroids = [];
                
            else
                
                % prime loop condition since we don't have a do while ...
                numNotCloseEnough = settings.minClusters;
                
                while(numNotCloseEnough>0 && K<=settings.maxClusters && ~this.getUserCancelled())
                    if(~firstLoop)
                        if(numNotCloseEnough==1)
                            statusStr = sprintf('1 cluster was not close enough.  Setting desired number of clusters to %u.',K);
                        else
                            statusStr = sprintf('%u clusters were not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);
                        end
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end-1:end);statusStr]);
                        end
                        
                    else
                        statusStr = sprintf('Initializing desired number of clusters to %u.',K);
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        
                    end
                    
                    tic
                    %     IDX = kmeans(X,K) returns an N-by-1 vector IDX containing the cluster
                    %     indices of each point -> the loadshapeMap
                    %
                    %     [IDX, C] = kmeans(X, K) returns the K cluster centroid locations in
                    %     the K-by-P matrix C.
                    %
                    %     [IDX, C, SUMD] = kmeans(X, K) returns the within-cluster sums of
                    %     point-to-centroid distances in the 1-by-K vector sumD.
                    %
                    %     [IDX, C, SUMD, D] = kmeans(X, K) returns distances from each point
                    %     to every centroid in the N-by-K matrix D.
                    
                    
                    if(firstLoop)
                        % prime the kmeans algorithms starting centroids
                        % Can be a problem when we are going to start with repeat
                        % clusters.
                        if(settings.initClusterWithPermutation)
                            centroids = loadShapes(pa_randperm(N,K),:);
                            [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','distance',this.distanceMetric);
                        else
                            [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K);
                        end
                        firstLoop = false;
                                            
                    else
                        [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','distance',this.distanceMetric);
                    end
                    if(ishandle(performanceAxesH))
                        if(strcmpi(this.performanceCriterion,'silhouette'))
                            performanceIndex  = mean(silhouette(loadShapes,idx));

                        else
                            performanceIndex  = this.getCalinskiHarabaszIndex(idx,centroids,sumD);                            
                        end
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        PACluster.plot(performanceAxesH,X,Y);
                        
                        statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                        
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end-1:end);statusStr]);
                        end
                        
                        drawnow();
                        %plot(calinskiAxes,'xdata',X,'ydata',Y);
                        %set(calinskiLine,'xdata',X,'ydata',Y);
                        %set(calinkiAxes,'xlim',[min(X)-5,
                        %max(X)]+5,[min(Y)-10,max(Y)+10]);
                    end
                    
                    
                    removed = sum(isnan(centroids),2)>0;
                    numRemoved = sum(removed);
                    if(numRemoved>0)
                        statusStr = sprintf('%u clusters were dropped during this iteration.',numRemoved);
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        
                        centroids(removed,:)=[];
                        K = K-numRemoved;
                        [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off','distance',this.distanceMetric);
                        
                        if(ishandle(performanceAxesH))
                            if(strcmpi(this.performanceCriterion,'silhouette'))
                                performanceIndex  = mean(silhouette(loadShapes,idx));
                                
                            else
                                performanceIndex  = this.getCalinskiHarabaszIndex(idx,centroids,sumD);
                            end
                            X(end+1)= K;
                            Y(end+1)=performanceIndex;
                            PACluster.plot(performanceAxesH,X,Y);
                            
                            statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                            
                            fprintf(1,'%s\n',statusStr);
                            if(ishandle(textStatusH))
                                curString = get(textStatusH,'string');
                                set(textStatusH,'string',[curString(end);statusStr]);
                            end
                            
                            drawnow();
                            
                            %set(calinskiLine,'xdata',X,'ydata',Y);
                            %set(calinkiAxes,'xlim',[min(X)-5,
                            %max(X)]+5,[min(Y)-10,max(Y)+10]);
                        end
                    end
                    
                    toc
                    
                    point2centroidDistanceIndices = sub2ind(size(pointToClusterDistances),(1:N)',idx);
                    distanceToClusters = pointToClusterDistances(point2centroidDistanceIndices);
                    sqEuclideanClusters = (sum(centroids.^2,2));
                    
                    clusterThresholds = settings.clusterThreshold*sqEuclideanClusters;
                    notCloseEnoughPoints = distanceToClusters>clusterThresholds(idx);
                    notCloseEnoughClusters = unique(idx(notCloseEnoughPoints));
                    
                    numNotCloseEnough = numel(notCloseEnoughClusters);
                    if(numNotCloseEnough>0)
                        centroids(notCloseEnoughClusters,:)=[];
                        for k=1:numNotCloseEnough
                            curClusterIndex = notCloseEnoughClusters(k);
                            clusteredLoadShapes = loadShapes(idx==curClusterIndex,:);
                            numClusteredLoadShapes = size(clusteredLoadShapes,1);
                            if(numClusteredLoadShapes>1)
                                try
                                    [~,splitClusters] = kmeans(clusteredLoadShapes,2,'EmptyAction','drop','distance',this.distanceMetric);
                                    
                                catch me
                                    showME(me);
                                end
                                centroids = [centroids;splitClusters];
                            else
                                if(numClusteredLoadShapes~=1)
                                    echo(numClusteredLoadShapes); %houston, we have a problem.
                                end
                                numNotCloseEnough = numNotCloseEnough-1;
                                centroids = [centroids;clusteredLoadShapes];
                            end
                            % for speed
                            %[~,centroids(curRow:curRow+1,:)] = kmeans(clusteredLoadShapes,2,'distance',this.distanceMetric);
                            %curRow = curRow+2;
                        end
                        
                        % reset cluster centers now / batch update
                        K = K+numNotCloseEnough;
                        [~, centroids] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off','distance',this.distanceMetric);
                    end
                end
                
                
                if(numNotCloseEnough~=0 && ~this.getUserCancelled())
                    statusStr = sprintf('Failed to converge using a maximum limit of %u clusters.',settings.maxClusters);
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end);statusStr]);
                        drawnow();
                    end
                    
                    % No partial credit
                    [performanceIndex, X, Y, idx, centroids] = deal([]);
                    
                else
                    
                    if(this.getUserCancelled())
                        statusStr = sprintf('User cancelled - completing final clustering operation ...');
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end                        
                        [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off','distance',this.distanceMetric);
                    end
                    if(ishandle(performanceAxesH))
                        % getPerformance
                        if(strcmpi(this.performanceCriterion,'silhouette'))
                            performanceIndex  = mean(silhouette(loadShapes,idx));
                        else
                            performanceIndex  = this.getCalinskiHarabaszIndex(idx,centroids,sumD);                            
                        end
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        PACluster.plot(performanceAxesH,X,Y);
                        
                        statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                        
                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end
                        
                        drawnow();
                        
                        %set(calinskiLine,'xdata',X,'ydata',Y);
                        %set(calinkiAxes,'xlim',[min(X)-5,
                        %max(X)]+5,[min(Y)-10,max(Y)+10]);
                        
                    end
                    
                    if(strcmpi(this.performanceCriterion,'silhouette'))
                        fmtStr = '%0.4f';
                    else
                        fmtStr = '%0.2f';
                    end
                    if(this.getUserCancelled())
                        statusStr = sprintf(['User cancelled with final cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
                    else
                        statusStr = sprintf(['Converged with a cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
                    end
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end);statusStr]);
                    end
                end
                
                
                performanceProgression.X = X;
                performanceProgression.Y = Y;
                performanceProgression.statusStr = statusStr;
                performanceProgression.criterion = sprintf('%s Index',sentencecase(this.performanceCriterion));
                
                
            end
        end
        
   
    end
    
    methods(Static, Access=private)
        % ======================================================================
        %> @brief Calculates the distribution of load shapes according to
        %> centroid, in ascending order.
        % @param Instance of PACluster
        %> @param loadShapeMap Nx1 vector of centroid indices.  Each
        %> element's position represents the loadShape.  
        %> @note This is the @c @b idx parameter returned from kmeans
        % @param number of centroids (i.e number of bins/edges to use when
        % calculating the distribution)
        %> @retval sortedCounts Cx1 vector where sourtedCounts(c) represents the number of
        %> of loadshapes found at centroid 'c'.  
        %> @retval sortedIndices Cx1 vector.  sortedIndices(c) is the
        %> centroid index with loadshape count of sortedCounts(c) at index c.
        %> It can be used to map the popularity of the original order of the loadShapeMap to the index of its position in sorted order.
        %> @note originalIndices = 1:C.  sortedIndices == originalIndices(sortedIndices)        
        % ======================================================================
        function [sortedCounts, sortedIndices] = calculateAndSortDistribution(loadShapeMap)
            clusterCounts = histc(loadShapeMap,1:max(loadShapeMap));
            
            % Consider four centroids with following counts
            % Index, Count
            % 1, 404
            % 2, 233
            % 3, 50
            % 4, 354
            
            [sortedCounts,sortedIndices] = sort(clusterCounts,'descend');
            % Index, Sorted Count, Sorted indices
            % 1, 404, 1
            % 2, 354, 4
            % 3, 233, 3
            % 4, 50,  2
            %
            
            % To make index 1 be the most popular, we sort in descending
            % order (high to low)
            
            % sortedIndexToClusterIndex = sortedIndices;
            %   index of most popular centroid is
            %               sortedIndexToClusterIndex(end)
            % index of least popular centroid is
            %               sortedIndexToClusterIndex(1)
            % sortedCounts == clusterCounts(sortedIndices)
            %             this.histogram = sortedCounts;
            %             this.centroidSortMap = sortedIndices;
        end
    end
    
    methods(Static)
        
        %> @brief Retrieve a struct of default settings for the PACluster
        %> class.
        %> @retval Struct with field value pairs as follows:
        %> - @c minClusters = 10
        %> - @c clusterThreshold = 0.2 
        %> - @c clusterMethod = 'kmeans'   {'kmeans','kmedoids'}
        %> - @c useDefaultRandomizer = false;
        %> - @c initClusterWithPermutation = false;            
        %> @note Higher thresholds result in fewer clusters (and vice versa).
        function settings = getDefaultParameters()
            settings = PAData.getDefaultParameters();
            settings.minClusters = 10;
            settings.clusterThreshold = 1.0;    %higher threshold equates to fewer clusters.
            
            settings.clusterMethod = 'kmeans';
            settings.useDefaultRandomizer = false;
            settings.initClusterWithPermutation = false;
            
        end
        
        function methods = getClusterMethods()
            methods = {'kmeans','kmedoids'};
        end
    
        function h=plot(performanceAxesH,X,Y)
            plotOptions = PACluster.getPlotOptions();
            h=plot(performanceAxesH,X,Y,plotOptions{:});
            xlabel(performanceAxesH,'K');
            ylabel(performanceAxesH,'Performance Index');
        end       
        
        function plotOptions = getPlotOptions()
            plotOptions = {'linestyle',':','linewidth',1,'marker','*','markerfacecolor','k','markeredgecolor','k','markersize',8};
        end
    end
    
end

