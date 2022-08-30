# -*- coding: utf-8 -*-
import os
import sys
fid=open('wav.scp','a')
path=sys.argv[1]
#path=os.getcwd() 
def get_file(path):
    for root, dirs, files in os.walk(path):
        for file in files:
            path=str(os.path.join(root,file))
            name=str(os.path.basename(path))
            name_1=str(os.path.splitext(name)[0])
            name_2=str(os.path.splitext(name)[1])
            wav_scp=name_1 + ' ' + path
            #if  name_2 == '.WAV':
            if name_2 == '.WAV'or name_2 == '.wav':
                print wav_scp
                fid.write(wav_scp)
                fid.write('\n')
get_file(path)
