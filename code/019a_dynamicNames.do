/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 09/02/2023
Last Modified: 15/05/2023


We look at firm names on the accounting side here, expanding coverage of Arora, Belenzon, and Sheer (2021)'s "historical name tracking" of Compustat firms using CRSP.


Infiles:
- CRSPDaily_19262022.dta (The Center for Research in Security Prices Daily Stock file for the period 01/01/1926-31/12/2022, with only trading names, PERMNO, PERMCO, and CUSIP)
- CRSPcstatLink.dta (The official crosswalk between firm identifiers by The Center for Research in Security Prices and firm identifiers by S&P Global Market Intelligence Compustat, correct as of 31/01/2023)
- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure)


Outfiles:
- 019a_crspName_permno_raw.dta (The *raw* (not cleaned) version of our dataset of CRSP Name -to- permno links, with validity dates)
- 019a_crspName_permno.dta (The *cleaned* version of our dataset of CRSP Name -to- permno links, with validity dates)
- 019a_permno_gvkey.dta (A cleaned mapping of CRSP permnos to Compustat gvkeys)
- 019a_crspName_gvkey.dta (Our mapping of CRSP names to Compustat gvkeys)
- 019a_cstatPresence.dta (Each gvkey in Compustat with their first and last years present in the dataset)
- 019a_cstatName_gvkey.dta (A mapping of Compustat names (which are fixed at the gvkey level as the most recent name) to their gvkeys, with listing dates for gvkeys)
- 019a_dynamicNames.dta (A dynamic mapping of names to gvkeys)


Called .do Files:
None

External Packages:
None


*/

********************************************************************************
************************* GET DATED NAME-PERMNO LINKS **************************
********************************************************************************

* Import CRSP Daily Stock File *

use "$orig/CRSP/CRSPDaily_19262022.dta", clear


* Drop Extraneous Variables *

// We want PERMCO, COMNAM, and Date

drop PERMCO CUSIP


* Rename Variables *

rename PERMNO permno
rename COMNAM crsp_name


* Label Variables *

label var date "Date on which crsp_name is validly linked to permno"
label var crsp_name "CRSP variable COMNAM: company name"
label var permno "CRSP permanent company identifier"


* Drop if Company Name is Missing * // We can't use information in which a company name is missing

drop if missing(crsp_name)


* Get "Run" For Each Name-permco Link *

// Suppose a ALPHACORP changes its name to ALPHA INDUSTRIES on the 1st of January 1980, and then reverts back to ALPHACORP on the 1st of January 1985. We don't want to link ALPHACORP to this permno (which will be unchanged) for the 1980-1984 period. Indeed, we require that subsequent dates on which a permno has the same trading name are spaced by no more than 365 days in order to include the period between these dates in the link.

bysort permno crsp_name (date): gen pcn_run = 1 if _n == 1

bysort permno crsp_name (date): replace pcn_run = pcn_run[_n-1] + (date > date[_n-1] + 365) if _n > 1

label var pcn_run "Within crsp_name-permno, ID of distinct period when crsp_name-permno link valid"


* Get Min- and Max-dates For Links, Reduce to crsp_name-permno-pcn_run Level *

bysort permno crsp_name pcn_run: egen linkDay1 = min(date)

label var linkDay1 "First day on which permno-crsp_name link is valid"

bysort permno crsp_name pcn_run: egen linkDayN = max(date)

label var linkDayN "Last day on which permno-crsp_name link is valid"

drop date pcn_run // No longer needed

duplicates drop


* Export *

compress

save "$data/019a_crspName_permno_raw.dta", replace





********************************************************************************
************************ CLEAN DATED NAME-PERMNO LINKS *************************
********************************************************************************

* Import Raw Dated Name-permno Links *

use "$data/019a_crspName_permno_raw.dta", clear


* Deal with " NEW" at the end of Company Names: Flag Observations *

// " NEW" at the end of a company name is a common occurence in CRSP, and we look to make sure it's not holding us back here

gen hasNEWname = (strrpos(crsp_name, " NEW") == length(crsp_name) - 3)

label var hasNEWname "crsp_name ends in ' NEW'"


* Deal with " NEW" at the end of Company Names: Swap for Other, Less Abbreviated Name Automatically *

// For example, permno 58413 has names "FEDERAL REALTY INVESTMENT TRUST" (td dates 5638-22645) and "FEDERAL REALTY INVESTMENT TR NEW" (td dates 22648-23009). We replace "FEDERAL REALTY INVESTMENT TR NEW" with "FEDERAL REALTY INVESTMENT TRUST" here, which is distinct from just removing the " NEW" from the end. Each of these permnos has just 2 observations so we do this in an automated fashion.

sort permno hasNEWname

foreach _permno in 10044 10963 12041 13908 15144 18356 58413 78068 81703 89355 90989 92248{
	
	replace crsp_name = crsp_name[_n-1] if hasNEWname == 1 & permno == `_permno'
	
}

drop hasNEWname // No longer needed


* Deal with " NEW" at the end of Company Names: Swap for Other, Less Abbreviated Name Manually *

replace crsp_name = "FIRST FIDELITY BANCORPORATION" if permno == 52505 & crsp_name == "FIRST FIDELITY BANCORP NEW"
replace crsp_name = "D W S STRATEGIC MUNI INCOME TR" if permno == 75465 & crsp_name == "D W S STRATEGIC MUNI INC TR NEW"
replace crsp_name = "GENERAL GROWTH PROPERTIES INC" if permno == 79129  & crsp_name == "GENERAL GROWTH PPTYS INC NEW"
replace crsp_name = "FIRST NIAGARA FINANCIAL GROUP IN" if permno == 85994 & crsp_name == "FIRST NIAGARA FINL GROUP INC NEW"
replace crsp_name = "CROWN CASTLE INTERNATIONAL CORP" if permno == 86339 & crsp_name == "CROWN CASTLE INTL CORP NEW"
replace crsp_name = "CHINA ADVANCED CONST MAT GRP INC" if permno == 93126 & crsp_name == "CHINA ADV CONST MAT GRP INC NEW"


* Deal with " NEW" at the end of Company Names: Drop All Others *

replace crsp_name = substr(crsp_name, 1, length(crsp_name) - 4) if strrpos(crsp_name, " NEW") == length(crsp_name) - 3 & length(crsp_name) > 3


/*
The below lists all examples where " NEW" is at the end of a company name but no identical name (sans the " NEW") exists in the dataset

gen unnewed_name = substr(crsp_name, 1, length(crsp_name) - 4) if strrpos(crsp_name, " NEW") == length(crsp_name) - 3
gen end_obs = missing(unnewed_name)
gen manual_check = 0
sort end_obs
quietly count if end_obs == 0
local loop_end = `=r(N)'
forvalues i = 1/`loop_end'{
	quietly count if crsp_name == unnewed_name[`i']
	quietly replace manual_check = (`=r(N)' == 0) if _n == `i'
}
drop end_obs
bysort permno (linkDay1): egen mc = max(manual_check)
list if mc
*/


* Smooth Out Link Discontinuities - Automated *

// Suppose a ALPHACORP delists on the 1st of January 1980, and then relists on the 1st of January 1985. Here, we will have two distinct links (runs) between ALPHACORP and its permno: one to 31/12/1979 and one from 01/01/1985. *If there isn't a different name in the interval*, we want to merge these into a single link that includes the 1980-1984 period.

bysort permno: gen nr_permno_links = _N

label var nr_permno_links "Number of permno-crsp_name links initially associated with permno"

quietly summ nr_permno_links // Gets maximum number of permno-crsp_name links per permno into `r(max)'

gen smooth_link = 0

label var smooth_link "Flag observation for extending link backwards"

forvalues i = 2/`=r(max)'{ // We iteratively combine links with reference to the *previous* link (in terms of dates) so we start at 2
	
	local loop_switch = 1 // Note that if we drop the first observation within a permno, then the 3rd observation becomes the second. We might need to deal with multiple "second" observations for a given permno, so we run a while loop such that i remains at 2.
	
	while(`loop_switch' == 1){
		
		bysort permno (linkDayN): replace smooth_link = 1 if crsp_name[_n-1] == crsp_name & _n == `i' // Flag the link to be extended backwards
		
		bysort permno (linkDayN): replace linkDay1 = min(linkDay1[_n-1], linkDay1) if smooth_link == 1 // Note that the links are ordered by end date; the "previous" link might start after the ith link, hence the min function.
		
		bysort permno (linkDayN): drop if smooth_link[_n+1] == 1 // Drop the newly redundant link
		
		quietly count if smooth_link == 1 // Gets number of changes taken place into `=r(N)'
		
		if(`=r(N)' == 0){
			
			local loop_switch = 0 // Break out of while loop, proceed to next iterand
			
		}
		
		replace smooth_link = 0 // For another round of consideration within this while loop
		
	}
	
}

drop nr_permno_links smooth_link // No longer needed


* Smooth Out Link Discontinuities - Manual *

// These are all names that last for ~2 weeks. Basically, they'll be listings where a permno briefly has two permcos listed at once

drop if permno == 15472 & crsp_name == "WRIGLEY CORP" & linkDay1 == -11732
drop if permno == 48776 & crsp_name == "LEISURE TECHNOLOGY INC" & linkDay1 == 5862
drop if permno == 77173 & crsp_name == "VTIESSE SEMICONDUCTOR CORP" & linkDay1 == 18445


* Generate a "Multiple Names Concurrently Mapping to permno" Flag *

// On first running, the above code leaves only 5 permcos with multiple names mapping to them at one time. This isn't strictly a problem, but we keep an eye on it as to avoid disruptions.

bysort permno (linkDay1): gen multiMapFlagInd = (linkDay1 <= linkDayN[_n-1] & _n != 1)

label var multiMapFlagInd "Flag for multiple names concurrently mapping to permno, individual obs. level"

bysort permno: egen multiMapFlag = max(multiMapFlagInd)

label var multiMapFlag "Flag for multiple names concurrently mapping to permno, permno level"

drop multiMapFlagInd


* Manually Close Non-trivial Gaps Between Name Mappings to Same Permno *

replace linkDayN = 14522 if permno == 75386 & crsp_name == "BRITISH STEEL PLC" & linkDay1 == 10566 // British steel privatised through this point

replace linkDayN = 16354 if permno == 12972 & crsp_name == "TELE CELULAR SUL PARTIC S A" & linkDay1 == 14201 // Through to the merger of TIM Nordeste and TIM Sul

drop if permno == 91287 & crsp_name == "UNITED SERVICES ADVISORS INC" & linkDay1 == 9245 // Needless 1-day link


* Automatically Close Trivial Gaps Between Name Mappings to Same Permno *

// We close these gaps (usually over a weekend or a weekend and some holidays) by meeting in the middle, yielding the extra day to the latter firm where necessary.

bysort permno (linkDayN): gen gap_post = (linkDay1[_n+1] - 1) - linkDayN if multiMapFlag == 0

label var gap_post "Number of days' gap between map of this and next name's map to permno"

bysort permno (linkDayN): gen gap_ante = (linkDay1 - 1) - linkDayN[_n-1] if multiMapFlag == 0

label var gap_ante "Number of days' gap between map of prev. and this name's map to permno"

replace linkDayN = linkDayN + floor(gap_post/2) if gap_post > 0 & !missing(gap_post)

replace linkDay1 = linkDay1 - ceil(gap_ante/2) if gap_ante > 0 & !missing(gap_ante)

drop gap_post gap_ante


* Format, Compress, Export *

format %td linkDay1 linkDayN

compress

save "$data/019a_crspName_permno.dta", replace





********************************************************************************
************************ CLEAN CRSP-COMPUSTAT CROSSWALK ************************
********************************************************************************

* Import Crosswalk *

use "$orig/CRSP/CRSPcstatLink.dta", clear


* Get Lower-case Variable Names *

quietly ds // Gets variables into `r(varlist)'

foreach var in `r(varlist)'{
	
	quietly rename `var' `=lower("`var'")' // Renames variable with its lowercase equivalent
	
}


* Drop Extraneous Variables * // We rely solely on permno and gvkey

drop linkprim liid linktype lpermco


* Rename and Relabel Variables *

label var gvkey "Compustat company identifier"

rename conm cstat_name

label var cstat_name "Compustat variable conm: company name"

rename lpermno permno

label var permno "CRSP permanent company identifier"

label var linkdt "First day on which permno-gvkey link is valid"

label var linkenddt "Last day on which permno-gvkey link is valid"


* Truncate Link End Dates at January 31st, 2023 *

// If the link end date is missing the link is "continuous", but we deal with the past (not the present) in our project, so we truncate this at January 31st, 2023

replace linkenddt = date("2023-01-31", "YMD") if missing(linkenddt)


* Smooth Out Link Discontinuities - Automated *

// Suppose a ALPHACORP delists on the 1st of January 1980, and then relists on the 1st of January 1985. Here, we will have two distinct links (runs) between ALPHACORP and its permno: one to 31/12/1979 and one from 01/01/1985. If there isn't a different link in the interval, we want to merge these into a single link that includes the 1980-1984 period. This is basically the same code that we ran earlier on name links in CRSP.

bysort permno: gen nr_permno_links = _N

label var nr_permno_links "Number of permno-gvkey links initially associated with permno"

quietly summ nr_permno_links // Gets maximum number of permno-crsp_name links per permno into `r(max)'

gen smooth_link = 0 

label var smooth_link "Flag observation for extending link backwards"

forvalues i = 2/`=r(max)'{ // We iteratively combine links with reference to the *previous* link (in terms of dates) so 
	
	local loop_switch = 1 // Note that if we drop the first observation within a permno, then the 3rd observation becomes the second. We might need to deal with multiple "second" observations for a given permno.
	
	while(`loop_switch' == 1){
		
		bysort permno (linkenddt): replace smooth_link = 1 if gvkey[_n-1] == gvkey & _n == `i' // Flag the link to be extended backwards
		
		bysort permno (linkenddt): replace linkdt = min(linkdt[_n-1], linkdt) if smooth_link == 1 // Note that the links are ordered by end date; the "previous" link might start after the ith link, hence the min function.
		
		bysort permno (linkenddt): drop if smooth_link[_n+1] == 1 // Drop the newly redundant link
		
		quietly count if smooth_link == 1 // Gets number of changes taken place into `=r(N)'
		
		if(`=r(N)' == 0){
			
			local loop_switch = 0 // Break out of while loop, proceed to next iterand
			
		}
		
		replace smooth_link = 0 // For another round of consideration within this while loop
		
	}
	
}

drop nr_permno_links smooth_link // No longer needed


* Export *

order permno gvkey linkdt linkenddt cstat_name

compress

save "$data/019a_permno_gvkey.dta", replace





********************************************************************************
************** COMBINE CRSP_NAME-PERMNO AND PERMNO-GVKEY MAPPING ***************
********************************************************************************

* Import permno-gvkey Mapping *

use "$data/019a_permno_gvkey.dta", clear


* Joinby to crsp_name-permno Mapping *

joinby permno using "$data/019a_crspName_permno.dta", unmatched(both)
/*

                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
           only in using data |     10,589       20.74       20.74 -- 21% of permnos in the CRSP name do not match; these are permnos that do not match any firm in Compustat, mostly investment vehicles from what I can see.
both in master and using data |     40,477       79.26      100.00 -- All master observations merge
------------------------------+-----------------------------------
                        Total |     51,066      100.00
*/
drop if _merge == 2 // Not useful

drop _merge // No longer informative


* Drop Extemporaneous Observations *

drop if linkDay1 > linkenddt | linkDayN < linkdt // If the name mapping doesn't match, we don't keep it


* Get Boundaries of crsp_name-gvkey Link *

gen dynName_linkDay1 = max(linkdt, linkDay1)

label var dynName_linkDay1 "First day on which crsp_name-gvkey link is valid"

gen dynName_linkDayN = min(linkenddt, linkDayN)

label var dynName_linkDayN "Last day on which crsp_name-gvkey link is valid"


* Drop Extraneous Variables *

drop permno linkdt linkenddt linkDay1 linkDayN multiMapFlag


* Get Maximally Wide Date Boundaries for Duplicate mappings *

// Suppose the name "ALPHA CONSTRUCTION SERVICES" maps to gkvey 12345 for 01/01/2000-31/12/2000 and then again for 01/01/2002-31/12/2002. We change this to a single mapping from 01/01/2000-31/12/2002

bysort gvkey crsp_name: egen PHdynName_linkDay1 = min(dynName_linkDay1)

label var PHdynName_linkDay1 "Placeholder for the chosen dynName_linkDay1 for a given crsp_name-gvkey"

bysort gvkey crsp_name: egen PHdynName_linkDayN = min(dynName_linkDayN)

label var PHdynName_linkDayN "Placeholder for the chosen dynName_linkDayN for a given crsp_name-gvkey"

replace dynName_linkDay1 = PHdynName_linkDay1

replace dynName_linkDayN = PHdynName_linkDayN

drop PHdynName_linkDay1 PHdynName_linkDayN // No longer needed


* Drop Duplicates *

duplicates drop

/*
* Code to Flag Overlaps *

gen overlap = 0
bysort crsp_name (dynName_linkDay1 dynName_linkDayN): replace overlap = 1 if _n > 1 & dynName_linkDayN[_n-1] >= dynName_linkDay1 // Link before (by link start date) overlaps
bysort crsp_name (dynName_linkDayN dynName_linkDay1): replace overlap = 1 if _n > 1 & dynName_linkDayN[_n-1] >= dynName_linkDay1 // Link before (by link end date) overlaps
bysort crsp_name (dynName_linkDay1 dynName_linkDayN): replace overlap = 1 if _n < _N & dynName_linkDay1[_n+1] <= dynName_linkDayN // Link after (by link start date) overlaps
bysort crsp_name (dynName_linkDayN dynName_linkDay1): replace overlap = 1 if _n < _N & dynName_linkDay1[_n+1] <= dynName_linkDayN // Link after (by link end date) overlaps
label var overlap "crsp_name maps concurrently to multiple gvkeys"
*/


* Manual Overlap Fixing *

drop if gvkey == "134845" & crsp_name == "A T & T CORP" // Short-lived AT&T subsidiary listing
drop if gvkey == "032280" & crsp_name == "A T & T CORP" // Short-lived AT&T subsidiary listing
drop if gvkey == "140796" & crsp_name == "ALCATEL" // Short-lived Alcatel subsidiary listing
drop if gvkey == "143461" & crsp_name == "CABLEVISION SYSTEMS CORP" // Short-lived cablevision subsidiary listing
drop if gvkey == "064410" & crsp_name == "CIRCUIT CITY STORES INC" // Unclear why this maps to Carmax for 5 years
drop if gvkey == "126814" & crsp_name == "DISNEY WALT CO"  // Short-lived .com boom Disney subsidiary listing
drop if gvkey == "121293" & crsp_name == "DONALDSON LUFKIN & JEN INC" // Short-lived DLJ subsidiary, wound down by Credit Suisse through takeover
drop if gvkey == "020960" & crsp_name == "FIDELITY NATIONAL FINL INC" // Short-lived subsidiary eventually sold
drop if gvkey == "018040" & crsp_name == "FIRST REPUBLIC BANCORP INC"
drop if gvkey == "018375" & crsp_name == "FLETCHER CHALLENGE LTD" // Corporate split
drop if gvkey == "005074" & crsp_name == "GENERAL MOTORS CORP" // Subsidiary
drop if gvkey == "012206" & crsp_name == "GENERAL MOTORS CORP" // Subsidiary
drop if gvkey == "121742" & crsp_name == "GENZYME CORP" // Short-lived subsidiary
drop if gvkey == "066013" & crsp_name == "GEORGIA PACIFIC CORP" // Spin-off
drop if gvkey == "024724" & crsp_name == "LIBERTY GLOBAL PLC" // Liberty Global's coroporate structure is a nightmare
drop if gvkey == "013664" & crsp_name == "LIBERTY INTERACTIVE CORP"
drop if gvkey == "179562" & crsp_name == "LIBERTY MEDIA CORP"
drop if gvkey == "183812" & crsp_name == "LIBERTY MEDIA CORP"
drop if gvkey == "147175" & crsp_name == "LOEWS CORP" // Susbsidiary
drop if gvkey == "124015" & crsp_name == "QUANTUM CORP"
drop if gvkey == "126836" & crsp_name == "SNYDER COMMUNICATIONS INC" // Short-lived subsidiary
drop if gvkey == "011670" & crsp_name == "SPECTRUM BRANDS HOLDINGS INC"
drop if gvkey == "116245" & crsp_name == "SPRINT CORP"
drop if gvkey == "032280" & crsp_name == "TELE COMMUNICATIONS INC" // Half-listed subsidiaries
drop if gvkey == "065683" & crsp_name == "TELE COMMUNICATIONS INC"
drop if gvkey == "061464" & crsp_name == "U S WEST INC"
drop if gvkey == "186355" & crsp_name == "TEUCRIUM COMMODITY TRUST"
drop if gvkey == "186546" & crsp_name == "TEUCRIUM COMMODITY TRUST"

drop if crsp_name == "LIBERTY MEDIA CORP 2ND" | crsp_name == "LIBERTY MEDIA CORP 3RD" // Not a useful name
drop if crsp_name == "MORGAN STANLEY TRUSTS" // Too complicated, and unlikely to patent

replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "116004" & crsp_name == "ALLIED CAPITAL CORP"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "001820" & crsp_name == "ASTRO MEDICAL INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "019574" & crsp_name == "GANNETT CO INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "015037" & crsp_name == "GOLDCORP INC" 
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "009340" & crsp_name == "I C N PHARMACEUTICALS INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "024184" & crsp_name == "LABONE INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "009549" & crsp_name == "OCEAN ENERGY INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "005968" & crsp_name == "RYERSON TULL INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "007824" & crsp_name == "SIERRA PACIFIC RESOURCES"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "066278" & crsp_name == "SPORTS AUTHORITY INC"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "008007" & crsp_name == "WELLS FARGO & CO"
replace dynName_linkDay1 = dynName_linkDay1 + 1 if gvkey == "114956" & crsp_name == "XENITH BANKSHARES INC"

replace dynName_linkDay1 = dynName_linkDay1 + 2 if gvkey == "063687" & crsp_name == "CENTRUE FINANCIAL CORP"
replace dynName_linkDay1 = dynName_linkDay1 + 2 if gvkey == "062655" & crsp_name == "DEAN FOODS CO"
replace dynName_linkDay1 = dynName_linkDay1 + 2 if gvkey == "003277" & crsp_name == "GROUP 1 SOFTWARE INC"
replace dynName_linkDay1 = dynName_linkDay1 + 2 if gvkey == "016469" & crsp_name == "MEDICAL MANAGER CORP"
replace dynName_linkDay1 = dynName_linkDay1 + 2 if gvkey == "015210" & crsp_name == "VIRTUS TOTAL RETURN FUND INC"

replace dynName_linkDay1 = 12478 if gvkey == "027982" & crsp_name == "FIRST FEDERAL SAVINGS BANK GA" // Reverse spin-off
replace dynName_linkDayN = 13829  if gvkey == "018040" & crsp_name == "EXECUFIRST BANCORP INC"


* Relabel for Clarity, Order *

label var cstat_name "Compustat variable conm (company name) associated with gvkey"

order gvkey crsp_name dynName_linkDay1 dynName_linkDayN cstat_name


* Format, Compress, Export *

format %td dynName_linkDay1 dynName_linkDayN

compress

save "$data/019a_crspName_gvkey.dta", replace





********************************************************************************
********************* GET 1:1 COMPUSTAT_NAME-GVKEY MAPPING *********************
********************************************************************************

* Import Compustat *

use "$orig/Compustat/cstat_1950_2022.dta", clear


* Drop Extraneous Variables *

keep gvkey conm datadate fyear


* Order, Rename, Relabel Variables *

order gvkey conm fyear datadate

label var gvkey "Compustat company identifier"

rename conm cstat_name

label var cstat_name "Compustat variable conm (company name) associated with gvkey"

label var fyear "Fiscal year"

rename datadate datadate_end

label var datadate_end "Last calendar day of fiscal year"


* Extract Start and End Dates of Listing (Fiscal) *

bysort gvkey (fyear): egen fyear1 = min(fyear)

label var fyear1 "First fiscal year for which gvkey is listed"

bysort gvkey (fyear): egen fyearN = max(fyear)

label var fyearN "Last fiscal year for which gvkey is listed"


* Get Start Date of Fiscal Year *

gen datadate_start = datadate_end - 364 - ((mod(yofd(datadate_end), 4) == 0 & datadate_end - dofy(yofd(datadate_end)) + 1 > 59) | (mod(yofd(datadate_end), 4) == 1 & datadate_end - dofy(yofd(datadate_end)) + 1 < 59)) // Leap years demand special temporal accounting

label var datadate_start "First calendar day of fiscal year"


* Extract Start and End Dates of Listing (Calendar) *

bysort gvkey (datadate_start): egen caldate1 = min(datadate_start)

label var caldate1 "First calendar day of first fiscal year for which gvkey is listed"

bysort gvkey (datadate_end): egen caldateN = max(datadate_end)

label var caldateN "Last calendar day of last fiscal year for which gvkey is listed"


* Export Dataset of Years Each gvkey Is Present *

** Preserve **

preserve


	** Get First Present Year (Calendar or Fiscal) for Each gvkey **
	
	bysort gvkey: gen yPresent1 = min(yofd(caldate1), fyear1)
	
	label var yPresent1 "First year (calendar or fiscal) that gvkey is present in Compustat"
	
	replace yPresent1 = 1950 if yPresent1 == 1949


	** Get Last Present Year (Calendar or Fiscal) for Each gvkey **
	
	bysort gvkey: gen yPresentN = max(yofd(caldateN), fyearN)
	
	label var yPresentN "Last year (calendar or fiscal) that gvkey is present in Compustat"

	
	** Reduce to gvkey Level **
	
	keep gvkey yPresent1 yPresentN
	
	duplicates drop
	
	
	** Drop if First Year After 2020 **
	
	drop if yPresent1 > 2020
	
	
	** Censor End of Data at 2020 **
	
	replace yPresentN = 2020 if yPresentN > 2020
	
	
	** Export **
	
	compress
	
	save "$data/019a_cstatPresence.dta", replace
	
	
** Restore **

restore


* Reduce from gvkey-fyear Level to gvkey Level *

drop fyear datadate_end datadate_start

duplicates drop


* Format, Compress, Export *

format %td caldate1 caldateN

compress

save "$data/019a_cstatName_gvkey.dta", replace





********************************************************************************
************************** GET DYNAMIC NAMES DATABASE **************************
********************************************************************************

* Import Compustat Name -to- gvkey Mapping *

use "$data/019a_cstatName_gvkey.dta", clear


* Get "Wide Boundary" for Listing *

// To deal with extemporaneous name mappings from CRSP to gvkeys, we create a "wide" boundary - from min{first day of fyear1, caldate1} to max{last day of fyearN, caldateN}

gen wb_date1 = min(dofy(fyear1), caldate1)

label var wb_date1 "Minimum of first calendar day of gvkey's first fyear and gvkey's first data day"

gen wb_dateN = max(dofy(fyearN + 1) - 1, caldateN)

label var wb_dateN "Minimum of last calendar day of gvkey's last fyear and gvkey's last data day"


* Merge CRSP Name -to- gvkey Mapping *

merge 1:m gvkey cstat_name using "$data/019a_crspName_gvkey.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        15,542
        from master                    14,992  (_merge==1)  -  Some firms in Compustat don't appear in CRSP
        from using                        550  (_merge==2)  -  These are mappings that occur for firms that list *after* our last download from Compustat

    Matched                            37,257  (_merge==3)
*/
drop if _merge == 2 // Information valid for 2021- onwards, which we don't consider

drop _merge // No longer needed - can be inferred


* Move to Missing Extemporaneous CRSP Name Mappings * // These are mappings in CRSP that don't apply to any of the time that the firm is listed in Compustat

gen crsp_extemporaneous = 0 if !missing(crsp_name)

replace crsp_extemporaneous = 1 if !missing(crsp_name) & ((dynName_linkDay1 > wb_dateN & !missing(dynName_linkDay1)) | (dynName_linkDayN < wb_date1 & !missing(dynName_linkDayN)))

label var crsp_extemporaneous "Indicator, CRSP name mapping is extemporaneous to period gvkey is in Compustat"

replace crsp_name = "" if crsp_extemporaneous == 1 // We don't drop the observation, as this would also drop the Compustat name associated with the listing.

replace dynName_linkDay1 = . if crsp_extemporaneous == 1

replace dynName_linkDayN = . if crsp_extemporaneous == 1

drop crsp_extemporaneous // No longer needed


* Drop Extraneous Observations *

// These are generated from removing additional CRSP names

bysort gvkey (crsp_name): gen extra = (_n < _N & missing(crsp_name)) // If all CRSP names are missing, we want to retain at least one observation to keep the Compustat name

label var extra "Observation carries no additional information"

drop if extra == 1

drop extra


* Drop Name Changes post-2020 not Registered in Our Version of Compustat *

drop if gvkey == "038929" & crsp_name == "ATRENEW INC" 
drop if gvkey == "152909" & crsp_name == "ALLSPRING INC OPP FUND" 
drop if gvkey == "154609" & crsp_name == "ALLSPRING MULTI-SECTOR INC FD" 
drop if gvkey == "177052" & crsp_name == "ALLSPRING GLOBAL DIV OPP FUND" 
drop if gvkey == "292284" & crsp_name == "SCISPARC LTD" 


/*
Code for reviewing post-2020 name changes that we should discard
bysort gvkey (dynName_linkDay1): gen nr_obs = _N
bysort gvkey (dynName_linkDay1): gen obs_nr = _n
count if nr_obs > 1 & dynName_linkDay1 > date("31-12-2020","DMY") & cstat_name != crsp_name
format %td wb*
bysort gvkey (dynName_linkDay1): gen last_crsp_name = crsp_name[_N]
list gvkey cstat_name fyear1 fyearN caldate1 caldateN wb_date1 wb_dateN crsp_name dynName_linkDay1 dynName_linkDayN if nr_obs > 1 & dynName_linkDay1 > date("31-12-2020","DMY") & cstat_name != last_crsp_name, noobs
*/


* Define Name-link Boundaries for Compustat Name *

// Even if they're not identical, we let the name given in Compustat run (1) for back to the previous CRSP name's end if there's at least two CRSP names mapping to the gvkey or (2) if there is no more than one CRSP name mapping to the gvkey, for as long as the gvkey is in Compustat

bysort gvkey (dynName_linkDayN): gen cstatName_linkDay1 = dynName_linkDayN[_N-1] + 1 if !missing(crsp_name[_n-1]) & _n == _N // We use the penultimate CRSP-name link observation for reference, and initially only generate it here

bysort gvkey (dynName_linkDayN): replace cstatName_linkDay1 = wb_date1 if missing(crsp_name[_n-1]) & _n == _N

bysort gvkey (cstatName_linkDay1): replace cstatName_linkDay1 = cstatName_linkDay1[1] // We then fill out all observations within the gvkey with the given value

label var cstatName_linkDay1 "First day on which cstat_name-gvkey link is valid"

bysort gvkey (dynName_linkDayN): gen cstatName_linkDayN	= max(dynName_linkDayN[_N], wb_dateN) if !missing(crsp_name[_n-1]) & _n == _N

bysort gvkey (dynName_linkDayN): replace cstatName_linkDayN = wb_dateN if missing(crsp_name[_n-1]) & _n == _N

bysort gvkey (cstatName_linkDayN): replace cstatName_linkDayN = cstatName_linkDayN[1]

label var cstatName_linkDayN "Last day on which cstat_name-gvkey link is valid"


* Re-define Name-link Boundaries for gvkeys with Two CRSP Names Contemporaneously Mapping to Them * // The two contemporaneous CRSP Names mapping to a gvkey (which happens in a few instances) messes things up a little, since observations are at the crsp_name-gvkey level

duplicates drop // For where multiple CRSP names have been moved to missing

replace cstatName_linkDay1 = 8401 if gvkey == "013061"
replace cstatName_linkDay1 = 12784 if gvkey == "064387"
replace cstatName_linkDay1 = 16764 if gvkey == "212340"
replace cstatName_linkDay1 = 761 if gvkey == "009920"
replace cstatName_linkDay1 = -3652 if gvkey == "010846"

replace cstatName_linkDay1 = 21510 if gvkey == "013312"
replace cstatName_linkDay1 = 12532 if gvkey == "013498"
replace cstatName_linkDay1 = 8766 if gvkey == "028883"
replace cstatName_linkDay1 = 12054 if gvkey == "030331"
replace cstatName_linkDay1 = 18993 if gvkey == "271357"

replace cstatName_linkDay1 = 12744 if gvkey == "031041"
replace cstatName_linkDay1 = 14610 if gvkey == "144496"
replace cstatName_linkDay1 = 14610 if gvkey == "221261"
replace cstatName_linkDay1 = 14191 if gvkey == "116806"
replace cstatName_linkDay1 = 22615 if gvkey == "031477"

replace cstatName_linkDay1 = 9496 if gvkey == "007276"
replace cstatName_linkDay1 = 4018 if gvkey == "005985"


/*
Code for reviewing overlaps...
gen overlap = 0
bysort gvkey (dynName_linkDay1 dynName_linkDayN): replace overlap = 1 if _n > 1 & dynName_linkDayN[_n-1] >= dynName_linkDay1 // Link before (by link start date) overlaps
bysort gvkey (dynName_linkDayN dynName_linkDay1): replace overlap = 1 if _n > 1 & dynName_linkDayN[_n-1] >= dynName_linkDay1 // Link before (by link end date) overlaps
bysort gvkey (dynName_linkDay1 dynName_linkDayN): replace overlap = 1 if _n < _N & dynName_linkDay1[_n+1] <= dynName_linkDayN // Link after (by link start date) overlaps
bysort gvkey (dynName_linkDayN dynName_linkDay1): replace overlap = 1 if _n < _N & dynName_linkDay1[_n+1] <= dynName_linkDayN // Link after (by link end date) overlaps
bysort gvkey: egen max_overlap = max(overlap)
list if max_overlap, noobs
*/

* Truncate Name Link Validity Dates Within Wide Compustat Boundaries *

replace dynName_linkDayN = wb_dateN if dynName_linkDayN > wb_dateN & !missing(dynName_linkDayN)

replace cstatName_linkDayN = wb_dateN if cstatName_linkDayN > wb_dateN

replace dynName_linkDay1 = wb_date1 if dynName_linkDay1 < wb_date1 & !missing(dynName_linkDay1)

replace cstatName_linkDay1 = wb_date1 if cstatName_linkDay1 < wb_date1 // This one shouldn't make any changes


* Reshape to Give gvkey-gvkey_dates-name-name_dates-name_source Observations *

drop fyear1 fyearN caldate1 caldateN // No longer needed

order gvkey wb_date1 wb_dateN cstat_name cstatName_linkDay1 cstatName_linkDayN crsp_name dynName_linkDay1 dynName_linkDayN // Makes it a little easier to see which dates are associated with what

format %td wb_date1 wb_dateN cstatName_linkDay1 cstatName_linkDayN // For expositional clarity

rename cstat_name name1
rename cstatName_linkDay1 name_linkDay11
rename cstatName_linkDayN name_linkDayN1

rename crsp_name name2
rename dynName_linkDay1 name_linkDay12
rename dynName_linkDayN name_linkDayN2

gen false_i = _n // To facilitate the reshape, which will generate duplicates (since cstat_name, cstatName_linkDay1, cstatName_linkDayN are fixed within gvkey)

label var false_i "Reshape long facilitation variable"

reshape long name name_linkDay1 name_linkDayN, i(false_i)

drop false_i // Has no meaning

gen name_source = "Compustat" if _j == 1

replace name_source = "CRSP" if _j == 2

label var name_source "Source of name"
label var name "Company name"
label var name_linkDay1 "First day on which company name validly links to gvkey"
label var name_linkDayN "Last day on which company name validly links to gvkey"

drop _j // No longer needed

drop if missing(name) // For _j == 2 where the gvkey is not mapped to by any CRSP names

duplicates drop // Generated by the false reshape (see above)


* Drop Redundant CRSP Names Already Captured by Compustat *

// gvkey-name pairs have at most 2 observations - one from CRSP and one from Compustat. 

bysort gvkey name (name_source): gen drop_flag = (_n == 1 & _N == 2 & name_linkDay1 >= name_linkDay1[_n+1] & name_linkDayN <= name_linkDayN[_n+1]) // Note that sorting by name_source puts CRSP observation first

drop if drop_flag == 1

drop drop_flag // No longer needed


* Merge CRSP-sourced and Compustat-sourced Mappings where the Latter Succeeds the Former and both are in the Same gvkey-name Pair *

bysort gvkey name (name_source): gen merge_flag = (_n == 2 & name_linkDayN[_n-1] + 1 <= name_linkDay1) // Flag the observation to be extended backwards

bysort gvkey name (name_source): replace name_linkDay1 = name_linkDay1[_n-1] if merge_flag == 1 // Extend the Compustat observation backwards

bysort gvkey name (name_source): drop if merge_flag[_n+1] == 1 // Drop the CRSP observation

drop merge_flag // No longer needed


* Export *

sort gvkey name_linkDay1 name_linkDayN name

compress

save "$data/019a_dynamicNames.dta", replace