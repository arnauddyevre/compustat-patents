/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 20/05/2023
Last Modified: 21/05/2023


The purpose of this script is to process the subsidiaries listed in various Securities and Exchange Commission (SEC) filings as compiled by Wharton Research Data Services (WRDS) for the period 1993-2019.


Infiles:
- wrds_sec9319.dta (Subsidiaries listed in various Securities and Exchange Commission (SEC) filings as compiled by Wharton Research Data Services (WRDS) for the period 1993-2019. Dataset originally built on top of the Corpwatch API.)


Outfiles:
- 018c_wrdsSEC_subsName_gvkey.dta (At the gvkey-Subsidiary level, mappings of subsidiaries (by name) to gvkeys from SEC filings, Oct1992-Jul2019. Derived from the compilation of such filings by WRDS, itself built on the CorpWatch API.)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
************************ PROCESS ORIGINAL WRDS DATASET *************************
********************************************************************************

* Import Original Data *

use "$orig/WRDS x SEC/wrds_sec9319.dta", clear


* Drop Extraneous Variables, Duplicates Created Thereby *

keep gvkey rdate subsidiary_name type // Note here especially that we don't keep WRDS' cleaned company name. We stick to our own algorithm.

compress // String variables all unnecessarily long, numbers all long instead of int

duplicates drop


* Drop Observations without gvkeys *

drop if missing(gvkey) // Obviously we can't match to a gvkey if there is no gvkey


* Retain Only 10-K Reports *

keep if type == "10-K" // There are sooooooooooooooooo many subsidiary names and we have to cut stuff down somehow. Also 10-Ks are good because (1) they are never misssing "end-of-report" dates and (2) we understand fully their periodicity

drop type // No longer needed


* Get Date Variables *

rename rdate reportEnd

label var reportEnd "Last date to which report pertains"

gen reportStart = reportEnd - 364 - ((mod(yofd(reportEnd), 4) == 0 & reportEnd - dofy(yofd(reportEnd)) + 1 > 59) | (mod(yofd(reportEnd), 4) == 1 & reportEnd - dofy(yofd(reportEnd)) + 1 < 59))

label var reportStart "First date to which report pertains"

format %td reportStart reportEnd


* Rename, Label, Format Variables *

label var gvkey "Ultimate owner of subsidiary"

rename subsidiary_name subs_name

label var subs_name "Name of subsidiary"


* Get Ownership Runs *

bysort gvkey subs_name (reportStart): gen ownershipRun = 1 if _n == 1

bysort gvkey subs_name (reportStart): replace ownershipRun = ownershipRun[_n-1] + (yofd(reportStart) > yofd(reportEnd[_n-1]) + 3) if _n > 1 // We restart of a new run if there's 3 full years in which no ownership of the subsidiary is claimed

label var ownershipRun "Identifier of distinct period of ownership of subsidiary by gvkey"


* Get Dates of Confirmed Ownership *

bysort gvkey subs_name ownershipRun (reportStart): gen year1 = yofd(reportStart[1])

label var year1 "Year in which gvkey's ownership of subsidiary commences"

bysort gvkey subs_name ownershipRun (reportStart): gen yearN = yofd(reportEnd[_N])

label var yearN "Year in which gvkey's ownership of subsidiary concludes"


* Flag Source of Data *

gen name_source = "SEC-WRDS 10-K"

label var name_source "Source of name"


* Reduce to gvkey-Subsidiary Level *

drop reportEnd reportStart ownershipRun

duplicates drop


* Smooth Over Gaps in Ownership *

// Suppose ALPHACORP lists BETATECH as a subsidiary for 1993-1998, and then again in 2003-2018. In the intermediary, no other firm claims ownership of BETATECH. We want to smooth this gap such that ALPHACORP owns BETATECH for the whole 1993-2018 period.

bysort subs_name: gen nr_links = _N

label var nr_links "Number of links from the subsidiary name to a gvkey for a period"

quietly summ nr_links // Gets the maximal number of links from a subs_name into `=r(max)'

gen smooth_link = 0

label var smooth_link "Flag observation for extending link backwards"

forvalues i = 2/`=r(max)'{
	
	local loop_switch = 1 // Note that if we drop the first gvkey within a subs_name, then the 3rd observation becomes the second. We might need to deal with multiple "second" observations for a given subs_name, so we run a while loop such that i remains at 2.
	
	while(`loop_switch' == 1){
		
		bysort subs_name (year1 gvkey): replace smooth_link = 1 if gvkey == gvkey[_n-1] & _n == `i' // Flag links to extend backwards
		
		bysort subs_name (year1 gvkey): replace year1 = year1[_n-1] if smooth_link == 1 // Smooth out link
		
		bysort subs_name (year1 gvkey): drop if smooth_link[_n+1] == 1 // Drop newly redundant link
		
		quietly count if smooth_link == 1 // Gets the number of changes into `=r(N)'
		
		if(`=r(N)' == 0){
			
			local loop_switch = 0
			
		}
		
		replace smooth_link = 0 // For the next round of consideration
		
	}
	
}

drop nr_links smooth_link // No longer needed


* Export *

compress

save "$data/018c_wrdsSEC_subsName_gvkey.dta", replace