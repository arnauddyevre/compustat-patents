# compustat-patents

___

This repository contains two datasets mapping publicly listed firms from Compustat to patents from the U.S. Patents and Trademark Office, from 1950 to 2020. 
Anyone is very welcome to use the data, provided that appropriate credit is given by citing *[Dyèvre, A.]([url](http://arnauddyevre.com)) & Seager, O. (2023) **70 Years of Patents Matched to Compustat Firms: Methodology and Insights About Firm Heterogeneity**, STICERD*.

### Structure

The repository is organised as follows:
- `code`: contains the Stata and Python code used to generate the final panels of firms matched to patents. The code takes as inputs datasets described in `orig` and saves outputs in `data`
- `data`: contains two datsets, in .csv format. "static.csv" and "dynamic.csv". "static.csv" contains a static match of patents to Compustat gvkeys according to year of patent application. "dynamic.csv" contains a list of reassignment events, according to which patents should be reassigned from one gvkey to another.
- `orig`: contains *descriptions* of the raw datasets used by scripts in `code` to create the final datasets in `data`. These datasets are either very large (like most of the patent datasets) or proprietary (Compustat annual) so we only provide descriptions of the data and directions on how to get them.
- `doc`: contains the working paper describing how the data in `data` is constructed, as well as a readme file giving more information about the code.

### Log

- First created: April 10th, 2023
- Last modified: June 23rd, 2023

### Licence and attribution

The datasets in "data" are made available under the Creative Commons Attribution 4.0 International (CC-BY-4.0) license. If you use this dataset, please cite the working paper as follows:
Dyèvre, A. & Seager, O. **Matching Patents to Publicly Listed Firms in the US: 1950-2020**, working paper

[![License: CC BY 4.0](https://licensebuttons.net/l/by/4.0/88x31.png)](https://creativecommons.org/licenses/by/4.0/)
