#!/bin/bash

. ./cmd.sh
. ./path.sh

graph_dir=exp/tri4b/graph 
exp_dir=exp/tri4b

for f in $graph_dir/HCLG.fst ; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done


steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 --config conf/decode.config \
$graph_dir data/mfcc/test $exp_dir/decode_test || exit 1;

cat exp/tri4b/decode_test*/scoring_kaldi/best_wer
#result:
#%WER 27.97 [ 22691 / 81139, 426 ins, 709 del, 21556 sub ] exp/tri4b/decode_test/wer_10_0.0
#%WER 31.48 [ 25544 / 81139, 463 ins, 965 del, 24116 sub ] exp/tri4b/decode_test.si/wer_11_0.0