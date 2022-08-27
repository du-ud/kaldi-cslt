#!/usr/bin/env python3
import sys
import io
import jieba
jieba.set_dictionary(sys.argv[1])

input_stream = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
output_stream = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
#print(input_stream)
for l in input_stream:
     output_stream.write(" ".join(jieba.cut(l, False, False)))
