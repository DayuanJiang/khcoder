# KH Coder: for Quantitative Content Analysis or Text Mining

## Description

Web pages, screenshots, documentations, discussion forum, and file releases are still on SourceForge.
http://khc.sourceforge.net/en/

I am going to gradually move them here.

## How to run source code of KH Coder on Windows

1. Download & install Perl: http://strawberryperl.com/
2. (Fork and) clone this repository
3. Download \*.exe file (Winzip self-extractor) of KH Coder 3 from http://khc.sourceforge.net/en/
4. Unzip the downloaded file into the clone directory
5. Open command prompt window and go to the clone directory, type "perl kh_coder.pl", and hit "Enter" key

If you get errors like "Can't locate **Jcode**.pm in @INC", you need to install Perl module called "**Jcode**". To install it, type "cpanm **Jcode**" and hit "Enter" key on your command prompt window.

Above procedure is for people who want to modify or develop KH Coder. If you want to just run, try or use KH Coder, just unzip the \*.exe and double click “kh_coder.exe”.

## On Linux or other Un\*x like system

You need:

- MySQL
- Perl (and various Perl modules)
- R (and some R packages)
- Morphological Analysis and POS Tagging software
    - ChaSen or MeCab for analyzing Japanese text
    - FreeLing for analyzing Catalan, English, French, German, Italian, Portuguese, Russian or Spanish text
    - MeCab and HanDic for analyzing Korean text
    - Stanford POS Tagger and JAVA for analyzing English text
    - Stanford Word Segmenter, Stanford POS Tagger and JAVA for analyzing English text

## License

GNU GPL version 2 or later