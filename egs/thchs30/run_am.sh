#!/bin/bash

# Copyright 2016  Tsinghua University (Author: Dong Wang, Xuewei Zhang)
#           2018  Tsinghua University (Author: Zhiyuan Tang)
#           2019  Tsinghua University (Author: Wenqiang Du)
# Apache 2.0.

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh

n=10 # parallel jobs
stage=-4
set -euo pipefail
# at present, kaldi supports python 2
py_ver=`python -c 'import sys; v, _, _, _, _= sys.version_info;  print("%d" % v)'`
if [ $py_ver -gt 2 ]; then echo "Python version should be 2 (now $py_ver)"; exit 1; fi

echo '###### Bookmark: basic preparation ######'

# corpus and trans directory
thchs=/work105/duwenqiang/data/


#you can obtain the database by uncommting the following lines
#[ -d $thchs ] || mkdir -p $thchs  || exit 1
#echo "downloading THCHS30 at $thchs ..."
#local/download_and_untar.sh $thchs  http://www.openslr.org/resources/18 data_thchs30  || exit 1
#local/download_and_untar.sh $thchs  http://www.openslr.org/resources/18 resource      || exit 1


if [ $stage -le 1 ];then
  local/thchs-30_data_prep.sh $thchs/data_thchs30
  ln -s $thchs/data_thchs30 data_thchs30
  echo '###### Bookmark: language preparation ######'
  # prepare lexicon.txt, extra_questions.txt, nonsilence_phones.txt, optional_silence.txt, silence_phones.txt
  # build a large lexicon that invovles words in both the training and decoding, all in data/dict
  mkdir -p data/dict;
  cp $thchs/resource/dict/{extra_questions.txt,nonsilence_phones.txt,optional_silence.txt,silence_phones.txt} data/dict && \
  cat $thchs/resource/dict/lexicon.txt $thchs/data_thchs30/lm_word/lexicon.txt | \
  grep -v '<s>' | grep -v '</s>' | sort -u > data/dict/lexicon.txt

  echo '###### Bookmark: language processing ######'
  # generate language stuff used for training
  # also lexicon to L_disambig.fst for graph making in local/thchs-30_decode.sh
  mkdir -p data/lang;
  utils/prepare_lang.sh --position_dependent_phones false data/dict "<SPOKEN_NOISE>" data/local/lang data/lang
fi 

if [ $stage -le 2 ];then
  echo '###### Bookmark: feature extraction ######'
  # produce MFCC and Fbank features in data/{mfcc,fbank}/{train,test}
  rm -rf data/mfcc && mkdir -p data/mfcc && cp -r data/{train,test} data/mfcc
  rm -rf data/fbank && mkdir -p data/fbank && cp -r data/{train,test} data/fbank
  for x in train test; do
    # make mfcc and fbank
    steps/make_mfcc.sh --nj $n --cmd "$train_cmd" data/mfcc/$x
    steps/make_fbank.sh --nj $n --cmd "$train_cmd" data/fbank/$x
    # compute cmvn
    steps/compute_cmvn_stats.sh data/mfcc/$x
    steps/compute_cmvn_stats.sh data/fbank/$x
  done
fi

if [ $stage -le 3 ];then
  echo '###### Bookmark: GMM-HMM training ######'
  # monophone
  steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/mono
  # monophone ali
  steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/mono exp/mono_ali
  
  # triphone
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 2000 10000 data/mfcc/train data/lang exp/mono_ali exp/tri1
  # triphone_ali
  steps/align_si.sh --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/tri1 exp/tri1_ali
  
  # lda_mllt
  steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 2500 15000 data/mfcc/train data/lang exp/tri1_ali exp/tri2b
  # lda_mllt_ali
  steps/align_si.sh  --nj $n --cmd "$train_cmd" --use-graphs true data/mfcc/train data/lang exp/tri2b exp/tri2b_ali
  
  # sat
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 data/mfcc/train data/lang exp/tri2b_ali exp/tri3b
  # sat_ali
  steps/align_fmllr.sh --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/tri3b exp/tri3b_ali
  
  # quick
  steps/train_quick.sh --cmd "$train_cmd" 4200 40000 data/mfcc/train data/lang exp/tri3b_ali exp/tri4b
  # quick_ali
  steps/align_fmllr.sh --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/tri4b exp/tri4b_ali
fi

if [ $stage -le 4 ];then
  echo '###### Bookmark: TDNN-F Chain Training ######'
  local/chain/run_tdnn-f_common_skip.sh \
    --mfcc-dir data/mfcc/train --fbank-dir data/fbank/train \
    --gmm-dir exp/tri4b --ali-dir exp/tri4b_ali 
fi
