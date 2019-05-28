# videoReaderMatlab_FFmpeg
A class to read (almost) all types of video in Matlab. This class has  been developped as a alternative (and more) to matlab VideoReader object that is sometime buggy under Ubuntu.
I also provides all the properties of the input video including the type (I, P, B) of each frame. The class uses FFmpeg to decode and save all the frames of the input video as .bmp files at a specified location  (hard drive) and thus doesn't make usage of the computer's RAM . FFprobe is used to read the properties of the input videos (fps, video bitrate, video resolution, frames type, video rotation parameter).
## class's accessible properties:
- __*file_name*__: path to the video.
- __*resolution*__: video's resolution [height, width].
- __*video_bitrate*__: video bitrate.
- __*frame_rate*__: frame rate (fps).
- __*orientation*__: rotation angle.
- __*nber_Iframes*__: number of I frames.
- __*nber_Pframes*__: number of P frames.
- __*nber_Bframes*__:number of B frames.
- __*nber_frames*__:total number of frames.
- __*frames_type*__: array giving the type of each frame (I,P,B).
- __*Iframes_indexes*__: array giving indexes of I frames.
- __*Pframes_indexes*__: array giving indexes of P frames.
- __*Bframes_indexes*__: array giving indexes of B frames.
- __*GOPs_structures*__: array giving the structure of each Group Of Pictures (GOP).

## Class's methods:
 - __*obj(video_path, temp_path)*__: class constructor, recieves the video path and a frames' temporary storage location.
All the video's properties are readable after the object's instantiation.
- __*obj.loadToDisk()*__: decodes the video and saves its frames as .bmp files at the specified location.
- __*[frame] = obj.readFrame(frame_index)*__: reads the frames of specified index.
- __*obj.unloadFromDisk()*__: frees the space on the hard drive alocated for frames' temporary storage.

## Exemple 

