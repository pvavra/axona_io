function [header, timestamps, event_types, event_bytes] = read_input_file(filename)
% READ_INPUT_FILE reads a AXONA input data file (".inp") and returns the
% timestamps, the associated waveforms and the file-header for further
% processing in matlab
%
% Input: 
%       filename    ... String. filename of input file ('.inp')
%
% Output: 
%       header      ... Struct. Structure containing the header-information
%                       as key-value pairs.
%
%       timestamps  ... Double [nEvents x 1] array. Contains timestamps in
%                       seconds of when the events happened.
%
%       event_types ... String [nEvents x 1] array, containing either 'I',
%                       'O', or 'K' to represent digital input, digital
%                       output, and keypress events respectively.
%
%       event_byts  ... int [nEvents x 1] array. For 'I' and 'O' event
%                       types, this contains the digital channel an which
%                       the event happened ('on' or 'off'); 'K' is ignored
%                       in this function and simply returns '0'. 
%       
%  
% From the DACQ file format documentation:
% 
% Input files have a header section and a data-section. The header is a
% simple list of 'key value' pairs (one per row). The data is wrapped by
% `data_start` and `data_end`. Each event data is stored in blocks of 7
% bytes, with the first 4 being the timestamps, the 5th byte coding for the
% event type, and the remaining 2 bytes storing info on which channel the
% i/o happened (or keypress, which is ignored in this function).
% 
% see also:
%   READ_TETRODE_FILE


DATA_START_TOKEN = sprintf('\r\ndata_start');
DATA_END_TOKEN = sprintf('\r\ndata_end');
 
f = fopen(filename,'r');
if f == -1
    warning('Cannot open file %s!', filename);
    header = []; timestamps = []; event_types = [];
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
% header.sample_rate = convertToNumber(header.sample_rate(1:(end-3))); % remove ' hz' from the end

% convert extract timestamps and event_bytes from binary data
%--------------------------------------------------------------------------
% this section is based on the `Unit Mode` description of the input

% there are 7 byes for each input sample, the first 4 are the timestamp,
% and the remaing are the event 'description'
data = reshape(rawBinaryData,7,[]);

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

% the remaining 50 bytes per channel are the waveforms
event_types = char(data(5,:)'); % either 'I' for digital input, 'K' for keypress, or 'O' for digital output.
channel_state = data(6:7,:);
event_bytes = typecast(channel_state(:),'int16');

end


function output = convertToNumber(inputString)
% converts `inputString` into a number if it possible, otherwise returns
% the original string

% check whether only white-space or digits present in input string
indices = regexp(inputString ,'[\s\d]'); % return all indices of digits/whitespace
toConvert = isequal((1:length(inputString)),indices);

if toConvert  
    output = str2num(inputString);
else
    output = inputString;
end

end