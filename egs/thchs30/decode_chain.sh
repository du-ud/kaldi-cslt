#!/bin/bash

. ./path.sh
. ./cmd.sh
exp_dir=exp/chain-skip/tdnn-f-cn
beam=13
stage=-3
for data_set in test  ;do
      steps/nnet3/decode.sh \
      --nj 8 --acwt 1.0 --post-decode-acwt 10.0 \
      --cmd "run.pl" --iter final \
      --stage $stage \
      $exp_dir/graph  data/fbank/$data_set $exp_dir/decode_graph_final
done
cat $exp_dir/decode_graph_final/scoring_kaldi/best_wer

#result: %WER 21.75 [ 17647 / 81139, 149 ins, 664 del, 16834 sub ] exp/chain-skip/tdnn-f-cn/decode_graph_final/wer_10_0.0



