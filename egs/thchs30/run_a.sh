#!/bin/bash

set -e

. ./cmd.sh
. ./path.sh

stage=-2
decode_stage=-3
beam=13
mfcc=data/mfcc/test  # data for adaptation
fbank=data/fbank/test # data for adaptation
test_data=data/fbank/test # data for adaptation test
lang=data/lang 
tree=exp/chain-skip/tree
lat_dir=exp/chain-skip/gmm_lats_ada
input_model=exp/chain-skip/tdnn-f-cn # the initial model for adaptation
gmm_dir=exp/tri4b
dir=exp/chain-skip/tdnn_ada

if [ $stage -le 1 ];then
  echo "Produce features for adaptation"
  steps/make_mfcc.sh --nj $n --cmd "$train_cmd" $mfcc
  steps/make_fbank.sh --nj $n --cmd "$train_cmd" $fbank
  steps/compute_cmvn_stats.sh $fbank
fi

if [ $stage -le 2 ];then
  echo "Adaptation training"
  local/chain/run_chain_adapt.sh \
    --mfcc-dir $mfcc --fbank-dir $fbank \
    --lang-dir $lang --tree-dir $tree \
    --lat-dir $lat_dir --input-model $input_model \
    --gmm-dir $gmm_dir --dir $dir
fi

if [ $stage -le 3 ];then
  echo "Decoding"
  steps/nnet3/decode.sh \
    --nj 10 --acwt 1.0 --post-decode-acwt 10.0 \
    --iter final --beam 13  \
    --cmd "$decode_cmd" --stage $decode_stage \
    $input_model/graph $test_data \
    $dir/decode_graph_final

  wer=`cat $dir/decode_graph_final/scoring_kaldi/best_wer`
  echo "Adaptation WER: $wer"
fi

