#!/bin/bash

MYVIMRC=.vimrc
VIMRC=~/.vimrc
NVIMRC_DIR=~/.config/nvim
NVIMRC=~/.config/nvim/init.vim

if [ command -v vim 2>/dev/null ]; then
    cp $MYVIMRC $VIMRC
    echo "copied to $VIMRC"
fi

if [ command -v nvim 2>/dev/null ]; then
    if ! [ -d $NVIMRC_DIR ]; then
        mkdir -p $NVIMRC_DIR
    fi
    cp $MYVIMRC $NVIMRC
    echo "copied to $NVIMRC"
fi

cp -a .vim_runtime/. ~/

