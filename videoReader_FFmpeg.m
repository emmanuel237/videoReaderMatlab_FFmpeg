classdef videoReader_FFmpeg
    %A class to read (almost) all types of video in Matlab. This class has  been developped as a alternative (and more) to matlab VideoReader object that is sometime buggy under Ubuntu.
    % I also provides all the properties of the input video including the type (I, P, B) of each frame. The class uses FFmpeg to decode and save all the frames of the input video as .bmp files at a specified location  (hard drive) and thus doesn't make usage of the computer's RAM . FFprobe is used to read the properties of the input videos (fps, video bitrate, video resolution, frames type, video rotation parameter).
    % ## class's accessible properties:
    % - file_name: path to the video.
    % -resolution: video's resolution [height, width].
    % -video_bitrate: video bitrate.
    % - frame_rate: frame rate (fps).
    % - rotation_angle: rotation angle.
    % - nber_Iframes: number of I frames.
    % - nber_Pframes: number of P frames.
    % - nber_Bframes:number of B frames.
    % - nber_frames:total number of frames.
    % - frames_type: array giving the type of each frame (I,P,B).
    % - Iframes_indexes: array giving indexes of I frames.
    % - Pframes_indexes: array giving indexes of P frames.
    % - Bframes_indexes: array giving indexes of B frames.
    % - GOPs_structures: array giving the structure of each Group Of Pictures (GOP).
    %
    % ## Class's methods:
    %  -obj(video_path, temp_path): class constructor, recieves the video path and a frames' temporary storage location.
    % All the video's properties are readable after the object's instantiation.
    % -obj.loadToDisk(): decodes the video and saves its frames as .bmp files at the specified location.
    % -[frame] = obj.readFrame(frame_index): reads the frames of specified index.
    % -obj.unloadFromDisk(): frees the space on the hard drive alocated for frames' temporary storage.
    %(C): Emmanuel Kiegaing Kouokam 2019
    %Class's properties
    
    properties (SetAccess=private)
        file_name
    end
    properties (SetAccess=private)
        resolution
    end
    properties (SetAccess=private)
        video_bitrate
    end
    properties (SetAccess=private)
        frame_rate
    end
    properties (SetAccess=private)
        rotation_angle
    end
    properties (SetAccess=private)
        nber_Iframes
    end
    properties (SetAccess=private)
        nber_Pframes
    end
    properties (SetAccess=private)
        nber_Bframes
    end
    properties (SetAccess=private)
        nber_frames
    end
    properties (SetAccess=private)
        frames_type
    end
    properties (SetAccess=private)
        Iframes_indexes
    end
    properties (SetAccess=private)
        Pframes_indexes
    end
    properties (SetAccess=private)
        Bframes_indexes
    end
    properties (SetAccess=private)
        h264_profile
    end
    properties (SetAccess=private)
        GOPs_structure
    end
    
    properties (SetAccess=private)
        frame_storage_location %location for frames temporary storage
    end
    
    
    methods
        function obj = videoReader_FFmpeg(input_vid,storage_loc)
            if nargin == 1 % uses the default storage location which is the input video's location
                obj.file_name = input_vid;
                %building the path to the temporary storage location on the
                %disk
                framesPath = obj.file_name(1:length(obj.file_name)-4);%removing the extention from the video's name
                framesPath = strcat(framesPath,'Frames');
                obj.frame_storage_location = framesPath;
            else %uses the specified storage location
                obj.file_name = input_vid;
                framesPath = obj.file_name(1:length(obj.file_name)-4);%removing the extention from the video's name
                splashes = strfind(framesPath,'/');
                if storage_loc(end) == '/'
                    storage_loc = storage_loc(1:end-1); %removing an eventual '/'
                end
                framesPath = strcat(storage_loc,'/', framesPath(splashes(end) + 1 :end), 'Frames');
                obj.frame_storage_location = framesPath;
            end
            %reading the video's properties using ffprope
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %reading the video's H264 profile
            commandText = strcat('ffprobe -v error -show_format -show_streams',[' ' obj.file_name],' > ',obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            system(commandText);%launching the ffprobe command
            clc;
            textFile = strcat(obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            %looking for the tag profile in the output file
            fid = fopen(textFile);
            tline = fgetl(fid);
            while ischar(tline)
                if length(strfind(tline,'profile')) > 0
                    obj.h264_profile = tline(9:end);
                    break; %breaking the loop when we find the first occurence of profile
                end
                tline = fgetl(fid);
            end
            fclose(fid);%closing and deleting the temporary text file
            delete(textFile);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %       reading the video's rotation parameter %%%%%%%%%%%%%%%%%%%%%%%%
            commandText = strcat('ffprobe -i ',[' ' obj.file_name]);
            textFile = strcat(obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            diary(textFile);
            system(commandText);%launching the ffprobe command
            diary off;
            clc;
            %looking for the tag profile in the output file
            fid = fopen(textFile);
            tline = fgetl(fid);
            obj.rotation_angle = 0;
            while ischar(tline)
                if length(strfind(tline,'rotate')) > 0
                    obj.rotation_angle = str2num(tline(length(tline)-2:length(tline)));
                    break; %breaking the loop when we find the first occurence of profile
                end
                tline = fgetl(fid);
            end
            fclose(fid);%closing and deleting the temporary text file
            delete(textFile);
            
            %%%%% reading the video frame rate %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            commandText = strcat('ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate',[' ' obj.file_name]);
            textFile = strcat(obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            diary(textFile);
            system(commandText);%launching the ffprobe command
            diary off;
            clc;
            fid = fopen(textFile);
            tline = fgetl(fid);
            obj.frame_rate = eval(tline);
            fclose(fid);%closing and deleting the temporary text file
            delete(textFile);
            %%%%%%%%%%%%%%%%%%% read the others video properties
            commandText = strcat('ffprobe -show_frames -select_streams v:0 -show_entries stream=bit_rate',[' ' obj.file_name],' > ',obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            system(commandText);
            textFile = strcat(obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            clc %clearing the console to remove messages from system command
            fid = fopen(textFile);%opening the text file
            tline = fgetl(fid);%reading a line in the text file
            %initializing the counter variables
            nbIframes = 0;
            nbPframes = 0;
            nbBframes = 0;
            arrayIndex = 1;
            GOPcount = 0;
            while ischar(tline)
                %looking for the begining of a frame
                if length(strfind(tline,'[FRAME]')) > 0
                    %reading the info up to getting the end of frame marker
                    tline = fgetl(fid);
                    while length(strfind(tline,'[/FRAME]')) == 0
                        %looking for the marker pict_type
                        if length(strfind(tline,'pict_type')) > 0
                            framesType(arrayIndex) = tline(11);%taking the frame's type
                            %checking for the frame's type to count them
                            switch framesType(arrayIndex)
                                case 'I'
                                    nbIframes = nbIframes + 1;
                                    GOPstruct(arrayIndex) = 0;%GOP structure of the video
                                    GOPcount = GOPcount + 1 ;
                                case 'P'
                                    nbPframes = nbPframes + 1;
                                    GOPstruct(arrayIndex) = GOPcount;
                                    
                                case 'B'
                                    nbBframes = nbBframes + 1;
                                    GOPstruct(arrayIndex) = GOPcount;
                            end
                            arrayIndex = arrayIndex + 1;
                        end
                        %extracting the width and heigth of the video file
                        if length(strfind(tline,'width')) > 0
                            width = str2num(tline(7:length(tline)));
                        end
                        
                        if length(strfind(tline,'height')) > 0
                            height = str2num(tline(8:length(tline)));
                        end
                        
                        
                        tline = fgetl(fid);
                    end
                end
                tline = fgetl(fid);%reading a line in the text file
                %Extracting the bitrate of the video stream which is at the end of the
                %produced file
                if length(strfind(tline,'bit_rate')) > 0
                    bitrate = round((str2num(tline(10:length(tline))))/1000);
                end
            end
            %computing the total number of frames in the video
            nbFrames = nbIframes + nbPframes + nbBframes;
            %determing the indexes of each type of frame
            indexes = 1:1:nbFrames;
            obj.Iframes_indexes = indexes(framesType=='I');
            obj.Pframes_indexes = indexes(framesType=='P');
            obj.Bframes_indexes = indexes(framesType=='B');
            %determining the GOP size
            %indices = 1:1:nbFrames;
            %Iframes = indices(framesType == 'I');
            %Determining the size of each GOP
            %for n = 1 : length(Iframes) -1
            %
            %    GOPsize(n) = Iframes(n + 1) - Iframes(n);
            
            % end
            fclose(fid);
            delete(textFile);
            %assigning results to the object's properties
            obj.resolution = [height, width];
            obj.video_bitrate = bitrate;
            obj.nber_Iframes = nbIframes;
            obj.nber_Pframes = nbPframes;
            obj.nber_Bframes = nbBframes;
            obj.nber_frames = nbFrames;
            obj.GOPs_structure = GOPstruct;
            obj.frames_type = framesType;
            
        end
        %function reading the input video and saving its frames at the
        %specified location
        %@error_occured is a boolean value indicating if an error occured
        %during video reading
        %@loading_log : contains a log of eventual errors that occured
        %during video reading
        function [error_occured, errors_log] = loadToDisk(obj)
            %creating the temporary storage folder
            succeed = mkdir(obj.frame_storage_location);
            if succeed ~= 1  %couldn't open the output folder
                error_occured = 1;
                errors_log{1} = 'frame storage folder could not be created';
                fprintf('frame storage folder could not be created\n');
                return;
            end
            error_count = 0;
            %creating subfolder for specific frame types
            mkdir(obj.frame_storage_location,'Iframes');
            mkdir(obj.frame_storage_location,'PBframes');
            %extracting the I frames in the folder Iframes
            system('ffmpeg -i ',[' ' obj.file_name],' -vf "select=eq(pict_type\,I)" -vsync vfr', obj.frame_storage_location,'/','Iframes','/Iframe%d.bmp'); %extracting I frames
            %counting the number of frames extracted frames which corresponds to the number of files
            %in the folder
            nberIimages = length(dir(strcat(obj.frame_storage_location,'/Iframes'))) - 2;
            if obj.nber_Iframes ~= nberIimages
                obj.nber_Iframes = nberIimages;
                %'/!\ couldnt read all I frames'
                 errors_log{error_count + 1} = 'Could not read all the I frames from the video';
                 error_count = error_count + 1;
            end
            %concatenating the files names for futher checks
            for i = 1 : nberIimages
                framesFileNames = strcat(framesFileNames,fileNames(i).name);
            end
            
            %extracting the P frames in the folder PBframes
            commandText = strcat('ffmpeg -i ',videoPath,' -vf "select=eq(pict_type\,P)" -vsync vfr', framesPath,'/','PBframes','/Pframe%d.bmp');
            system(commandText); %extracting frames
            %counting the number of frames extracted which corresponds to the number of files
            %in the folder
            fileNames = dir(strcat(framesPath(2:length(framesPath)),'/PBframes'));
            fileNames = fileNames(3:length(fileNames));
            nberPimages = length(fileNames);
            if videoProperties.nbPframes ~= nberPimages
                videoProperties.nbPframes = nberPimages;
                %'/!\ couldnt read all the P frames'
                errorMsg = strcat(errorMsg, 'Could not read all the P frames from the video');
            end
            
            for i = 1 : nberPimages
                framesFileNames = strcat(framesFileNames,fileNames(i).name);
            end
            
            %extracting the B frames in the folder PBframes
            commandText = strcat('ffmpeg -i ',videoPath,' -vf "select=eq(pict_type\,B)" -vsync vfr', framesPath,'/','PBframes','/Bframe%d.bmp');
            system(commandText); %extracting frames
            %counting the number of frames extracted which corresponds to the number of files
            %in the folder
            fileNames = dir(strcat(framesPath(2:length(framesPath)),'/PBframes'));
            fileNames = fileNames(3:length(fileNames));
            nberBimages = length(fileNames);
            nberBimages = nberBimages - nberPimages;
            if videoProperties.nbBframes ~= nberBimages
                videoProperties.nbBframes = nberBimages;
                %'/!\ couldnt read all the B frames'
                errorMsg = strcat(errorMsg, 'Could not read all the B frames from the video');
            end
            for i = 1 : nberBimages
                framesFileNames = strcat(framesFileNames,fileNames(i).name);
            end
            %checking the extracted files because the decoder can fail to extract some
            %frames.
            %this part of the script will check that the frames are really extracted and
            %will stop as soon as it meets a frame which could not be extracted
            for i = 1: length(videoProperties.framesType)
                frameImageName = getFrameImageFileName(i,videoProperties);
                testFile = length(strfind(framesFileNames,frameImageName));
                if testFile == 0 %if the corresponding file doesn't exist stop browsing and return the correct chunck
                    videoProperties.framesType = videoProperties.framesType(1:i-1);
                    videoProperties.nbFrames = i-1;
                    break;
                end
                
            end
            %creating a log file if errors has occured during frames reading
            if length(errorMsg) > 0
                '/!\Errors occured during reading; saving a log file/!\'
                fileId = fopen(strcat(framesPath(2:length(framesPath)),'readLog.txt'),'w');
                fprintf(fileId,'%s\n',errorMsg);
                fclose(fileId);
                
            end
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

%function returning the  name of image representing a given frame
%takes as input arguments the frame indice and parameters of the video
%return the file name corresponding to the input file

function frameImageName = getFrameImageFileName(frameIndice, videoParams)

frameIndices = 1:videoParams.nbFrames;
IframeIndices = frameIndices(videoParams.framesType == 'I');
PframeIndices = frameIndices(videoParams.framesType == 'P');
BframeIndices = frameIndices(videoParams.framesType == 'B');
frameType = videoParams.framesType(frameIndice);

%switching to  the right section according to type of frame
switch frameType
    case 'P'
        %looking for the image index in the array of frames
        imageIndice = (PframeIndices == frameIndice);
        imageIndice = find(imageIndice);  
        %file name construction
        fileName = strcat('Pframe',num2str(imageIndice),'.bmp');
    case 'B'
        imageIndice = (BframeIndices == frameIndice);
        imageIndice = find(imageIndice);  
        %file name construction
        fileName = strcat('Bframe',num2str(imageIndice),'.bmp');
    case 'I'             
        imageIndice = (IframeIndices == frameIndice);
        imageIndice = find(imageIndice);  
        %file name construction
        fileName = strcat('Iframe',num2str(imageIndice),'.bmp');        
    
 end

frameImageName = fileName;

end

