#!/bin/bash

git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime

cp .vimrc  ~/.vimrc

git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

git clone --recurse-submodules -j8  https://github.com/Valloric/YouCompleteMe.git ~/.vim/bundle/YouCompleteMe
cd ~/.vim/bundle/YouCompleteMe
./install.py --clang-completer
cd ~

