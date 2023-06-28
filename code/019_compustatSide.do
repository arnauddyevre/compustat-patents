/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 26/06/2023
Last Modified: 27/06/2023


This script processes everything on the accounting-side of the data (i.e. Compustat) that is needed for the patent-firm match.

As of the 26th of June 2023, it takes approximately 15 minutes to run in Stata 17 on a computer with 16GB of RAM running an Intel Core i7-1165G7 processor (with 4 CPUs into 8 logical processors and an Intel Iris Xe GPU).

This script is broken down into the following sections:
019a. CRSP/Compustat Dynamic Names - this script obtains all names associated with a gvkey; both the 2020 or time-of-exit name given in Compustat, and previous trading names as listed in the CRSP Daily Stock File.
019b. Listed-Listed M&A - this script identifies M&A activity from crosswalks between firm identifiers in Compustat and another set of firm identifiers; we look into M&A where one identifier remains constant and the other changes.
019c. SDC Platinum M&A - this script identifies M&A activity pertinent to our data from SDC Platinum's vast database on M&A activity.
019d. Mapping gvkeys to Ultimate Owner gvkeys - This script uses the data collected on ownership to map gvkeys to their *ultimate owner* gvkeys.
019e. Intermediary Housekeeping - This script attaches application/grant dates to the homogenised patent data, runs dynamic names through our name-cleaning algorithm, and gets a dataset of clean names that feature in both patent and accounting data.
019f. Mapping Public Firm Names to Ultimate Owner gvkeys - This script maps the names associated with each gvkey to their ultimate owner gvkeys.
019g. Mapping Private Firm Names to Ultimate Owner gvkeys - This script maps the names associated with privately held subsidiaries to their ultimate owner gvkeys.


Infiles:
[019a]
	- CRSPDaily_19262022.dta (The Center for Research in Security Prices Daily Stock file for the period 01/01/1926-31/12/2022, with only trading names, PERMNO, PERMCO, and CUSIP)
	- CRSPcstatLink.dta (The official crosswalk between firm identifiers by The Center for Research in Security Prices and firm identifiers by S&P Global Market Intelligence Compustat, correct as of 31/01/2023)
	- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure)

[019b]
	- permno_gvkey.dta (ABS' crosswalk between their identifier - permno_adj - and gvkeys)

[019c]
	- SDCplatinum8520_MandA.dta (All SDC Platinum data for M&A that become effective during the 1985-2020 period.)

[019d]
	- effectiveAcq_listedListed.csv (A list of listed-acquires-private "effective acquisitions", with gvkey of the acquiring firm, gvkey of the acquired firm, year of acquisition, and type of transaction. Constructed from several sources.)
	- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure)

[019e]
	- patent.dta (PatentsView's largest patent dataset, most pertinently containing the patent's publication number and the publication date.)
	- application.dta (PatentsView's data on patent applications, including application date)
	- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
	- 014_FGLMY2675appYears.dta (USPTO patents from 1926-1975 with their application dates, as inferred from the Fleming, Greene, Li, Marx and Yao (2019) OCR.)
	- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)

[019g]
	- 018d_collatedSubsidiaries.dta (All subsidiaries sourced from ABS 2021, general research, LM 1972, and 10-Ks, with their clean names. At the gvkey-clean_name-ownership_period level)
	- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)


Outfiles:
[019a]
	- 019a_crspName_permno_raw.dta (The *raw* (not cleaned) version of our dataset of CRSP Name -to- permno links, with validity dates)
	- 019a_crspName_permno.dta (The *cleaned* version of our dataset of CRSP Name -to- permno links, with validity dates)
	- 019a_permno_gvkey.dta (A cleaned mapping of CRSP permnos to Compustat gvkeys)
	- 019a_crspName_gvkey.dta (Our mapping of CRSP names to Compustat gvkeys)
	- 019a_cstatPresence.dta (Each gvkey in Compustat with their first and last years present in the dataset)
	- 019a_cstatName_gvkey.dta (A mapping of Compustat names (which are fixed at the gvkey level as the most recent name) to their gvkeys, with listing dates for gvkeys)
	- 019a_dynamicNames.dta (A dynamic mapping of names to gvkeys)

[019b]
	- 019b_ABSlistedListedAuto.csv (An automatically generated file of listed-listed M&A activity as inferred from the ABS crosswalk between their unique firm identifier - permno_adj - and gvkeys)
	- 019b_CRSPcstatListedListedAuto.csv (An automatically generated file of listed-listed M&A activity as inferred from the CRSP/Compustat crosswalk on WRDS between permnos (CRSP) and gvkeys (Compustat))
	- 019b_cstatCUSIPs.dta (A mapping of Compustat gvkeys to their 9- and 6-character CUSIPs, excluding ETFs and similar entities)

[019c]
	- 019c_SDCplatinum8520_MandAtrimmed.dta (SDC Platinum data for complete acquisitions and mergers that become effective during the 1985-2020 period)
	- 019c_SDCplatinumListedListedAuto.csv (An automatically generated file of listed-listed M&A activity as inferred from SDC Platinum data, merged to gvkeys via 6-character CUSIPs)

[019d]
	- 019d_listedListed_EA.dta (A list of listed-listed "effective acquisition" M&A events in terms of gvkeys)
	- 019d_gvkeyYearGvkey_immediate.dta (A list of *immediate* child-parent relationships between gvkeys, at the gvkey-gvkey-year level)
	- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)
	- 019d_whoOwnsWhomAndWhen_gvkeys.dta (A list of child-ultimate_parent relationships between gvkeys, at the gvkey-gvkey level)

[019e]
	- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
	- 019e_dynamicNamesClean.dta (A dynamic mapping of names, as cleaned by the Dyèvre-Seager algorithm, to gvkeys)
	- 019e_dynamicNamesClean_matched.dta (A dynamic mapping of clean names [that also feature in our patent dataset] to gvkeys)

[019f]
	- 019f_cstatPresenceByUltimateOwner.dta (Inclusive *only* of gvkeys associated with clean names that also feature in our patent data, gvkey in Compustat with their first and last years present in the dataset by ultimate owner gvkeys)
	- 019f_whoOwnsWhomAndWhen_nameUOs.dta.dta (A mapping of clean names to ultimate parent gvkeys, with the original names that produced them and the gvkeys they are mapped through, at the clean_name-gvkey level)
	- 019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)

[019g]
	- 019g_subsidiariesCut.dta (A reduced list of subsidiaries created from 018d_collatedSubsidiaries.dta)
	- 019g_subsidiariesCleanedAndCutAgain.dta (A further reduced list of subsidiaries created from 018d_collatedSubsidiaries.dta, with links to immediate-owner gvkeys cleaned)
	- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Called .do Files:
- 019a_dynamicNames.do (The script that gets all names currently or formerly associated with a gvkey)
- 019b_listedListed.do (The script that gets all M&A activity from firm identifier crosswalks)
	- 500_nameCleaning.do (The centralised name cleaning algorithm)
- 019c_SDCplatinum.do (The script that gets all M&A activity pertinent to our data from SDC platinum)
	- 500_nameCleaning.do (The centralised name cleaning algorithm)
- 019d_whoOwnsWhom_gvkeys.do (The script that maps subsidiary gvkeys to their ultimate owner gvkeys)
- 019e_patentsDatesGvkeys.do (An intermediary housekeeping script, adding information to various existing datasets)
	- 500_nameCleaning.do (The centralised name cleaning algorithm)
- 019f_whoOwnsWhom_names.do (The script that maps names associated with public firms to their ultimate owner gvkeys)
- 019g_whoOwnsWhom_subsidiaries.do (The script that maps names associated with private firms to their ultimate owner gvkeys)


External Packages:
- unique by Tony Brady [used in 019b, 019c, 019g]

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

ssc install unique // Used in 019b, 019c, 019g.





********************************************************************************
******************************* RUN THE .do FILES ******************************
********************************************************************************

* 019a - Get Dynamic Names of Listed Firms *

do "$code/019a_dynamicNames.do"


* 019b - Get M&A Activity from Firm Identifier Crosswalks *

do "$code/019b_listedListed.do"


* 019c - Get M&A Activity from SDC Platinum *

do "$code/019c_SDCplatinum.do"


* 019d - Map Subsidiary gvkeys to Ultimate Owner gvkeys *

do "$code/019d_whoOwnsWhom_gvkeys.do"


* 019e - Intermediary Housekeeping *

do "$code/019e_patentsDatesGvkeys.do"


* 019f - Map Names of Listed Firms to Ultimate Owner gvkeys *

do "$code/019f_whoOwnsWhom_names.do"


* 019g - Map Names of Private Firms to Ultimate Owner gvkeys *

do "$code/019g_whoOwnsWhom_subsidiaries.do"





********************************************************************************
********************************** POSTAMBLE ***********************************
********************************************************************************

exit