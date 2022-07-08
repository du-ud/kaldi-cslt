dir=exp/lm
lm_dir=
gmm_mdl_dir=exp/tri4b
nn_mdl_dir=exp/chain-skip/tdnn-f-cn

mkdir $dir
tar czvf $dir/corpus.lm_e-7.tar.gz  data_thchs30/lm_word/word.3gram.lm

./utils/format_lm.sh  data/lang $dir/corpus.lm_e-7.tar.gz  data/lang $dir/lang_test

./utils/mkgraph.sh   $dir/lang_test $gmm_mdl_dir  $gmm_mdl_dir/graph

./utils/mkgraph.sh  --self-loop-scale 1.0 $dir/lang_test $nn_mdl_dir  $nn_mdl_dir/graph
