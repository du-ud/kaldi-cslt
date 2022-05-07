./configure --static \
      --use-cuda=yes --cudatk-dir=/usr/local/cuda \
      --mathlib=OPENBLAS --openblas-root=../tools/OpenBLAS/install \
      --static-math=yes \
      --static-fst=yes --fst-root=../tools/openfst

make depend -j 40

make -j 40
