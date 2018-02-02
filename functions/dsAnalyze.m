function result = dsAnalyze(src,varargin)
%DSANALYZE - Apply an analysis function to DynaSim data, optionally saving data
%
% Pass a single DynaSim data structure or an array of data structures to a
% user-specified analysis function, add varied info to the results and
% optionally save the output structure.
%
% Usage:
%  1) dsAnalyze Style: explicit func handle/cell of handles
%   result = AnalyzeData(data,func,'option1',value1,...) % pass data or datafile name
%   result = AnalyzeData(studyinfo,func,'option1',value1,...) % pass studyinfo struct
%   result = AnalyzeData(study_dir,func,'option1',value1,...) % pass study_dir containing studyinfo.mat
%  2) dsSimluate Style: implicit func through options.analysis_functions/options.plot_functions
%   result = AnalyzeData(data,'option1',value1,...) % pass data or datafile name
%   result = AnalyzeData(studyinfo,'option1',value1,...) % pass studyinfo struct
%   result = AnalyzeData(study_dir,'option1',value1,...) % pass study_dir containing studyinfo.mat
%
% Inputs:
%   - First input/argument:
%     - data: DynaSim data structure or data file path (s)
%     - studyinfo: DynaSim studyinfo structure or path to studyinfo
%     - study_dir: DynaSim study directory containing studyinfo.mat
%   - func: function handle or cell array of function handles pointing to plot
%           or analysis function(s). Should not contain case-insensitive string
%           'plot' unless is a function that returns a figure handle for plotting.
%   - options: (key/value pairs are passed on to the analysis function)
%     'save_results_flag'   : whether to save result {0 or 1} (default: 0)
%     'matCompatibility_flag': whether to save mat files in compatible mode, vs to prioritize > 2GB VARs {0 or 1} (default: 1)
%     'overwrite_flag': whether to overwrite existing result files {0 or 1} (default: 0)
%     'result_file'         : where to save result (default: 'result.mat')
%     'format'              : format for saved plots if figures are generated
%                             {'svg','jpg','eps','png'} (default: 'svg')
%     'varied_filename_flag': whether to make filename based on the varied
%                             parameters and type of plot {0 or 1}. will overwrite
%                             if multiple plots of same type (use 'save_prefix' to
%                             avoid overwrite in that case) (default: 0)
%     'save_prefix'         : if 'varied_filename_flag'==1, add a string prefix 
%                             to the name (default: '')
%    2 ways to specify:
%     1)
%     'function_options'    : cell array of option cell arrays {'option1',value1,...}
%                             in which each cell corresponds to the options for
%                             the corresponding function cell. if only passing a
%                             single func, can specificy function options as
%                             key,val list as varargin for AnalyzeData
%     2)
%     'analysis_functions': cell array of analysis function handles
%     'analysis_options'  : cell array of option cell arrays {'option1',value1,...}
%     'plot_functions'    : cell array of plot function handles
%     'plot_options'      : cell array of option cell arrays {'option1',value1,...}
%
%     'load_all_data_flag'  : whether to load all the data in studyinfo
%                             at once {0 or 1} (default: 0)
%     'verbose_flag'  : whether to display informative messages/logs (default: 0)
%     'parfor_flag' : whether to use parfor to run analysis {0 or 1} (default: 0)
%
% Outputs:
%   - result: structure returned by the analysis function
%
% TODO: annotate figures with data set-specific modifications
%
%
% See also: dsSimulate
%
% Author: Jason Sherfey, PhD <jssherfey@gmail.com>
% Copyright (C) 2016 Jason Sherfey, Boston University, USA

%% General cases:
%   - data struct (likely from SimualteModel call)
%   - data struct array
%   - studyinfo with load_all_data_flag==0
%   - studyinfo with load_all_data_flag==1

%% localfn output
if ~nargin
  output = localfunctions; % output var name specific to this fn
  return
end

%% check input type
if (nargin > 1) && (iscell(varargin{1}) || isfunction(varargin{1}))
  funcIn = varargin{1};
  varargin(1) = [];
else
  funcIn = [];
end

%% Check inputs
options=dsCheckOptions(varargin,{...
  'result_file','result',[],...
  'save_results_flag',0,{0,1},...
  'matCompatibility_flag',1,{0,1},...  % whether to save mat files in compatible mode, vs to prioritize > 2GB VARs
  'overwrite_flag',0,{0,1},... % whether to overwrite existing data
  'format','svg',{'svg','jpg','eps','png','fig'},...
  'varied_filename_flag',0,{0,1},...
  'plot_type','waveform',{'waveform','rastergram','raster','power','rates','imagesc','heatmapFR','heatmap_sortedFR','meanFR','meanFRdens','FRpanel'},...
  'save_prefix',[],[],...
  'function_options',{},[],...
  'simIDs',[],[],...
  'load_all_data_flag',0,{0,1},...
  'auto_gen_test_data_flag',0,{0,1},...
  'unit_test_flag',0,{0,1},...
  'parfor_flag',0,{0,1},...     % whether to run analysis in parallel (using parfor)
  'verbose_flag',0,{0,1},...
  'analysis_functions',[],[],...
  'analysis_options',[],[],...
  'plot_functions',[],[],...
  'plot_options',[],[],...
  'auto_gen_test_data_flag',0,{0,1},...
  },false);

%% auto_gen_test_data_flag argin
if options.auto_gen_test_data_flag
  varargs = varargin;
  varargs{find(strcmp(varargs, 'auto_gen_test_data_flag'))+1} = 0;
  varargs(end+1:end+2) = {'unit_test_flag',1};
  argin = [{src},{funcIn}, varargs]; % specific to this function
end


%% Save data if no output is requested.
if nargout < 1
  options.save_results_flag = 1;
  dsVprintf(options, 'Setting save_results_flag=1 since no nargout.\n')
end

if options.parfor_flag && ~strcmp(reportUI,'matlab')
  disp('For GNU Octave users: Do not expect any speed up by using DynaSim''s ''parfor_flag''. In GNU Octave, parfor loops currently default to regular for loops.');
end

%% Parse src
[data, studyinfo] = parseSrc(src, options, varargin{:});
% Data at this point:
%   - 'data' as single struct or struct array, or empty
%   - 'studyinfo' struct or empty

% check if study_dir defined
if isempty(studyinfo)
  studyinfoBool = false;
else
  studyinfoBool = true;
  if ~isfield(studyinfo,'study_dir') || isempty(studyinfo.study_dir) || ~isdir(studyinfo.study_dir)
    studyinfo.study_dir = pwd;
  end
end

% Data at this point:
%   - 'data' as single struct or struct array, or empty
%   - 'studyinfo' struct with many flds or just 'study_dir' field

% convert data to double precision before analysis
dsVprintf(options, 'Converting data to double precision before analysis.\n')
for j = 1:length(data)
  for k = 1:length(data(j).labels)
    fld = data(j).labels{k};
    data(j).(fld) = double(data(j).(fld));
  end
end

% make fn fields into cells
if ~isempty(options.plot_functions) || ~iscell(options.plot_functions)
  options.plot_functions = {options.plot_functions};
end
if ~isempty(options.analysis_functions) || ~iscell(options.analysis_functions)
  options.analysis_functions = {options.analysis_functions};
end

% make funcIn for dsSimulate Style
if isempty(funcIn) && ( ~isempty(options.plot_functions) || ~isempty(options.analysis_functions) )
  funcIn = [options.plot_functions(:); options.analysis_functions(:)];
  plotFnBoolVec = false(size(funcIn));
  plotFnBoolVec(1:length(options.analysis_functions)) = true; % specify which fn were plot fn
else
  plotFnBoolVec = [];
end

% convert func string to handle, or check length of cell array
[funcIn, nFunc] = parseFuncIn(funcIn);

% check if postSim
postSimBool = studyinfoBool || (length(data) > 1); % since length(data)==1 and no studyinfo with dsSimulate call. EAR: not sure about that.

for fInd = 1:nFunc % loop over function inputs
  func = funcIn{fInd};

  % confirm func is function handle or convert to one if possible
  func = parseFunc(func);

  % check if plot in fn name
  if ~isempty(plotFnBoolVec)
    plotFnBool = plotFnBoolVec(fInd);
  else
    plotFnBool = ~isempty(regexpi(func2str(func), 'plot'));
  end

  % change result_file if varied_filename_flag
  if options.varied_filename_flag && isfield(data, 'varied')
    options.result_file = filenameFromVaried(options.result_file, func, data, plotFnBool, options, varargin{:});
  end

  % do analysis
  dsVprintf(options, '  Executing post-processing function: %s\n',func2str(func));
  tstart = tic;

  %% Eval func
  if length(data)==1 || postSimBool % Don't need to add check on load_all_data_flag, since if false data is empty.
    result = evalFnWithArgs(fInd, data, func, options, varargin{:});
  else
    result = [];
  end

  % calc nResults
  if ~isempty(result)
    nResults = length(result);
  elseif ~isempty(data)
    nResults = length(data);
  else
    nResults = length(siminfo.simulations);
  end

  dsVprintf(options, '    Elapsed time: %g sec\n',toc(tstart));

  % Dave: Not all plotting functions will return a plot handle. For
  % example, dsPlot2 returns a nested structure of figure, axis, and plot
  % handles. This command updates it.
  if isstruct(result)
    if isfield(result,'hcurr')
      result = result.hcurr;
    end
  end

  % determine if result is a plot handle or derived data
  if all(ishandle(result)) || plotFnBool % analysis function returned a graphics handle or has plot in fn name
    %% Plot Function

    % will save plots else return main fn
    if options.save_results_flag
      % loop through results. all results may exist or need to be made during loop
      for iResult = 1:nResults
        extension = ['.' options.format]; % '.svg'; % {.jpg,.svg}

        if ~postSimBool % approx nResults == 1 && ~studyinfoBool % approx ~postSimBool
          fName = [options.result_file extension];
          fPath = fName;

          thisResult = result(iResult);
        elseif studyinfoBool
          simID = studyinfo.simulations(iResult).sim_id;
          prefix = func2str(func);
          fName = [prefix '_sim' num2str(simID) '_plot' num2str(fInd) '_' func2str(func)];

          if (postSimBool && ~options.load_all_data_flag)
            data = loadDataFromSingleSim(simID, options, varargin);

            %skip if no data
            if isempty(data)
              dsVprintf(options, 'Skipping simID=%i since no data.\n', simID);
              continue
            end

            % calc result for this data
            thisResult = evalFnWithArgs(fInd, data, func, options, varargin);
          else % (postSimBool && options.load_all_data_flag)
            thisResult = result(iResult);
          end

          % change result_file if varied_filename_flag
          if options.varied_filename_flag && isfield(data, 'varied')
            fName = filenameFromVaried(fName, func, data, plotFnBool, options, varargin{:});
          end % varied_filename_flag

          % make fPath
          fDir = fullfile(studyinfo.study_dir, 'postSimPlots');
          if ~exist(fDir,'dir')
            mkdir(fDir)
          end
          fPath = fullfile(fDir,fName);
        else % length(result)>1 and ~studyinfoBool
          fName = [options.result_file '_page' num2str(iResult) extension];

          % make fPath
          fDir = fullfile(studyinfo.study_dir, 'postSimPlots');
          if ~exist(fDir,'dir')
            mkdir(fDir)
          end
          fPath = fullfile(fDir,fName);

          thisResult = result(iResult);
        end
        % Data needed for plotting:
        %   - thisResult
        %   - fPath

        %skip if no data
        if isempty(thisResult)
          dsVprintf(options, 'Skipping simID=%i since no result.\n', simID);
          continue
        end

        set(thisResult, 'PaperPositionMode','auto');
        dsVprintf(options, '    Saving plot: %s\n',fName);

        switch extension
          case '.svg'
            plot2svg(fPath,thisResult);
          case '.jpg'
            print(thisResult,fPath,'-djpeg');
          case '.eps'
            print(thisResult,fPath,'-depsc');
          case '.png'
            print(thisResult,fPath,'-dpng');
          case '.fig'
            savefig(thisResult,fPath);
        end

        if nResults > 1
          close(thisResult)
        end
      end %nResults
    end %save_results_flag
  else % analysis function returned derived data
    %% Analysis Function
    if isstruct(result)
      result = add_modifications(result, data, varargin{:});

      for iResult = 1:length(result)
        % add options to result structure
        if length(varargin)>1
          for j = 1:2:length(varargin)
            result(iResult).options.(varargin{j}) = varargin{j+1};
          end
        else
          result(iResult).options = [];
        end
      end %iResult
    end %isstruct

    % save derived data else return main function
    if options.save_results_flag
      if studyinfoBool
        allResults = result;
        clear result;

        for iResult = 1:nResults
          simID = studyinfo.simulations(iResult).sim_id;

          if options.load_all_data_flag
            result = allResults(iResult);
          else % load data
            data = loadDataFromSingleSim(simID, options, varargin);

            %skip if no data
            if isempty(data)
              continue
            end

            % calc result for this data
            result = evalFnWithArgs(fInd, data, func, options, varargin);
          end

          prefix = func2str(func);
          fName = [prefix '_sim' num2str(simID) '_analysis' num2str(fInd) '_' func2str(func) '.mat'];

          % change result_file if varied_filename_flag
          if options.varied_filename_flag && isfield(data, 'varied')
            fName = filenameFromVaried(fName, func, data, plotFnBool, options, varargin{:});
          end % varied_filename_flag

          % make fPath
          fDir = fullfile(studyinfo.study_dir, 'postSimResults');
          if ~exist(fDir,'dir')
            mkdir(fDir)
          end
          fPath = fullfile(fDir,fName);

          dsExportData(result, 'filename',fPath, 'result_flag',1, varargin{:});
        end %iResult
      else % ~studyinfoBool, whether 1 or array of struct
        fName = options.result_file;
        extension = '.mat';

        if ~strcmp(fName(end-3:end), extension) %check for .mat extension
          fName = [fName extension];
        end
        
        fPath = fName;

        dsExportData(result, 'filename',fPath, 'result_flag',1, varargin{:});
      end % scenarios
    end % save_results_flag
  end % ishandle(result)
end % fInd

%% auto_gen_test_data_flag argout
if options.auto_gen_test_data_flag
  argout = {result}; % specific to this function

  %dsUnitSaveAutoGenTestData(argin, argout); % TODO: check if needs to be saveAutoGenTestDir
end

end %main fn




%% Local functions

function [data, studyinfo] = parseSrc(src, options, varargin)

%% auto_gen_test_data_flag argin
options = catstruct(options, dsCheckOptions(varargin,{'auto_gen_test_data_flag',0,{0,1}},false));
if options.auto_gen_test_data_flag
  varargs = varargin;
  varargs{find(strcmp(varargs, 'auto_gen_test_data_flag'))+1} = 0;
  varargs(end+1:end+2) = {'unit_test_flag',1};
  argin = [{src},{options}, varargs]; % specific to this function
end


if isstruct(src) && isfield(src,'time') % data struct (single or array)
  data = src; % if length==1,then likely from SimulateModel call
  studyinfo = [];
elseif ischar(src) %string input
  if options.load_all_data_flag % load data
    [data,studyinfo] = dsImport(src, varargin{:});
  else % only load studyinfo
    data = [];
    studyinfo = dsCheckStudyinfo(src);
  end

  % update study_dir
  if exist(src, 'file') && ~isempty(strfind(src, 'studyinfo')) %studyinfo.mat
    studyinfo.study_dir = fileparts2(src);
  elseif isdir(src) % study_dir
    studyinfo.study_dir = src;
  end
end

% Old Verbose Way with unnecessary checks
% determine type of src
% if ischar(src)
%   if exist(src,'file') % data file or studyinfo.mat
%     if strfind(src, 'studyinfo') %studyinfo.mat
%       [data,studyinfo] = dsImport(src, varargin{:}); % load data
%       studyinfo.study_dir = fileparts2(src);
%     else % data file
%       [data,studyinfo] = dsImport(src, varargin{:}); % load data
%     end
%   elseif isdir(src) % study_dir
%     [data,studyinfo] = dsImport(src, varargin{:}); % load data
%     studyinfo.study_dir = src;
%   else
%     try
%       [data,studyinfo] = dsImport(src, varargin{:}); % load data
%     catch
%       error('Unknown source for first input/argument.')
%     end
%   end
% elseif isstruct(src) && length(src)>1 % data file cell array
%   data = src;
% elseif isstruct(src) % single data struct or studyinfo struct
%   if isfield(src,'time') % single data file
%     data = src;
%   else % studyinfo struct
%     [data,studyinfo] = dsImport(src, varargin{:}); % load data
%   end
% elseif iscell(src) % cell array of files
%   [data,studyinfo] = dsImport(src, varargin{:}); % load data
% else
%   try
%     [data,studyinfo] = dsImport(src, varargin{:}); % load data
%   catch
%     error('Unknown source for first input/argument.')
%   end
% end
%
%
% % make studyinfo if doesn't exist
% if ~exist('studyinfo','var')
%   studyinfo = [];
% end

%% auto_gen_test_data_flag argout
if options.auto_gen_test_data_flag
  argout = {data, studyinfo}; % specific to this function

  %dsUnitSaveAutoGenTestDataLocalFn(argin, argout); % localfn
end

end


function [funcIn, nFunc] = parseFuncIn(funcIn)
% convert funcIn input to handle if not a cell array

if isa(funcIn,'function_handle')
  nFunc = 1;
  funcIn = {funcIn}; % make into cell array
elseif ischar(funcIn)
  funcIn = {str2func(funcIn)}; % convert string to fn handle

  if ~isfunction(funcIn)
    error('Post-processing function must be supplied as a function handle or function name string');
  end

  nFunc = 1;
else
  nFunc = numel(funcIn);
end
end


function func = parseFunc(func)
if ~isa(func,'function_handle')
  if ischar(func)
    func = str2func(func); % convert string to fn handle

    if ~isfunction(func)
      error('Post-processing function must be supplied as a function handle or function name string');
    end
  else
    error('Post-processing function must be supplied as a function handle or function name string');
  end
end
end


function filename = filenameFromVaried(filename, func, data, plotFnBool, options, varargin)
% NOTE: inputs are odd since called from different sources with different
%       states.

%% auto_gen_test_data_flag argin
options = catstruct(options, dsCheckOptions(varargin,{'auto_gen_test_data_flag',0,{0,1}},false));
if options.auto_gen_test_data_flag
  varargs = varargin;
  varargs{find(strcmp(varargs, 'auto_gen_test_data_flag'))+1} = 0;
  varargs(end+1:end+2) = {'unit_test_flag',1};
  argin = [{filename}, {func}, {data}, {plotFnBool}, {options}, varargs]; % specific to this function
end

if isfield(options, 'save_prefix') && ~isempty(options.save_prefix)
  prefix = options.save_prefix;
else
  if plotFnBool
    if isempty(options.function_options)
      plot_options = options;
    else
      plot_options = options.function_options{fInd};
    end

    fInd = regexp(options.result_file, 'plot(\d+)', 'tokens');
    fInd = fInd{1}{1};

    % check if 'plot_type' given as part of plot_options
    plot_options = dsCheckOptions(plot_options,{'plot_type',['plot' fInd],[]},false);

    prefix = plot_options.plot_type; % will be waveform by default due to CheckOptions in main fn
  else % ~plotFnBool
    prefix = func2str(func);
  end
end

filename = dsNameFromVaried(data, prefix, filename);

%% auto_gen_test_data_flag argout
if options.auto_gen_test_data_flag
  argout = {filename}; % specific to this function

  %dsUnitSaveAutoGenTestDataLocalFn(argin, argout); % localfn
end

end


function result = evalFnWithArgs(fInd, data, func, options, varargin)

if strcmp(reportUI,'matlab')
  p = gcp('nocreate');
end

try
  if isempty(options.function_options)
    % Only do parfor mode if parfor_flag is set and parpool is already running. Otherwise, this will add unncessary overhead.
    if options.parfor_flag && ~isempty(p)
      
      parfor dInd = 1:length(data)
        result(dInd) = feval(func,data(dInd),varargin{:});
      end
    else
      for dInd = 1:length(data)
        result(dInd) = feval(func,data(dInd),varargin{:});
      end
    end % options.parfor_flag && ~isempty(p)
  else
    function_options = options.function_options{fInd};

    if options.parfor_flag && ~isempty(p)
      parfor dInd = 1:length(data)
        result(dInd) = feval(func,data(dInd),function_options{:});
      end
    else
      for dInd = 1:length(data)
        result(dInd) = feval(func,data(dInd),function_options{:});
      end
    end % options.parfor_flag && ~isempty(p)
  end % isempty(options.function_options)
catch err
  warning(err.message);
  result = [];
end

end


function data = loadDataFromSingleSim(simID, options, varargin)
% check if iResult in options.simIDs
if isempty(options.simIDs)
  simIDs = simID;
else
  simIDs = intersect(simID, options.simIDs);

  if isempty(simIDs) % skip if empty
    return
  end
end

varinputs = varargin; % create copy of varargin
if isstruct(varinputs{1})
  varinputs.simIDs = simIDs;
else
  % find simIDs in varinputs
  varinputs{find(~cellfun(@isempty,strfind(varinputs(1:2:end), 'simIDs')))*2} = simIDs;
end

data = dsImport(src, varinputs{:}); % load data
end


function result = add_modifications(result, data, varargin)
% add modifications to result structure, excluding modifications made
% within experiments. note: while this nested function is similar to
% dsModifications2Vary called by dsSimulate, the data structure contains
% all modifications (those within and across experiments; listed in 'varied').
% the result structure collapses data sets from an experiment into a single
% result; thus, each result corresponds to modifications across
% experiments but not within them; those modifications are stored in
% the simulator options.

%% auto_gen_test_data_flag argin
options = dsCheckOptions(varargin,{'auto_gen_test_data_flag',0,{0,1}},false);
if options.auto_gen_test_data_flag
  varargs = varargin;
  varargs{find(strcmp(varargs, 'auto_gen_test_data_flag'))+1} = 0;
  varargs(end+1:end+2) = {'unit_test_flag',1};
  argin = [{result}, {data}, varargs]; % specific to this function
end

% #todo: The function dsModifications2Vary implements this functionality.
% Consider using it here.
if ~isempty(data(1).simulator_options.modifications)
  varied = {};
  mods = data(1).simulator_options.modifications;
  for ii = 1:length(result)
    for jj = 1:size(mods,1)
      % prepare valid field name for thing varied:
      fld = [mods{jj,1} '_' mods{jj,2}];

      % convert arrows and periods to underscores
      fld = regexprep(fld,'(->)|(<-)|(-)|(\.)','_');

      % remove brackets and parentheses
      fld = regexprep(fld,'[\[\]\(\)\{\}]','');
      result(ii).(fld) = mods{jj,3};
      varied{end+1} = fld;
    end
    result(ii).varied = varied;
    result(ii).modifications = mods;
  end
elseif isfield(data,'varied') && length(data) == 1
  % add 'varied' info from data to result structure
  for ii = 1:length(result)
    result(ii).varied = data(1).varied;
    for jj = 1:length(data(1).varied)
      result(ii).(data(1).varied{jj}) = data(1).(data(1).varied{jj});
    end
  end
end

%% auto_gen_test_data_flag argout
if options.auto_gen_test_data_flag
  argout = {result}; % specific to this function

  %dsUnitSaveAutoGenTestDataLocalFn(argin, argout); % localfn
end
end % add_modifications
