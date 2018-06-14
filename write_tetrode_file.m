function [success] = write_tetrode_file(filename, header, timestamps, waveforms, overwrite)
% READ_TETRODE_FILE writes a AXONA tetrode data file from MATLAB.
%
%
% Input:
%     filename    ... String. Filename, typically ending in ".1", up to
%                     ".32" (see below and DACQ file format documentation)
%
%     header      ... struct. Structure containing key-value pairs from the
%                     header section of the tetrode file. timestamps  ...
%                     double [nSpikes x 1] Array. Timestamps in seconds of
%                     when the spikes happened.
%
%     waveforms   ... int8 [nSpike x 50 x 4] Array. These are the waveforms
%                     of each spikes.
%
%     overwrite   ... Boolean. True if you want to overwrite any existing
%                     file. If false, will abort writing with an error
%                     message. default: true
%
% Output:
%       success     ... Boolean. True if writing was successful, otherwise
%                       false.
%
% see also: READ_TETRODE_FILE


%% set defaults
if nargin == 4
    overwrite = TRUE;
end

%% open file
if ~overwrite, assert(~ exist(filename, 'file'), 'Error: output file already exists'), end
f = fopen(filename, 'w');


%% convert Header-struct to string for writing
data(1,:) = fieldnames(header);
data(2,:) = struct2cell(header);
data(2,:) = cellfun(@string, data(2,:),'UniformOutput',0);
headerString = sprintf('%s %s\n',data{:});


%% get a few infos from header for writing data below
timebase = header.timebase;
num_spikes = header.num_spikes;


%% convert timestamps and waveforms into expected AXONA format
% i.e.: (taken from read_tetrode_file.m)
%Note structure of data is such that for every spikes on each channel a 4
%byte timestamp is logged followed by the 50 waveform points each being 1
%byte. So 54bytes per channel, 216 per spikes. Key point is that timestamps
%are always the same for each channel, so fully redundant (i.e. just read
%first ch). The timestamp is in bigendian ordering so if this computer
%lives in a little endian world we will need to swap bytes to get
%meaningful values. Waveform points are just int8s so aren't affect by byte
%ordering. Data also seems to be padded beyond the end of num_spikes.

% first, convert timestamps into 4-bytes
if size(timestamps, 2) == 4 % if we get 4 times the timestamps, then assume they are identical and use only first column
    timestamps = timestamps(:,1); 
end
timestamps = timestamps.*timebase;  % convert to sample nr 
timestamps = int32(timestamps);
% check whether we need to swap bytes into big-endian
[~,~,endian] = computer;
if endian == 'L'
    timestamps = swapbytes(timestamps);
end
timestamps = typecast(timestamps,'int8'); 
timestamps = reshape(timestamps, 4, []);
% now, each timestamp takes 4 rows of int8, with as many columns as there
% were spikes

% create 'data' array first: first four 
data = NaN(216,num_spikes); % preallocate data-array
for iSpike = 1:num_spikes
   data(:,iSpike) = [...
       timestamps(:,iSpike)' waveforms(iSpike,:,1) ...
       timestamps(:,iSpike)' waveforms(iSpike,:,2) ...
       timestamps(:,iSpike)' waveforms(iSpike,:,3) ...
       timestamps(:,iSpike)' waveforms(iSpike,:,4) ...
       ];
end
data = data(:);


%% write data to file
fwrite(f,headerString);
fwrite(f,'\r\ndata_start','uint8');
fwrite(f,data,'*int8');
fwrite(f,'\r\ndata_end','uint8');

end
