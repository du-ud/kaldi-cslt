#!/bin/bash

set -e

stage=-1
nj=10

# data and ali dir
mfcc_dir=data/train/mfcc
fbank_dir=data/train/fbank
ali_dir=exp/tri4b_ali
gmm_dir=exp/tri4b

# for decode
lang_dir=data/lang
test_dir=data/fbank/test

# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
train_stage=-10
get_egs_stage=-10
decode_iter=

# TDNN options
frames_per_eg=150,120,90
remove_egs=false
xent_regularize=0.1
preserve_model_interval=5
common_egs_dir=
input_model=exp/chain-skip/tdnn-f-cn/final.mdl
tree_dir=exp/chain-skip/tree
chain_lang=data/lang_chain
lat_dir=exp/chain-skip/gmm_lats_ada
dir=

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. parse_options.sh

# if we are using the speed-perturbed data we need to generate
# alignments for it.

for f in $gmm_dir/final.mdl $fbank_dir/feats.scp \
    $mfcc_dir/feats.scp $ali_dir/ali.1.gz  $input_model/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done
# The adapatation model must use the same structure with teacher model
ln -s $input_model/configs $dir

# Please take this as a reference on how to specify all the options of
# local/chain/run_chain_common.sh

if [ $stage -le 0 ];then
  echo "Generate lattice for trianing data"
  steps/align_fmllr_lats.sh  --nj $nj --cmd "$train_cmd" ${mfcc_dir} \
    $lang_dir $gmm_dir $lat_dir || exit 1;
fi

if [ $stage -le 1 ]; then
 mkdir -p $dir
 steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$cuda_cmd" \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.0 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width $frames_per_eg \
    --trainer.num-chunk-per-minibatch 128  \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs 4 \
    --use-gpu='wait' \
    --trainer.optimization.num-jobs-initial 2 \
    --trainer.optimization.num-jobs-final 4 \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.max-param-change 2.0 \
    --trainer.input-model=$input_model/final.mdl \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval $preserve_model_interval \
    --feat-dir $fbank_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --dir $dir  || exit 1;
fi
