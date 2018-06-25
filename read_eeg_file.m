function [header,eeg_data] = read_eeg_file(filename)
% READ_EEG_FILE reads a AXONA EEG data file into MATLAB.
%
% Input:
%     filename    ... String. Filename, typically ending in ".eeg" (see
%                     below and DACQ file format documentation)
%
% Output:
%     header      ... Struct. Structure containing key-value pairs from the
%                     header section of the tetrode file.
%
%     eeg_data    ... Double [nSamples x % 1] Array. Timestamps in
%                     seconds of when the spikes happened.
%
%
% From the DACQ file format documentation:
%
% EEG data is usually recorded continuously at 250 Hz in unit recording
% mode. The “.eeg” and “.eg2” files contain the data from the primary and
% secondary EEG channels, if these have been enabled. Very simply, the data
% consist of “num_EEG_samples” data bytes, following on from the
% data_start. The sample count is specified in the header. The “.egf” file
% is stored if a user selects a higher-sample rate EEG. Samples are
% normally collected at 4800 Hz (specified in the header), and are also
% normally 2 bytes long, rather than just 1.
%
% see also: READ_TETRODE_FILE, READ_INPUT_FILE

DATA_START_TOKEN = sprintf('\r\ndata_start');
DATA_END_TOKEN = sprintf('\r\ndata_end');

f = fopen(filename,'r');
if f == -1
    warning('Cannot open file %s!', filename);
    header = struct(); eeg_data = [];
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
tic
rawBinaryData = fread(f, endData-startData-length(DATA_START_TOKEN), '*uint8'); % read data in as bytes
toc

% convert header
%--------------------------------------------------------------------------
cell_array = textscan(headerString,'%s %[^\n\r]'); % split into keys and values
cell_array{2} = cellfun(@convertToNumber, cell_array{2},'UniformOutput',false); % % convert all numeric ones into numbers, keep string otherwise
header = cell2struct(cell_array{2},cell_array{1});
% manually post-process timebase and sample_rate: they include 'hz' so the
% above didn't convert them into numbers
% header.timebase = convertToNumber(header.timebase(1:(end-3))); % remove ' hz' from the end
header.sample_rate = str2num(header.sample_rate(1:(end-3))); % remove ' hz' from the end

% convert eeg data into double
%--------------------------------------------------------------------------
% this section is based on the `Unit Mode` description of the input

% there are 216 per spike (54 per channel), so sort the data into one
% column per spike
data = reshape(rawBinaryData,header.bytes_per_sample,[]);

switch header.bytes_per_sample
    case 1
        intType = 'int8';
    case 2
        intType = 'int16';
    otherwise
        error('unhandled bytes-per-sample');
end

% convert timestamp bytes to same endian-ness as this computer

[~,~,endian] = computer;  % 'L' or 'B'
if endian == 'L'
    data = swapbytes(data);
end
data = typecast(data(:),intType);

% and convert them into seconds
eeg_data = double(data);



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