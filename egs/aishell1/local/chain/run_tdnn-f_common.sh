#!/bin/bash

set -e

stage=15
decode_nj=50

# data and ali dir
mfcc_dir=data/mfcc/train
fbank_dir=data/fbank/train
test_dir=data/fbank/test
ali_dir=exp/tri4b_ali
gmm_dir=exp/tri4b
tree_dir=exp/chain/tree
lang=data/lang_chain
lat_dir=exp/chain-no-skip/gmm_lats
dir=exp/chain/tdnn-f
# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
train_stage=-3
get_egs_stage=5
decode_iter=

# TDNN options
frames_per_eg=150,110,100
remove_egs=false
common_egs_dir=
xent_regularize=0.1
gmm_dir=exp/tri4b
preserve_model_interval=200
# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. parse_options.sh

# if we are using the speed-perturbed data we need to generate
# alignments for it.

for f in $ali_dir/final.mdl $fbank_dir/feats.scp \
    $mfcc_dir/feats.scp $ali_dir/ali.1.gz; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

# Please take this as a reference on how to specify all the options of
# local/chain/run_chain_common.sh
 local/chain/run_chain_common.sh --stage $stage \
                                 --gmm-dir $gmm_dir \
                                 --ali-dir $ali_dir \
                                 --lores-train-data-dir ${mfcc_dir} \
                                 --lang $lang \
                                 --lat-dir $lat_dir \
                                 --num-leaves 10000 \
                                 --tree-dir $tree_dir || exit 1;

if [ $stage -le 14 ]; then
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree | grep num-pdfs | awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
  opts="l2-regularize=0.002"
  linear_opts="orthonormal-constraint=1.0"
  output_opts="l2-regularize=0.0005 bottleneck-dim=256"

  mkdir -p $dir/configs

  cat <<EOF > $dir/configs/network.xconfig
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-1,0,1) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-batchnorm-layer name=tdnn1 $opts dim=1280
  linear-component name=tdnn2l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn2 $opts input=Append(-1,0,1) dim=1280
  linear-component name=tdnn3l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn3 $opts dim=1280
  linear-component name=tdnn4l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn4 $opts input=Append(-1,0,1) dim=1280
  linear-component name=tdnn5l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn5 $opts input=Append(-1,0,1) dim=1280
  linear-component name=tdnn6l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn6 $opts input=Append(-2,0,2) dim=1280
  linear-component name=tdnn7l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn7 $opts input=Append(-2,0,2) dim=1280
  linear-component name=tdnn8l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn8 $opts input=Append(-2,0,2) dim=1280
  linear-component name=tdnn9l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn9 $opts input=Append(-3,0,3) dim=1280
  linear-component name=tdnn10l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn10 $opts input=Append(-3,0,3) dim=1280
  linear-component name=tdnn11l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn11 $opts input=Append(-3,0,3) dim=1280
  linear-component name=prefinal-l dim=256 $linear_opts
  
  relu-batchnorm-layer name=prefinal-chain input=prefinal-l $opts dim=1280
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts
  
  relu-batchnorm-layer name=prefinal-xent input=prefinal-l $opts dim=1280
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi

if [ $stage -le 15 ]; then
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
    --trainer.num-chunk-per-minibatch 128 \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs 6 \
    --use-gpu='wait' \
    --trainer.optimization.num-jobs-initial 3 \
    --trainer.optimization.num-jobs-final 6 \
    --trainer.optimization.initial-effective-lrate 0.01 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval $preserve_model_interval \
    --feat-dir $fbank_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --dir $dir  || exit 1;
fi
