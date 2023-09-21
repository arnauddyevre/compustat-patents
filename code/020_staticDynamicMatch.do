/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 26/06/2023
Last Modified: 21/09/2023


This script takes our patent data with homogenised names constructed in 017 and amended in 019e, and our "clean name ownership" data constructed in 019, and produces a static match of patents to their applicants (and one for their grantees), as well as data to facilitate the dynamic reassignment of patents.

As of the 21st of September 2023, it takes approximately 16 minutes to run in Stata 17 on a computer with 16GB of RAM running an Intel Core i7-1165G7 processor (with 4 CPUs into 8 logical processors and an Intel Iris Xe GPU).

This script is broken down into the following sections:
020a. Static Match - this script produces the static match of patents to their applicants, as well as an additional static match of patents to their assignees.
020b. Dynamic Match - this script produces "transfer of ownership" data that facilitates the dynamic reassignment of patents to their assignees.
020c. Research Friendly Data Production - this script produces patent and dynamic reassignment data that is easy for researchers to use.


Infiles:
[020a]
	- 019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)

	
[020b]
	- 019d_listedListed_EA.dta (A list of listed-listed "effective acquisition" M&A events in terms of gvkeys)
	- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)
	- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	

[020c]
	- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure)
	- 019a_cstatPresence.dta (Each gvkey in Compustat with their first and last years present in the dataset)


Outfiles:
[020a]
	- 020a_whoOwnsWhomAndWhen_ReassignmentFriendlyFinal.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	- 020a_whoPatentsWhat_grantees.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, with various details on the patent and accounting sides of the data, at the patent-gvkey_uo-clean_name level)
	- 020a_whoPatentsWhat_grantees_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, at the patent-gvkey_uo-clean_name level)
	- 020a_whoPatentsWhat_applicants.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, with various details on the patent and accounting sides of the data, at the patent-gvkey_uo-clean_name level)
	- 020a_whoPatentsWhat_applicants_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkey_uo-clean_name level)
	
[020b]
	- 020b_dynamicReassignment_listedListed.dta (A list of listed-listed "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
	- 020b_dynamicReassignment.dta (A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
	

[020c]
	- 020c_allGvkeyFyears.dta (A list of all gvkey-fyears that feature in Compustat for 1950-2020)
	- 020c_patentsResearcherFriendly.dta (All patents in our database that are attributable to a gvkey either at the time of patenting (3,184,278 patents) and/or for later attribution to a gvkey's patenting history (additional 458,337 patents))
	- static.csv (For publication; All patents in our database that are attributable to a gvkey either at the time of patenting (3,184,278 patents) and/or for later attribution to a gvkey's patenting history (additional 458,337 patents). Identical to 020c_patentsResearcherFriendly.dta.)
	- 020c_gvkeyFR_to_gvkey.dta (Maps all gvkeyFRs present in our data to Compustat gvkeys)
	- dynamic.csv (For publication; maps all gvkeyFRs present in our data to Compustat gvkeys. Identical to 020c_gvkeyFR_to_gvkey.dta.)


Called .do Files:
- 020a_staticMatch.do (The script that produces the static match between patents and gvkeys for the 1950-2020 period)
- 020b_dynamicReassignment.do (The script that produces the data which facilitates the dynamic reassignment of patents)
- 020c_researcherFriendlyDataProduction.do (The script that builds on datasets produced in 020a_staticMatch.do and 020b_dynamicReassignment.do to produce researcher-friendly data)


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

* 020a - Static Match *

do "$code/020a_staticMatch.do"


* 020b - Dynamic Match *

do "$code/020b_dynamicReassignment.do"


* 020c - Produce Researcher Friendly Data *

do "$code/020c_researcherFriendlyDataProduction.do"