classdef videoReader_FFmpeg < handle
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
    %(C): Emmanuel Kiegaing Kouokam 2019, Image processin laboratory,
    %Uludag university
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
    properties (SetAccess=private)
        errors_log %log of all error associated with the operations performed on the input video
    end
    
     properties (SetAccess=private)
        error_count %log of all error associated with the operations performed on the input video
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
            obj.error_count = 0;
            obj.errors_log = [];
            %reading the video's properties using ffprope
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %reading the video's H264 profile
            system(strcat('ffprobe -v error -show_format -show_streams',[' ' obj.file_name],' > ',[' ' obj.file_name(1:length(obj.file_name)-4)],'_', 'videoInfos.txt'));%launching the ffprobe command
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
            textFile = strcat(obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            diary(textFile);
            system(strcat('ffprobe -i ',[' ' obj.file_name]));%launching the ffprobe command
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
            textFile = strcat(obj.file_name(1:length(obj.file_name)-4),'_', 'videoInfos.txt');
            diary(textFile);
            system(strcat('ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate',[' ' obj.file_name]));%launching the ffprobe command
            diary off;
            clc;
            fid = fopen(textFile);
            tline = fgetl(fid);
            obj.frame_rate = eval(tline);
            fclose(fid);%closing and deleting the temporary text file
            delete(textFile);
            %%%%%%%%%%%%%%%%%%% read the others video properties
            commandText = strcat('ffprobe -show_frames -select_streams v:0 -show_entries stream=bit_rate',[' ' obj.file_name],' > ',[' ' obj.file_name(1:length(obj.file_name)-4)],'_', 'videoInfos.txt');
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
        function [error_occured] = loadToDisk(obj)
            %creating the temporary storage folder
            succeed = mkdir(obj.frame_storage_location);
            if succeed ~= 1  %couldn't open the output folder
                error_occured = 1;
                obj.error_count = obj.error_count + 1;
                obj.errors_log{obj.error_count} = 'frame storage folder could not be created';
                fprintf('frame storage folder could not be created\n');
                return;
            end
            %creating subfolder for specific frame types
            mkdir(obj.frame_storage_location,'Iframes');
            mkdir(obj.frame_storage_location,'PBframes');
            %extracting the I frames in the folder Iframes
            system(strcat('ffmpeg -i ',[' ' obj.file_name],' -vf "select=eq(pict_type\,I)" -vsync vfr', [' ' obj.frame_storage_location],'/','Iframes','/Iframe%d.bmp')); %extracting I frames
            %counting the number of frames extracted frames which corresponds to the number of files
            %in the folder
            nberIimages = length(dir(strcat(obj.frame_storage_location,'/Iframes'))) - 2;
            if obj.nber_Iframes ~= nberIimages
                obj.nber_Iframes = nberIimages;
                %'/!\ couldnt read all I frames'
                obj.error_count = obj.error_count + 1;
                obj.errors_log{obj.error_count} = 'Could not read all the I frames from the video';
                fprintf('%s\n',obj.errors_log{obj.error_count});
                
            end
            %concatenating the files names for futher checks
            fileNames = dir(strcat(obj.frame_storage_location,'/Iframes'));
            fileNames = fileNames(3:length(fileNames));
            framesFileNames = '';
            for i = 1 : nberIimages
                framesFileNames = strcat(framesFileNames,fileNames(i).name);
            end
            
            %extracting the P frames in the folder PBframes
            system(strcat('ffmpeg -i ',[' ' obj.file_name],' -vf "select=eq(pict_type\,P)" -vsync vfr', [' ' obj.frame_storage_location],'/','PBframes','/Pframe%d.bmp')); %extracting frames
            %counting the number of frames extracted which corresponds to the number of files
            %in the folder
            fileNames = dir(strcat(obj.frame_storage_location,'/PBframes'));
            fileNames = fileNames(3:length(fileNames));
            nberPimages = length(fileNames);
            if obj.nber_Pframes ~= nberPimages
                obj.nber_Pframes = nberPimages;
                %'/!\ couldnt read all the P frames'
                obj.error_count = obj.error_count + 1;
                obj.errors_log{obj.error_count} = 'Could not read all the P frames from the video';
                fprintf('%s\n',obj.errors_log{obj.error_count});
                
            end
            
            for i = 1 : nberPimages
                framesFileNames = strcat(framesFileNames,fileNames(i).name);
            end
            
            %extracting the B frames in the folder PBframes
            system(strcat('ffmpeg -i ',[' ' obj.file_name],' -vf "select=eq(pict_type\,B)" -vsync vfr', [' ' obj.frame_storage_location],'/','PBframes','/Bframe%d.bmp')); %extracting frames
            %counting the number of frames extracted which corresponds to the number of files
            %in the folder
            fileNames = dir(strcat(obj.frame_storage_location,'/PBframes'));
            fileNames = fileNames(3:length(fileNames));
            nberBimages = length(fileNames) - nberPimages;
            if obj.nber_Bframes ~= nberBimages
                obj.nber_Bframes = nberBimages;
                %'/!\ couldnt read all the B frames'
                obj.error_count = obj.error_count + 1;
                obj.errors_log{obj.error_count} = 'Could not read all the B frames from the video';
                fprintf('%s\n',obj.errors_log{obj.error_count});
                
            end
            for i = 1 : nberBimages
                framesFileNames = strcat(framesFileNames,fileNames(i).name);
            end
            %checking the extracted files because the decoder can fail to extract some
            %frames.
            %this part of the script will check that the frames are really extracted and
            %will stop as soon as it meets a frame which could not be extracted
            for i = 1: length(obj.frames_type)
                frameImageName = getFrameImageFileName(i,obj);
                testFile = length(strfind(framesFileNames,frameImageName));
                if testFile == 0 %if the corresponding file doesn't exist stop browsing and return the correct chunck of frames
                    obj.frames_type = obj.frames_type(1:i-1);
                    obj.nber_frames = i-1;
                    error_occured = 1;
                    break;
                end
                
            end
            clc
        end
        %function deleting the strored frames form the hard disk.
        function unloadFromDisk(obj)
            system(strcat('rm',[' ' obj.frame_storage_location],' -r'));
        end
        
        %function reading a frame which index is given as parameter
        function [frame] = readFrame(obj,frame_index)
            %checking that the frame index is withing the valid range
            if frame_index <= obj.nber_frames
                %switching to wright section according to type of frame
                switch obj.frames_type(frame_index)
                    case 'P'
                        %looking for the image index in the array of frames
                        image_index = (obj.Pframes_indexes == frame_index);
                        image_index = find(image_index);
                        %file name construction
                        fileName = strcat(obj.frame_storage_location,'/PBframes/Pframe',num2str(image_index),'.bmp');
                    case 'B'
                        image_index = (obj.Bframes_indexes == frame_index);
                        image_index = find(image_index);
                        %file name construction
                        fileName = strcat(obj.frame_storage_location,'/PBframes/Bframe',num2str(image_index),'.bmp');
                    case 'I'
                        image_index = (obj.Iframes_indexes == frame_index);
                        image_index = find(image_index);
                        %file name construction
                        fileName = strcat(obj.frame_storage_location,'/Iframes/Iframe',num2str(image_index),'.bmp');
                        
                end
                
                frame = imread(fileName);
            else
                obj.error_count = obj.error_count + 1;
                obj.errors_log{obj.error_count} = strcat('Frame', [' ' num2str(frame_index)], ' is out of bounds');
                frame = []; %retun an empty matrix because the frame doesn't exit
                fprintf('%s\n',obj.errors_log{obj.error_count});
                %fprintf('error count %i\n',obj.error_count);
            end
        end
        
        %getter for errors_log
        function printErrors(obj)
            
            for i = 1 : obj.error_count
            
                fprintf('%s\n',obj.errors_log{i});
            end
        end
        
    end
end

%function returning the  name of image representing a given frame
%takes as input arguments the frame indice and parameters of the video
%return the file name corresponding to the input file

function frameImageName = getFrameImageFileName(frame_indice, video_reader_obj)

%switching to  the right section according to type of frame
switch video_reader_obj.frames_type(frame_indice)
    case 'P'
        %looking for the image index in the array of frames
        image_index = (video_reader_obj.Pframes_indexes == frame_indice);
        image_index = find(image_index);
        %file name construction
        fileName = strcat('Pframe',num2str(image_index),'.bmp');
    case 'B'
        image_index = (video_reader_obj.Bframes_indexes == frame_indice);
        image_index = find(image_index);
        %file name construction
        fileName = strcat('Bframe',num2str(image_index),'.bmp');
    case 'I'
        image_index = (video_reader_obj.Iframes_indexes == frame_indice);
        image_index = find(image_index);
        %file name construction
        fileName = strcat('Iframe',num2str(image_index),'.bmp');
        
end

frameImageName = fileName;

end

