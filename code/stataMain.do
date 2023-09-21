/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 26/06/2023
Last Modified: 21/09/2023


This script runs all of our Stata code used to create a static and dynamic match between patent data and Compustat gvkeys. It runs a total of 26 .do files, with the name cleaning algorithm 500_nameCleaning.do called on five separate occasions.

As of the 21st of September 2023, it takes approximately 5 hours and 13 minutes to run in Stata 17 on a computer with 16GB of RAM running an Intel Core i7-1165G7 processor (with 4 CPUs into 8 logical processors and an Intel Iris Xe GPU).

This script is broken down into the following sections and subsections:

017. Homogensation of firm names on the patent-side of the data.
	017a. Name Cleaning - we simply run all firm names from both the FGLMY and PatentsView data through our centralised name cleaning algorithm, which can be found under 500_nameCleaning.do.
	017b. FGLMY Re-parsing - we re-parse several of the observations in FGLMY which include a full sentence under the associated firm name.
	017c. FGLMY-to-PatentsView Automated Mapping - we map clean names as they appear in FGLMY to clean names associated with the same patents (from the common 1976-2021 period) in PatentsView.
	017d. Substring Match - following homogenisation of firm names across the FGLMY and PatentsView data, we take all clean names associated with 50 or more patents and find those which are substrings of each other.
	017e. Further Manual Cleaning - following the substring match, we look into the top 250 patenters
	017f. Creating a Full Clean Patent Dataset - following further manual cleaning, we construct a long-form patent dataset with associated original and clean names, in addition to indicator variables concenrning the generation of the clean name.

018. Processing data on privately-held subsidiaries of listed firms that feature in Compustat.
	018a. Restructuring ABS Subsidiary Data - we restructure the subsidiary data from the seminal work of Arora, Belenzon, and Sheer (2021).
	018b. Process Data on M&A Activity from General Research - we process the data collated from general research on M&A activity by firms listed in the U.S. and Canada, in addition to that which is documented by Lev and Mandelker (1972).
	018c. Process WRDS' Collation of Subsidiaries from SEC 10-K Filings - we process data from Wharton Research Data Services (built on original data by Corpwatch) that matches subsidiaries listed in SEC filings to Compustat gvkeys for 1993-2019.
	018d. Collate All Subsidiary Data - we get the ABS subsidiary data, M&A data from general research, and WRDS-SEC subsidiary data into a unified format.
	
019. Processing all names associated with listed firms that feature in Compustat.
	019a. CRSP/Compustat Dynamic Names - this script obtains all names associated with a gvkey; both the 2020 or time-of-exit name given in Compustat, and previous trading names as listed in the CRSP Daily Stock File.
	019b. Listed-Listed M&A - this script identifies M&A activity from crosswalks between firm identifiers in Compustat and another set of firm identifiers; we look into M&A where one identifier remains constant and the other changes.
	019c. SDC Platinum M&A - this script identifies M&A activity pertinent to our data from SDC Platinum's vast database on M&A activity.
	019d. Mapping gvkeys to Ultimate Owner gvkeys - This script uses the data collected on ownership to map gvkeys to their *ultimate owner* gvkeys.
	019e. Intermediary Housekeeping - This script attaches application/grant dates to the homogenised patent data, runs dynamic names through our name-cleaning algorithm, and gets a dataset of clean names featuring in both patent and accounting data.
	019f. Mapping Private Firm Names to Ultimate Owner gvkeys - This script maps the names associated with privately held subsidiaries to their ultimate owner gvkeys.
	019g. Mapping Public Firm Names to Ultimate Owner gvkeys - This script maps the names associated with each gvkey to their ultimate owner gvkeys.
	019h. Collating Mappings of Names to Ultimte Owner gvkeys - This script simply collates all names (of publicly-listed firms and privately held subsidiaries) to their ultimate owner gvkeys

020. Produce the static and dynamic matches.
	020a. Static Match - this script produces the static match of patents to their applicants, as well as an additional static match of patents to their assignees.
	020b. Dynamic Match - this script produces "transfer of ownership" data that facilitates the dynamic reassignment of patents to their assignees.
	020c. Research Friendly Data Production - this script produces patent and dynamic reassignment data that is easy for researchers to use.


Infiles:
	FLEMING, GREENE, LI, MARX, AND YAO (2019)
		- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017) [017a, 017c, 017d, 017e, 017f, 019e]
		
	USPTO PATENTSVIEW
		- patent.dta (PatentsView's largest patent dataset, most pertinently containing the patent's publication number and the publication date.) [017a, 019e]
		- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.) [017a, 017c, 017d, 017e, 017f]
		- assignee.dta (PatentsView's data on assignee information linked to its unique assignee_id) [017a]
		- rawassignee.dta (A detailed link between patents and their associated PatentsView assignee_id, which includes the order in which assignees appear on patents with multiple assignees.) [017c]
		- application.dta (PatentsView's data on patent applications, including application date.) [019e]
		
	DUKE INNOVATION AND SCIENTIFIC ENTERPRISES RESEARCH NETWORK (DISCERN) A.K.A. ARORA, BELENZON, AND SHEER (2021)
		- DISCERN_Panal_Data_1980_2015.dta (The full Compustat-based panel of firms constructed and used by Arora, Belenzon, and Sheer (2018a)) [018a]
		- DISCERN_SUB_name_list.dta (The full list of subsidiaries found by ABS, in their preferred structural format) [018a]
		- permno_gvkey.dta (ABS' crosswalk between their identifier - permno_adj - and gvkeys) [018a, 019b]
		
	WHARTON RESEARCH DATA SERVICES (WRDS)
		- wrds_sec9319.dta (Subsidiaries listed in various Securities and Exchange Commission (SEC) filings as compiled by Wharton Research Data Services (WRDS) for the period 1993-2019. Dataset originally built on top of the Corpwatch API.) [018c]

	CENTER FOR RESEARCH IN SECURITY PRICES (CRSP)
		- CRSPDaily_19262022.dta (The Center for Research in Security Prices Daily Stock file for the period 01/01/1926-31/12/2022, with only trading names, PERMNO, PERMCO, and CUSIP) [019a]
		- CRSPcstatLink.dta (The official crosswalk between firm identifiers by The Center for Research in Security Prices and firm identifiers by S&P Global Market Intelligence Compustat, correct as of 31/01/2023) [019a]

	S&P GLOBAL MARKET INTELLIGENCE COMPUSTAT
		- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure) [019a, 019d, 020c]
		
	REFINITIV SDC PLATINUM
		- SDCplatinum8520_MandA.dta (All SDC Platinum data for M&A that become effective during the 1985-2020 period.) [019c]	

	PYTHON-WRITTEN DATA
		- 014_FGLMY2675appYears.dta (USPTO patents from 1926-1975 with their application dates, as inferred from the Fleming, Greene, Li, Marx and Yao (2019) OCR.) [019e]

	MANUALLY CONSTRUCTED DATA
		- fglmyReparse_mapping_manuallyReviewed.csv (Observations are manually confirmed mappings from an original FGLMY name of the form "ASSIGNORSTOCOMPANYNAME..." to "COMPANYNAME") [017b]
		- resolve_flemToPview_errors.csv (Observations are correct mappings from FGLMY to PatentsView for those FGLMY clean names whose automated mapping to PatentsView is erroneous) [017c]
		- resolve_flemToPview_manualAdditions.csv (Observations are FGLMY-to-PatentsView mappings from top patenters in the FGLMY data who have no automated mapping to PatentsView) [017c]
		- jvManualRemap.csv (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with) [017d]
		- substring_match_manuallyReviewed.csv (Observations are clean_name-to-clean_name mappings from the internal substring match process that are retained following manual review) [017d]
		- lowPat_vacuumNames.csv (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries [with fewer than 50 patents] using the start of the subsidiary's clean name) [017e]
		- subsidiaryManualRemap.csv (Observations are clean_name-to-clean_name mappings from the subsidiaries [with 50 or more patents] of top patenters to the central clean name of said patenter) [017e]
		- effectiveAcq_listedPrivate.csv (A list of listed-acquires-private "effective acquisitions", with gvkey of the acquiring firm, name of the acquired firm, and year of acquisition. Constructed through general research and through reference to Lev and Mandelker (1972)) [018b]
		- effectiveAcq_listedListed.csv (A list of listed-acquires-private "effective acquisitions", with gvkey of the acquiring firm, gvkey of the acquired firm, year of acquisition, and type of transaction. Constructed from several sources.) [019d]
	

Outfiles:
[017]

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
		- 017e_lowPat_vacuumNames.dta (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries [with fewer than 50 patents] using the start of the subsidiaries' clean name)
		- 017e_subsidiaryManualRemap.dta (Observations are clean_name-to-clean_name mappings from the subsidiaries [with 50 or more patenters] of top patenters to the central clean name of said patenter)
		- 017e_lowPat_autoMapping.dta (Observations are clean names with fewer than 50 associated patents that have been automatically remapped to one of the top 250 patenters)
		- 017e_fglmy_names_5.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)
		- 017e_pview_names_5.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)

	[017f]
		- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)

[018]
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

[019]
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
		- 019f_subsidiariesCut.dta (A reduced list of subsidiaries created from 018d_collatedSubsidiaries.dta)
		- 019f_subsidiariesCleanedAndCutAgain.dta (A further reduced list of subsidiaries created from 018d_collatedSubsidiaries.dta, with links to immediate-owner gvkeys cleaned)
		- 019f_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)

	[019g]
		- 019g_dynamicNamesCleanManualAdd_matched.dta (A dynamic mapping of names, as cleaned by the Dyèvre-Seager algorithm, to gvkeys, augmented with high-patent firms erroneously unmatched to publicly-listed firms by the automated procedure)
		- 019g_cstatPresenceByUltimateOwner.dta (Inclusive *only* of gvkeys associated with clean names that also feature in our patent data, gvkey in Compustat with their first and last years present in the dataset by ultimate owner gvkeys)
		- 019g_whoOwnsWhomAndWhen_nameUOs.dta.dta (A mapping of clean names to ultimate parent gvkeys, with the original names that produced them and the gvkeys they are mapped through, at the clean_name-gvkey level)
		- 019g_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
	
	[019h]
		- 019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollated.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
		- 019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollatedSkinny.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner, with original names truncated and without link years between original names and intermediary gvkeys)

[020]
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
- 017_patentHomogenisation.do (The script that produces a 1926-2020 patent database with homogenised firm names)
	- 017a_nameCleaningPatents.do (The script that cleans all original names associated with patents in both FGLMY and PatentsView.)
		- 500_nameCleaning.do (The centralised name cleaning algorithm.)
	- 017b_fglmyReparse.do (The script that addresses some parsing errors in the FGLMY data.)
	- 017c_fglmyToPview_autoMapping.do (The script that homogenises firm names *across* datasets, replacing clean names in FGLMY with automatically matched clean names in PatentsView.)
	- 017d_substringMatchRun.do (The script that takes all clean names and looks for substring matches amongst patenters with 50 or more associated patents.)
	- 017e_furtherManualCleaning.do (The script that takes care of large [manually] and small [automatically] subsidiaries of high-patenting firms, as well as of joint ventures amongst high-patenting firms)
	- 017f_fullData_patentHomogenisation.do (The script that collates all the data following name cleaning, homogenisation, and review)
	
- 018_privateSubsidiaries.do (The script that processes all data regarding privately held subsidiaries of firms appearing in Compustat)
	- 018a_elongateABS.do (The script that restructures subsidiary data provided by Arora, Belenzon, and Sheer (2021).)
	- 018b_MandAprivate.do (The script that processes the data compiled by our own manual research, as well as the M&A activity documented by Lev and Mandelker (1972))
	- 018c_WRDS_SEC.do (The script that processes data on subsidiaries from SEC 10-K filings, as compiled by WRDS on top of the original effort by Corpwatch)
	- 018d_collateSubsidiaries.do (The script that collates the separate data sources from 018a, 018b, and 018c into a unified format)
		- 500_nameCleaning.do (The centralised name cleaning algorithm)
		
- 019_compustatSide.do (The script that processes everything on the accounting side of the data that is required for the patent-firm match)
	- 019a_dynamicNames.do (The script that gets all names currently or formerly associated with a gvkey)
	- 019b_listedListed.do (The script that gets all M&A activity from firm identifier crosswalks)
		- 500_nameCleaning.do (The centralised name cleaning algorithm)
	- 019c_SDCplatinum.do (The script that gets all M&A activity pertinent to our data from SDC platinum)
		- 500_nameCleaning.do (The centralised name cleaning algorithm)
	- 019d_whoOwnsWhom_gvkeys.do (The script that maps subsidiary gvkeys to their ultimate owner gvkeys)
	- 019e_patentsDatesGvkeys (An intermediary housekeeping script, adding information to various existing datasets)
		- 500_nameCleaning.do (The centralised name cleaning algorithm)
	- 019f_whoOwnsWhom_subsidiaries.do (The script that maps names associated with private firms to their ultimate owner gvkeys)
	- 019g_whoOwnsWhom_names.do (The script that maps names associated with public firms to their ultimate owner gvkeys)
	- 019h_nameCollation.do (The script that collates all names (of publicly-listed firms and privately held subsidiaries) to their ultimate owner gvkeys)
	
- 020_staticDynamicMatch.do (The script that produces the project's outputs - the static patent match and transferral-of-ownership data that facilitates dynamic reassignment of patents)
	- 020a_staticMatch.do (The script that produces the static match between patents and gvkeys for the 1950-2020 period)
	- 020b_dynamicReassignment.do (The script that produces the data which facilitates the dynamic reassignment of patents)
	- 020c_researcherFriendlyDataProduction.do (The script that builds on datasets produced in 020a_staticMatch.do and 020b_dynamicReassignment.do to produce researcher-friendly data)


External Packages:
- strdist by Michael Barker and Felix Pöge [used in 017b, 017c]
- jarowinkler by James Feigenbaum [used in 017c]
- unique by Tony Brady [used in 019b, 019c, 019f]

*/

********************************************************************************
*********************************** PREAMBLE ***********************************
********************************************************************************

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





********************************************************************************
****************************** RUN THE .do FILES *******************************
********************************************************************************

* 017 - Patenter Name Homogensation *

do "$code/017_patentHomogenisation.do"


* 018 - Unify Privately-held Subsidiary Data *

do "$code/018_privateSubsidiaries.do"


* 019 - Process Compustat-side of Data *

do "$code/019_compustatSide.do"


* 020 - Produce Static Match and Reassignment Data *

do "$code/020_staticDynamicMatch.do"





********************************************************************************
********************************** POSTAMBLE ***********************************
********************************************************************************

exit