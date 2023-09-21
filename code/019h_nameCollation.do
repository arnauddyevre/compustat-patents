/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 07/07/2023
Last Modified: 13/07/2023


The purpose of this script is simply to collate ultimate ownership of names.
	

Infiles:
- 019g_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
- 019f_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Outfiles:
- 019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollated.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
- 019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollatedSkinny.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner, with original names truncated and without link years between original names and intermediary gvkeys)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
********************* GET COLLATED WHO-OWNS-WHOM-AND-WHEN **********************
********************************************************************************

* Import Who Owns Whom and When for Listed Firms *

use "$data/019g_whoOwnsWhomAndWhen_ReassignmentFriendly.dta", clear


* Append Who Owns Whom and When for Private Firms *

append using "$data/019f_whoOwnsWhomAndWhen_privateSubs.dta", gen(appendedSubs)

label var appendedSubs "Observation comes from appended subsidiary who-owns-whom data"


* Drop Subsidiaries who Share Names with "Mirror Names" Added in 019g *

bysort clean_name: egen existsAsListed = min(appendedSubs)

replace existsAsListed = 1 - existsAsListed

label var existsAsListed "Clean name directly attributed to at least one listed firm"

drop if existsAsListed == 1 & appendedSubs == 1

drop existsAsListed appendedSubs


* Merge Variables with Distinct Names *

replace singlePublicSubs = singleSubs if missing(singlePublicSubs) // Updates everything from the listed firms WOWAW

drop singleSubs // No longer needed


* Populate Private Subsidiary Indicator for Listed Firms Observations *

replace privateSubsidiary = 0 if missing(privateSubsidiary)


* Order, Compress, Export *

local orderString = "" // Used to order variables

foreach V of varlist gvkey*{
	
	if("`V'" == "gvkeyUO" | "`V'" == "gvkeyFR" | "`V'" == "gvkeyCNoriginator" | strpos("`V'", "gvkeyIntTier")){ // We don't want this one
		
		continue
		
	}
	
	local orderString = `"`orderString' `V' name`=substr("`V'",6,1)'"'
	
	quietly ds, has(varl *`V'*)
	
	foreach V2 in `=r(varlist)'{
		
		local orderString = "`orderString' `V2'"
		
	}
	
}

order clean_name privateSubsidiary gvkeyUO gvkeyFR cnLink_y1 cnLink_yN `orderString' gvkeyCNoriginator

compress

save "$data/019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollated.dta", replace





********************************************************************************
***************** GET SMALLER COLLATED WHO-OWNS-WHOM-AND-WHEN ******************
********************************************************************************

* Import Collated Who-Owns-Whom-And-When *

use "$data/019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollated.dta", clear


* Reduce Length of String Variables *

quietly ds, has(type string) // Get names of all string variables into `r(varlist)'

foreach strV in `r(varlist)'{
	
	if("`strV'" == "clean_name"){ // We keep clean names intact
		
		continue
		
	}
	
	replace `strV' = substr(`strV', 1, 47) + "..." if length(`strV') > 50
	
}


* Drop Original Name Link Year Variables *

drop *_year1 *_yearN


* Compress, Export *

compress

save "$data/019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollatedSkinny.dta", replace