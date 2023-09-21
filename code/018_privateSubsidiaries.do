/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 26/06/2023
Last Modified: 26/06/2023


The purpose of this script is to produce uniform data on private subsidiaries from four distinct sources - the work of Arora, Belenzon, and Sheer (2021), the work of Lev and Mandelker (1972) that we map to Compustat, the Wharton Research Data Services expansion upon and Compustat-mapping of work by Corpwatch that documents subsidiaries as listed in SEC 10-K filings, and our own general research on private M&A activity.

As of the 26th of June 2023, it takes approximately 16 minutes to run in Stata 17 on a computer with 16GB of RAM running an Intel Core i7-1165G7 processor (with 4 CPUs into 8 logical processors and an Intel Iris Xe GPU).

This script is broken down into the following sections:
018a. Restructuring ABS Subsidiary Data - we restructure the subsidiary data from the seminal work of Arora, Belenzon, and Sheer (2021).
018b. Process Data on M&A Activity from General Research - we process the data collated from general research on M&A activity by firms listed in the U.S. and Canada, in addition to that which is documented by Lev and Mandelker (1972).
018c. Process WRDS' Collation of Subsidiaries from SEC 10-K Filings - we process data from Wharton Research Data Services (built on original data by Corpwatch) that matches subsidiaries listed in SEC filings to Compustat gvkeys for 1993-2019.
018d. Collate All Subsidiary Data - we get the ABS subsidiary data, M&A data from general research, and WRDS-SEC subsidiary data into a unified format.


Infiles:
[018a]
	- DISCERN_Panal_Data_1980_2015.dta (The full Compustat-based panel of firms constructed and used by Arora, Belenzon, and Sheer (2018a))
	- DISCERN_SUB_name_list.dta (The full list of subsidiaries found by ABS, in their preferred structural format)
	- permno_gvkey.dta (ABS' crosswalk between their identifier - permno_adj - and gvkeys)
	
[018b]	
	- effectiveAcq_listedPrivate.csv (A list of listed-acquires-private "effective acquisitions", with gvkey of the acquiring firm, name of the acquired firm, and year of acquisition. Constructed through general research and through reference to Lev and Mandelker (1972))

[018c]
	- wrds_sec9319.dta (Subsidiaries listed in various Securities and Exchange Commission (SEC) filings as compiled by Wharton Research Data Services (WRDS) for the period 1993-2019. Dataset originally built on top of the Corpwatch API.)
	
[018d]
No external inputs


Outfiles:
[018a]
	- 018a_permnoAdjYear_names.dta (The name attached to the permno_adj in each year in ABS' panel)
	- 018a_abs_subsName_permnoAdj_year.dta (All subsidiaries found by ABS for the period 1980-2015, attached to the relevant permno_adj)
	- 018a_ABSsubsName_gvkey_year.dta (All subsidiaries sourced from ABS, at the subsidiary_name-gvkey-year level. Note that duplicates at the subsidiary_name-year level are *jointly owned* by 2 gvkeys.)
	
[018b]
	- 018b_genResearch_subsName_gvkey.dta (A mapping of the names of private subsidiaries to their ultimate owner gvkeys for a specified period, as constructed from general research and reference to Lev and Mandelker (1972))

[018c]
	- 018c_wrdsSEC_subsName_gvkey.dta (At the gvkey-Subsidiary level, mappings of subsidiaries (by name) to gvkeys from SEC filings, Oct1992-Jul2019. Derived from the compilation of such filings by WRDS, itself built on the CorpWatch API.)
	
[018d]
	- 018d_collatedSubsidiaries.dta (All subsidiaries sourced from ABS 2021, general research, LM 1972, and 10-Ks, with their clean names. At the gvkey-clean_name-ownership_period level)
	

Called .do Files:
- 018a_elongateABS.do (The script that restructures subsidiary data provided by Arora, Belenzon, and Sheer (2021).)
- 018b_MandAprivate.do (The script that processes the data compiled by our own manual research, as well as the M&A activity documented by Lev and Mandelker (1972))
- 018c_WRDS_SEC.do (The script that processes data on subsidiaries from SEC 10-K filings, as compiled by WRDS on top of the original effort by Corpwatch)
- 018d_collateSubsidiaries.do (The script that collates the separate data sources from 018a, 018b, and 018c into a unified format)
	- 500_nameCleaning.do (The centralised name cleaning algorithm)


External Packages:
None


*/

********************************************************************************
*********************************** PREAMBLE ***********************************
********************************************************************************
/*
* Drop Anything Still in the Global Environment *

clear all
set more off
macro drop _all
capture log close
graph drop _all


* Preferred Settings *

set rmsg on, permanently
set scheme modern, permanently
set maxvar 10000


* Set Working Directory *

cd "C:/Users/Ollie/Dropbox/State and innovation" // Ollie's laptop

// cd "/Users/ios/Dropbox/State and innovation" // Arnaud's laptop

// cd "/Users/stateinnovation/Dropbox/State and innovation" // Turing MacBook


* Set Shorthands *

global code "C:/Users/Ollie/Dropbox/State and innovation/code"
global outputs "C:/Users/Ollie/Dropbox/State and innovation/outputs"
global doc "C:/Users/Ollie/Dropbox/State and innovation/doc"
global data "C:/Users/Ollie/Dropbox/State and innovation/data"
global temp "C:/Users/Ollie/Dropbox/State and innovation/temp"
global orig "C:/Users/Ollie/Dropbox/State and innovation/orig"
*/




********************************************************************************
******************************* RUN THE .do FILES ******************************
********************************************************************************

* 018a - Restructure ABS Subsidiary Data *

do "$code/018a_elongateABS.do"


* 018b - Process Subsidiary Data from Our Own Research and that of Lev and Mandelker (1972) *

do "$code/018b_MandAprivate.do"


* 018c - Process Subsidiary Data from SEC 10-K Filings as Compiled by WRDS *

do "$code/018c_WRDS_SEC.do"


* 018d - Collate All Subsidiary Data *

do "$code/018d_collateSubsidiaries.do"