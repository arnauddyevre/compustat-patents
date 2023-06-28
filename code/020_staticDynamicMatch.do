/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 26/06/2023
Last Modified: 26/06/2023


This script takes our patent data with homogenised names constructed in 017 and amended in 019e, and our "clean name ownership" data constructed in 019, and produces a static match of patents to their applicants (and one for their grantees), as well as data to facilitate the dynamic reassignment of patents.

As of the 26th of June 2023, it takes approximately 19 minutes to run in Stata 17 on a computer with 16GB of RAM running an Intel Core i7-1165G7 processor (with 4 CPUs into 8 logical processors and an Intel Iris Xe GPU).

This script is broken down into the following sections:
020a. Static Match - this script produces the static match of patents to their applicants, as well as an additional static match of patents to their assignees.
020b. Dynamic Match - this script produces "transfer of ownership" data that facilitates the dynamic reassignment of patents to their assignees.


Infiles:
[020a]
	- 019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)

	
[020b]
	- 019d_listedListed_EA.dta (A list of listed-listed "effective acquisition" M&A events in terms of gvkeys)
	- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)
	- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Outfiles:
[020a]
	- 020a_whoOwnsWhomAndWhen_ReassignmentFriendlyFinal.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	- 020a_whoPatentsWhat_grantees.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, with various details on the patent and accounting sides of the data, at the patent-gvkey_uo-clean_name level)
	- 020a_whoPatentsWhat_grantees_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, at the patent-gvkey_uo-clean_name level)
	- 020a_whoPatentsWhat_applicants.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, with various details on the patent and accounting sides of the data, at the patent-gvkey_uo-clean_name level)
	- 020a_whoPatentsWhat_applicants_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkey_uo-clean_name level)
	- static.csv (For publication; a mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkey_uo-clean_name level. Identical to 020a_whoPatentsWhat_applicants_skinny.dta.)
	
[020b]
	- 020b_dynamicReassignment_listedListed.dta (A list of listed-listed "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
	- 020b_dynamicReassignment.dta (A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
	- dynamic.csv (For publication; A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs. Identical to 020b_dynamicReassignment.dta.)


Called .do Files:
- 020a_staticMatch.do (The script that produces the static match between patents and gvkeys for the 1950-2020 period)
- 020b_dynamicReassignment.do (The script that produces the data which facilitates the dynamic reassignment of patents)


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