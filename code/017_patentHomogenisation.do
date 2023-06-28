/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 12/09/2022
Last Modified: 14/09/2022


Here, we homogenise the names given to firms associated with patents. The general aims that guide this are:
- Cleaning firm names, such that, for example "GOOGLE CORP" and "GOOGLE CORPORATION" are given the same firm name.
- Homogenising patent names across the Fleming, Greene, Li, Marx and Yao (2019) data (used for the 1926-1975 period) and the PatentsView data (used for the 1976-2021 period).
- Homogenising patent names within our collated data, such that the attribution of a patent is to the ultimate owners, in the spirit of Arora, Belenzon, and Sheer (2020).

As of the 27th of June 2023, it takes approximately 4 hours and 26 minutes to run in Stata 17 on a computer with 16GB of RAM running an Intel Core i7-1165G7 processor (with 4 CPUs into 8 logical processors and an Intel Iris Xe GPU).

This script is broken down into the following sections:
017a. Name Cleaning - we simply run all firm names from both the FGLMY and PatentsView data through our centralised name cleaning algorithm, which can be found under 500_nameCleaning.do.
017b. FGLMY Re-parsing - we re-parse several of the observations in FGLMY which include a full sentence under the associated firm name.
017c. FGLMY-to-PatentsView Automated Mapping - we map clean names as they appear in FGLMY to clean names associated with the same patents (from the common 1976-2021 period) in PatentsView.
017d. Substring Match - following homogenisation of firm names across the FGLMY and PatentsView data, we take all clean names associated with 50 or more patents and find those which are substrings of each other.
017e. Further Manual Cleaning - following the substring match, we look into the top 250 patenters
017f. Creating a Full Clean Patent Dataset - following further manual cleaning, we construct a long-form patent dataset with associated original and clean names, in addition to indicator variables concenrning the generation of the clean name.


Infiles:
[017a]
	- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
	- patent.dta (PatentsView's largest patent dataset, most pertinently containing the patent's publication number and the publication date.)
	- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
	- assignee.dta (PatentsView's data on assignee information linked to its unique assignee_id)
	
[017b]
	- fglmyReparse_mapping_manuallyReviewed.csv (Observations are manually confirmed mappings from an original FGLMY name of the form "ASSIGNORSTOCOMPANYNAME..." to "COMPANYNAME")
	
[017c]
	- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
	- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
	- rawassignee.dta (A detailed link between patents and their associated PatentsView assignee_id, which includes the order in which assignees appear on patents with multiple assignees.)
	- resolve_fglmyToPview_errors.csv (Observations are correct mappings from FGLMY to PatentsView for those FGLMY clean names whose automated mapping to PatentsView is erroneous)
	- resolve_fglmyToPview_manualAdditions.csv (Observations are FGLMY-to-PatentsView mappings from top patenters in the FGLMY data who have no automated mapping to PatentsView)

[017d]
	- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
	- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
	- jvManualRemap.csv (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with)
	- substring_match_manuallyReviewed.csv (Observations are clean_name-to-clean_name mappings from the internal substring match process that are retained following manual review)

[017e]
	- lowPat_vacuumNames.csv (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries [with fewer than 50 patents] using the start of the subsidiaries' clean name)
	- subsidiaryManualRemap.csv (Observations are clean_name-to-clean_name mappings from the subsidiaries [with 50 or more patenters] of top patenters to the central clean name of said patenter)
	- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
	- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)

[017f]
	- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
	- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
	

Outfiles:
[017a]
	- 017a_fglmy_names_1.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts)
	- 017a_pview_names_1.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts)

[017b]
	- 017b_fglmyReparse_mapping.dta (Observations are all reparsable clean names from the FGLMY dataset with their reparsed clean names)
	- 017b_fglmyReparse_mapping_manuallyReviewed.dta (A manually cleaned version of the outfile dataset 017b_fglmyReparse_mapping.dta)
	- 017b_fglmy_names_2.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* reparsing)

[017c]
	- 017c_pviewFGLMY_namePairs.dta (Observations are pairs of clean names [one from FGLMY, one from PatentsView] that are together associated with one or more patents, along with patent counts)
	- 017c_resolve_fglmyToPview_errors.dta (Observations are correct mappings from FGLMY to PatentsView for those FGLMY clean names whose automated mapping to PatentsView is erroneous)
	- 017c_fglmyToPview_nameMap.dta (Observations are mappings from FGLMY clean names to probabilistically associated PatentsView clean names)
	- 017c_resolve_flemToPview_manualAdditions.dta (Observations are FGLMY-to-PatentsView mappings from top patenters in the FGLMY data who have no automated mapping to PatentsView)
	- 017c_fglmy_names_3.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* automated and manual homogenisation between FGLMY and PatentsView)

[017d]
	- 017d_namesForSubstringMatch.dta (Observations are names from either 017_fglmy_names_3.dta or 017_pview_names_1.dta, with associated patent counts for 1926-1975, 1976-2021, and 1926-2021)
	- 017d_substringMatch.dta (Observations are all clean names with 50 or more associated patents that contain as a substring a different clean name with 50 or more associated patents, along with the longest clean name that is a strict substring)
	- 017d_jvManualRemap.dta (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with)
	- 017d_substringMatch_manuallyReviewed.dta (A manually reviewed version of the data produced in 017d_substringMatch.dta)
	- 017d_substringMatch_mapping.dta (Observations are those observations from 017_substringMatch.dta that are deemed to be legitimate)
	- 017d_fglmy_names_4.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the substring matching)
	- 017d_pview_names_4.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the substring matching) [Note that 017_pview_names_2.dta and 017_pview_names_3.dta do not exist by design]

[017e]
	- 017e_lowPat_vacuumNames.dta (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries [with fewer than 50 patents] using the start of the subsidiary's clean name)
	- 017e_subsidiaryManualRemap.dta (Observations are clean_name-to-clean_name mappings from the subsidiaries [with 50 or more patents] of top patenters to the central clean name of said patenter)
	- 017e_lowPat_autoMapping.dta (Observations are clean names with fewer than 50 associated patents that have been automatically remapped to one of the top 250 patenters)
	- 017e_fglmy_names_5.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)
	- 017e_pview_names_5.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)

[017f]
	- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)


Called .do Files:
- 017a_nameCleaningPatents.do (The script that cleans all original names associated with patents in both FGLMY and PatentsView.)
	- 500_nameCleaning.do (The centralised name cleaning algorithm.)
- 017a_fglmyReparse.do (The script that addresses some parsing errors in the FGLMY data.)
- 017c_fglmyToPview_autoMapping.do (The script that homogenises firm names *across* datasets, replacing clean names in FGLMY with automatically matched clean names in PatentsView.)
- 017d_substringMatchRun.do (The script that takes all clean names and looks for substring matches amongst patenters with 50 or more associated patents.)
- 017e_furtherManualCleaning.do (The script that takes care of large [manually] and small [automatically] subsidiaries of high-patenting firms, as well as of joint ventures amongst high-patenting firms)
- 017f_fullData_patentHomogenisation.do (The script that collates all the data following name cleaning, homogenisation, and review)


External Packages:
- strdist by Michael Barker and Felix Pöge [used in 017b, 017c]
- jarowinkler by James Feigenbaum [used in 017c]

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

* Install External Packages *

ssc install strdist // Used in 017b, 017c
ssc install jarowinkler // Used in 017c




********************************************************************************
**************************** RUNNING THE .DO FILES *****************************
********************************************************************************

* 017a - Clean Names Associated with Patents *

do "$code/017a_nameCleaningPatents.do"


* 017b - Re-parse Mis-parsed FGLMY Names *

do "$code/017b_fglmyReparse.do"


* 017c - Automated Mapping of FGLMY Clean Names to PatentsView Firm Names *

do "$code/017c_fglmyToPview_autoMapping.do"


* 017d - Substring Match *

do "$code/017d_substringMatchRun.do"


* 017e - Further Manual Cleaning *

do "$code/017e_furtherManualCleaning.do"


* 017f - Production of Full Patent-Clean_Name Dataset *

do "$code/017f_fullData_patentHomogenisation.do"