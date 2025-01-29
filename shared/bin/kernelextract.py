#!/usr/bin/env python3

verbose = False

def process_file(input_path, output_path):
    with open(input_path) as f:
        lines = f.readlines()
    
    output_lines = []
    STATE_NORMAL = 0
    STATE_IN_COMPILE = 1
    STATE_IN_HEURISTICS = 2

    state = STATE_NORMAL
    comment_block = False
    paren_count = 0
    
    for line in lines:
        if verbose: print(">", line)
        if state == STATE_NORMAL:
            if 'async_compile.triton(' in line: # state change & line skip
                if verbose: print("changing state to COMPILE")
                state = STATE_IN_COMPILE
                continue
            if verbose: print("NORMAL>", line)
            output_lines.append(line)
        elif state == STATE_IN_COMPILE: 
            if "''', device_str=" in line: # state change & line skip
                if verbose: print("changing state to NORMAL")
                state = STATE_NORMAL
                continue
            if '@triton_heuristics' in line: # state change & line commented
                if verbose: print("changing state to HEURISTICS")
                state = STATE_IN_HEURISTICS
                if verbose: print("COMPILE->HEURISTICS>", line)
                output_lines.append('#' + line)
                continue
            if verbose: print("COMPILE>", line)
            output_lines.append(line)
        elif state == STATE_IN_HEURISTICS:
            if line.strip()==")": # state change & line commented
                if verbose: print("changing state to COMPILE")
                state = STATE_IN_COMPILE
                if verbose: print("HEURISTICS->COMPILE", line)
                output_lines.append('#' + line)
                continue
            if verbose: print("HEURISTICS>", line)
            output_lines.append('#' + line)
    
    with open(output_path, 'w') as f:
        f.writelines(output_lines)

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        if verbose: print("Usage: python script.py input_file output_file")
        sys.exit(1)
    process_file(sys.argv[1], sys.argv[2])


"""TODO
comment these:

async_compile.wait(globals())
del async_compile

change this
grid=torch._inductor.kernel.flex_decoding.flex_decoding_grid(
to
flex_decoding_grid(

just before this

def call(args):

add

def flex_decoding_grid(batch_size, kv_heads, gqa_group_size, n_keys, d_model, meta):
    return (batch_size * kv_heads, meta["SPLIT_KV"], 1)

mod this

triton_tem_fused_0.run(

into

triton_tem_fused_0[grid]

after

import torch

add

from torch._dynamo.testing import rand_strided
"""
