function [header,timestamps, waveforms] = read_tetrode_file(filename)
% READ_TETRODE_FILE reads a AXONA tetrode data file into MATLAB.
%
% Input:
%     filename    ... String. Filename, typically ending in ".1", up to ".32"
%                            (see below and DACQ file format documentation)
%
% Output:
%     header      ... struct. Structure containing key-value pairs from the header section of the tetrode file.
%     timestamps  ... double [nSpikes x 1] Array. Timestamps in seconds of when the spikes happened.
%     waveforms   ... int8 [nSpike x 50 x 4] Array. These are the waveforms of each spikes.
%
% From the DACQ file format documentation:
%
% Tetrode files have a header section and a data-section. The data is
% wrapped by `data_start` and `data_end`. The header is a
% simple list of 'key value' pairs (one per row). In Unit mode (assumed in
% this script), data is stored in 1ms chunks [-200us prior to 800us post
% event]. There are 54bytes per spike (4 bytes timestamp, then 50 8-bit
% samples). The header's timebase (usually 96kHz) is the value by which the
% timestamps need to be divided to get the timestamp in seconds.
%
% see also: WRITE_TETRODE_FILE

DATA_START_TOKEN = sprintf('\r\ndata_start');
DATA_END_TOKEN = sprintf('\r\ndata_end');

f = fopen(filename,'r');
if f == -1
    warning('Cannot open file %s!', filename);
    header = []; timestamps = []; waveforms = [];
    return;
end

% first, identify where header and data sections are
%--------------------------------------------------------------------------
fullFile = fread(f, Inf, 'uint8=>char')'; % read binary file as if it was a text-file
startData = strfind(fullFile, DATA_START_TOKEN);
endData = strfind(fullFile, DATA_END_TOKEN);
frewind(f); % go back to start of file

% read in header and data
%--------------------------------------------------------------------------
headerString = fread(f, startData-1, 'uint8=>char')';
% to read in data, we need to advance by the length of the DATA_START_TOKEN
fseek(f, startData + length(DATA_START_TOKEN) -1,'bof'); % relative to start of file
rawBinaryData = fread(f, endData-startData-length(DATA_START_TOKEN), '*int8'); % read data in as bytes

% convert header
%--------------------------------------------------------------------------
cell_array = textscan(headerString,'%s %[^\n\r]'); % split into keys and values
cell_array{2} = cellfun(@convertToNumber, cell_array{2},'UniformOutput',false); % % convert all numeric ones into numbers, keep string otherwise
header = cell2struct(cell_array{2},cell_array{1});
% manually post-process timebase and sample_rate: they include 'hz' so the
% above didn't convert them into numbers
header.timebase = convertToNumber(header.timebase(1:(end-3))); % remove ' hz' from the end
header.sample_rate = convertToNumber(header.sample_rate(1:(end-3))); % remove ' hz' from the end

% convert extract timestamps and waveforms from binary data
%--------------------------------------------------------------------------
% this section is based on the `Unit Mode` description of the input

% there are 216 per spike (54 per channel), so sort the data into one
% column per spike
data = reshape(rawBinaryData,216,[]);

% Given that timestamps are identical for all four channels, pick simply
% the first channel
timestamps = data(1:4,:); % the four bytes of a
%convert timestamp bytes to int32 with same endian-ness as this computer
timestamps = typecast(timestamps(:),'int32');
[~,~,endian] = computer;  % 'L' or 'B'
if endian == 'L'
    timestamps = swapbytes(timestamps);
end
% and convert them into seconds
timestamps = double(timestamps)/header.timebase;

% waveforms
% the remaining 50 bytes per channel are the waveforms
waveforms = data([5:54, 59:108, 113:162, 167:216],:)';
waveforms = reshape(waveforms,[],50,4); % int8 [nSpike x 50 x 4]


end

function output = convertToNumber(inputString)
% converts `inputString` into a number if it possible, otherwise returns
% the original string

% try to convert
[converted, succeeded] = str2num(inputString);
if succeeded
    output = converted;
else
    output = inputString;
end

end