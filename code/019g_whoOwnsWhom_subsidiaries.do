/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 23/06/2023
Last Modified: 23/06/2023


The purpose of this script is to map the set of private subsidiaries created in 018_collatedSubsidiaries.do to their ultimate owner gvkeys. 
- We exercise great caution around false positives before mapping a subsidiary clean name to an ultimate owner gvkey. This consists of seven major steps...
	(1) We remove any clean name that is owned by two *ultimate owner* gvkeys in a single year
	(~) As an intermediate step, we retain only those clean names which map to the patent data.
	(2) We remove any name that also appears as the trading name of a gvkey in our dataset of names from CRSP and Compustat
	(3) We drop names that clean to 4 or fewer characters
	(4) Following Arora, Belenzon, and Sheer (2021), we keep only subsidiaries that map to gvkeys to which we *already* match patents via their current or past trading names per CRSP/Compustat
	(5) We review any/all names that appears in the list of 100,000 common words from Church (2005) compiled via Wiktionary
	(6) We drop any subsidiary that doesn't patent within 10 years of its tenure *as a subsidiary*
	(~) As another intermediate step, we clean the mapping between clean names and gvkeys
	(7) We drop any clean_name that *simultaneously* undergoes a change of (i) immediate-owner gvkey, (ii) ultimate-owner gvkey, and (iii) original subsidiary name.
- We then create a "chains of ownership" dataset similar to the one that is built for gvkeys in 019d_whoOwnsWhom_gvkeys.do.
	

Infiles:
- 018d_collatedSubsidiaries.dta (All subsidiaries sourced from ABS 2021, general research, LM 1972, and 10-Ks, with their clean names. At the gvkey-clean_name-ownership_period level)
- 019d_whoOwnsWhomAndWhen_gvkeys.dta (A list of child-ultimate_parent relationships between gvkeys, at the gvkey-gvkey level)
- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
- 019e_dynamicNamesClean.dta (A dynamic mapping of names, as cleaned by the Dyèvre-Seager algorithm, to gvkeys)
- 019e_dynamicNamesClean_matched.dta (A dynamic mapping of clean names [that also feature in our patent dataset] to gvkeys)
- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)


Outfiles:
- 019g_subsidiariesCut.dta (A reduced list of subsidiaries created from 018d_collatedSubsidiaries.dta)
- 019g_subsidiariesCleanedAndCutAgain.dta (A further reduced list of subsidiaries created from 018d_collatedSubsidiaries.dta, with links to immediate-owner gvkeys cleaned)
- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Called .do Files:
None


External Packages:
- unique by Tony Brady


*/

********************************************************************************
********************* CUT DOWN NUMBER OF SUBSIDIARY NAMES **********************
********************************************************************************

* Import Collated Subsidiary Data *

use "$data/018d_collatedSubsidiaries.dta", clear


* joinby To gvkey Ownership Data *

rename year1 year1_subs // To prevent merging of variables with different meanings

rename yearN yearN_subs

joinby gvkey using "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", unmatched(both)
/*
					   _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
		  only in master data |      1,507        0.15        0.15 -- 307 gvkeys that appear in the data of Arora, Belenzon, and Sheer (2021) or the WRDS-SEC 10-K filing data, but not in our Compustat data
		   only in using data |     33,141        3.31        3.46 -- 31,869 gvkeys that do not feature in any of our subsidiary ownership datasets
both in master and using data |    967,324       96.54      100.00 -- 9,933 gvkeys that feature both in our version of Compustat and at least one of our subsidiary datasets
------------------------------+-----------------------------------
*/
keep if _merge == 3 // We only want to keep subsidiaries that map to gvkeys that feature in our version of Compustat

drop _merge // No longer informative


* Drop Extemporaneous Merges *

drop if yearN < year1_subs | year1 > yearN_subs


* Take Narrow Boundaries for Subsidiary -to- gvkey_uo Mappings *

gen year1_uo = max(year1, year1_subs)

label var year1_uo "First year in which subsidiary is ultimately owned by gvkey_uo"

gen yearN_uo = min(yearN, yearN_subs)

label var yearN_uo "Last year in which subsidiary is ultimately owned by gvkey_uo"

drop year1_subs yearN_subs year1 yearN


* Drop Extraneous Variables *

// We'll merge back into the original data below - for now we won't need these

drop gvkey subs_name name_source

duplicates drop // These are created by the name-cleaning algorithm


* Expand to gvkey-clean_name-Year Level *

expand (yearN_uo - year1_uo + 1)

bysort clean_name gvkey_uo subsidiary: gen year = year1_uo + _n - 1

label var year "Year in which subsidiary is owned by gvkey_uo"

drop year1_uo yearN_uo


* Get Number of Implied Owners by clean_name-Year *

quietly unique gvkey_uo, by(clean_name year) gen(nrOwners)

bysort clean_name year (nrOwners): replace nrOwners = nrOwners[1] // Unique only populates nrOwners in one observation per clean_name-year pair, which we rectify here.

label var nrOwners "Number of gvkey_uos implied to own subsidiary in given year"


* Get Maximal Number of Implied Owners by clean_name *

bysort clean_name: egen maxNrOwners = max(nrOwners)

label var maxNrOwners "Maximal number of implied owners of clean_name, all years"


* Remove All Subsidiary Names Implicitly Owned by Multiple gvkey_uos in a Given Year *

drop if maxNrOwners > 1


* Reduce to Clean Name Level *

keep clean_name

duplicates drop


* Retain Only Names that Merge to Patent Data *

merge 1:m clean_name using "$data/017f_patents_homogenised.dta", keepusing(clean_name) // We literally only want the _merge variable here, and not any actual variables from the patent data
/*
	Result                      Number of obs
	-----------------------------------------
	Not matched                     7,223,180
		from master                   536,640  (_merge==1) -- The 536,640 subsidiary clean names that don't merge to the patent data
		from using                  6,686,540  (_merge==2) -- The 612,188 clean names that feature in the patent data that aren't subsidiary names

	Matched                         2,169,288  (_merge==3) -- The 21,342 subsidiary clean names that *do* feature in our patent data (note we're yet to remove subsidiaries that share clean_names with their owners)
	-----------------------------------------
*/
keep if _merge == 3 // See above

drop _merge // No longer needed

duplicates drop // Created by multiple patents under a single name


* Append Names From our CRSP/Compustat Trading Names Data *

append using "$data/019e_dynamicNamesClean.dta", gen(isTradingNameObs) keep(clean_name)

label var isTradingNameObs "Observation is from our CRSP/Compustat names dataset"


* Drop Names that Also feature in Our CRSP/Compustat Names Data *

bysort clean_name: egen isTradingName = max(isTradingNameObs)

label var isTradingName "Clean name features in our CRSP/Compustat names dataset"

drop if isTradingName == 1 // Note that this also drops every trading name observation

drop isTradingName isTradingNameObs // No longer needed


* Drop Names that Clean to 4 or Fewer Characters *

drop if length(clean_name) < 5


* Merge Back to Subsidiary Names *

merge 1:m clean_name using "$data/018d_collatedSubsidiaries.dta"
/*
	Result                      Number of obs
	-----------------------------------------
	Not matched                       838,292
		from master                         0  (_merge==1) -- All merge from the master by construction
		from using                    838,292  (_merge==2) -- The 576,225 (97.23% of) clean names that have been dropped in our previous steps

	Matched                            29,156  (_merge==3) -- The 16,403 (2.77% of) clean names that we retain
	-----------------------------------------
*/
keep if _merge == 3

drop _merge


* Append gvkeys That Also Match to Patents in Our Matched Clean Name Dataset *

append using "$data/019e_dynamicNamesClean_matched.dta", gen(matchedGvkeyObs) keep(gvkey)

label var matchedGvkeyObs "Obs. refers to gvkey linked to CRSP/Compustat name appearing in our patent data"


* Drop Names Not Associated with gvkey Featuring in Our Top-Level Patent Match *

bysort gvkey: egen gvkeyIsMatched = max(matchedGvkeyObs)

label var gvkeyIsMatched "gvkey linked to CRSP/Compustat name appearing in our patent data"

keep if gvkeyIsMatched == 1 & matchedGvkeyObs == 0

drop matchedGvkeyObs gvkeyIsMatched


/*
The below... 
- gets a spreadsheet of clean names in the 100,000 common words document, with the original names and tenures on the accounting-side and the patent-side of the data, into temp4.xlsx
- Reviewing temp4.xlsx manually produces temp5.xlsx, which we use to write the code for the removal of clean names.

save "$data/temp.dta", replace
import delimited "$orig/Common Words/oneHundredThousandWords.csv", clear
drop if strpos(v1, "#") == 1
replace v1 = upper(v1) // So it merges with our clean name data
rename v1 orig_name // To facilitate the album
do "$code/500_nameCleaning.do"
drop orig_name clean_name_1 clean_name_2 clean_name_3 clean_name_4 clean_name_5
duplicates drop // Created by the cleaning algorithm
rename clean_name_6 word
label var word "Word"
compress
save "$data/019e_oneHundredThousandWords.dta", replace
use "$data/temp.dta", clear
keep clean_name
duplicates drop
rename clean_name word // Facilitates merge
merge 1:1 word using "data/019e_oneHundredThousandWords.dta"
keep if _merge == 3
drop _merge
rename word clean_name
merge 1:m clean_name using "$data/018d_collatedSubsidiaries.dta", keep(3)
drop _merge subsidiary
gen desc = "ABS" if name_source == "ABS 2021"
replace desc = "GR" if name_source == "Gen. Research"
replace desc = "LM" if name_source == "LM 1972"
replace desc = "SEC" if name_source == "SEC-WRDS 10-K"
tostring year1 yearN, replace
replace desc = desc + " : " + subs_name + " : " + gvkey + " " + year1 + "-" + yearN
bysort clean_name: gen _j = _n
keep clean_name desc _j
reshape wide desc, i(clean_name) j(_j)
gen long_desc_subs = ""
quietly ds
foreach V in `r(varlist)'{
	if("`V'" != "clean_name" & "`V'" != "long_desc_subs"){
		replace long_desc_subs = long_desc_subs + " ::: " if !missing(long_desc_subs) & !missing(`V')
		replace long_desc_subs = long_desc_subs + `V' if !missing(`V')
		drop `V'
	}
}
save "$data/temp2.dta", replace
use patent_id clean_name appYear using "$data/019e_patentsHomogenised_wDates.dta", clear
duplicates drop
merge m:1 clean_name using "$data/temp2.dta", keepusing(clean_name) keep(3)
drop _merge
merge 1:m clean_name patent_id using "$data/017f_patents_homogenised.dta", keepusing(orig_name) keep(3)
bysort clean_name orig_name (appYear): gen appYear1 = appYear[1]
bysort clean_name orig_name (appYear): gen appYearN = appYear[_N]
drop appYear patent_id _merge
duplicates drop
tostring appYear*, replace
save "$data/temp3.dta", replace
use "$data/temp3.dta", clear
gen desc = orig_name + " : " + appYear1
replace desc = desc + "-" + appYearN if appYear1 != appYearN
gsort clean_name appYear1 -appYearN orig_name
drop orig_name appYear1 appYearN
bysort clean_name: gen _j = _n
reshape wide desc, i(clean_name) j(_j)
gen long_desc_pat = ""
quietly ds
foreach V in `r(varlist)'{
	if("`V'" != "clean_name" & "`V'" != "long_desc_pat"){
		replace long_desc_pat = long_desc_pat + " ::: " if !missing(long_desc_pat) & !missing(`V')
		replace long_desc_pat = long_desc_pat + `V' if !missing(`V')
		drop `V'
	}
}
merge 1:1 clean_name using "$data/temp2.dta"
sort _merge
drop _merge
order clean_name long_desc_subs long_desc_pat
export excel "$data/temp4.xlsx", replace
import excel "$data/temp5.xlsx", clear
drop B C
local the_code_string = `"drop if clean_name == "SMART""'
forvalues i = 1/`=_N'{
	local dog = A[`i']
	local the_code_string = `"`the_code_string' | clean_name == "`dog'""'
}
di `"`the_code_string'"'
*/


* Drop Subsidiaries with Common Words as Clean Names *

// We get these by merging to a list of 100,000 common words obtained from Dan Church on GitHub. We review each case, not dropping companies such as "BOOTS", "HOLLISTER", and "SAWYERS", but dropping firms such as "HEADQUARTERS", "COEUR", and "PROJECT".

drop if clean_name == "SMART" | clean_name == "SMART" | clean_name == "MAXIMA" | clean_name == "MINOR" | clean_name == "MORAINE" | clean_name == "ARRIVAL" | clean_name == "ENDOR" | clean_name == "TAMAR" | clean_name == "MAYBE" | clean_name == "MCGRAW" | clean_name == "SHELF" | clean_name == "MATERIALS" | clean_name == "SANDS" | clean_name == "ATKINS" | clean_name == "BARROW" | clean_name == "HERSCHEL" | clean_name == "VIDEO" | clean_name == "NORMANDY" | clean_name == "EMERSON" | clean_name == "KELSEY" | clean_name == "WINDMILL" | clean_name == "BARSTOW" | clean_name == "HICKSON" | clean_name == "BASSETT" | clean_name == "SWISH" | clean_name == "MARKHAM" | clean_name == "COUGAR" | clean_name == "SIRIUS" | clean_name == "STORM" | clean_name == "CAMERON" | clean_name == "DUNDAS" | clean_name == "MANIA" | clean_name == "SPACE" | clean_name == "BERKELEY" | clean_name == "GALWAY" | clean_name == "BERNARD" | clean_name == "LINTON" | clean_name == "BENEFIT" | clean_name == "CAPELLA" | clean_name == "RUTLAND" | clean_name == "BRISTOW" | clean_name == "HAMLIN" | clean_name == "SPRINGFIELD" | clean_name == "CUSHMAN" | clean_name == "CALVIN" | clean_name == "SIGNATURE" | clean_name == "WALLACE" | clean_name == "SHIELD" | clean_name == "SAXON" | clean_name == "DESERT" | clean_name == "WALLS" | clean_name == "SOUND" | clean_name == "GROVES" | clean_name == "CALDER" | clean_name == "MOVING" | clean_name == "BANTER" | clean_name == "MONITOR" | clean_name == "BAYARD" | clean_name == "CARIBBEAN" | clean_name == "AZTEC" | clean_name == "VERONA" | clean_name == "PENNY" | clean_name == "WINNER" | clean_name == "COEUR" | clean_name == "CHARMS" | clean_name == "RECTOR" | clean_name == "STYLE" | clean_name == "TANDEM" | clean_name == "MERRITT" | clean_name == "KNICKERBOCKER" | clean_name == "THREADS" | clean_name == "COMMUNITIES" | clean_name == "NEPTUNE" | clean_name == "ALWAYS" | clean_name == "TITANIA" | clean_name == "ARLINGTON" | clean_name == "JAPAN" | clean_name == "WINSLOW" | clean_name == "CHECK" | clean_name == "UNIVERSE" | clean_name == "BREWSTER" | clean_name == "IMAGE" | clean_name == "MONSTER" | clean_name == "COPPERFIELD" | clean_name == "HEADQUARTERS" | clean_name == "DAGGER" | clean_name == "COMET" | clean_name == "TOLEDO" | clean_name == "REDMOND" | clean_name == "WHITEHEAD" | clean_name == "WATERLOO" | clean_name == "VARIABLE" | clean_name == "BARTON" | clean_name == "SECTOR" | clean_name == "HALEY" | clean_name == "CLEVELAND" | clean_name == "HYDRO" | clean_name == "DRAPERIES" | clean_name == "PRODUCTION" | clean_name == "HELMETS" | clean_name == "FOURTEEN" | clean_name == "BULLETIN" | clean_name == "CONVOY" | clean_name == "BIGGS" | clean_name == "PEARL" | clean_name == "ELEMENT" | clean_name == "BARNES" | clean_name == "WANDER" | clean_name == "PORTLAND" | clean_name == "HASTINGS" | clean_name == "SESAME" | clean_name == "QUIVER" | clean_name == "INQUEST" | clean_name == "LATIMER" | clean_name == "SPARKS" | clean_name == "BOYLE" | clean_name == "DAVENPORT" | clean_name == "DIXIE" | clean_name == "PLATA" | clean_name == "KEYSTONE" | clean_name == "VENTURA" | clean_name == "EQUIP" | clean_name == "RATION" | clean_name == "FUSION" | clean_name == "BARKLEY" | clean_name == "PATHWAY" | clean_name == "GRILL" | clean_name == "RAINBOW" | clean_name == "LATHROP" | clean_name == "GLORIA" | clean_name == "CENTRO" | clean_name == "RESERVE" | clean_name == "MEADE" | clean_name == "INDUS" | clean_name == "BERLIN" | clean_name == "RECEIPT" | clean_name == "GERMANTOWN" | clean_name == "NEWTON" | clean_name == "GUNTHER" | clean_name == "HADLEY" | clean_name == "PILOT" | clean_name == "HAMILTON" | clean_name == "ELECTRA" | clean_name == "STAMFORD" | clean_name == "SABER" | clean_name == "PELICAN" | clean_name == "SAMSON" | clean_name == "CUSTOM" | clean_name == "GRIMES" | clean_name == "ELEVEN" | clean_name == "COLUMBIAN" | clean_name == "DEVON" | clean_name == "VALLEY" | clean_name == "MITCHELL" | clean_name == "ANDERSEN" | clean_name == "SHARON" | clean_name == "OMAHA" | clean_name == "CHAPEL" | clean_name == "STITCH" | clean_name == "TRANSPORTATION" | clean_name == "ISLAND" | clean_name == "BLACKBIRD" | clean_name == "FOUNDATION" | clean_name == "KEPLER" | clean_name == "DAVID" | clean_name == "MEDICAL" | clean_name == "GLOBE" | clean_name == "GIBRALTAR" | clean_name == "DOMAIN" | clean_name == "GRANVILLE" | clean_name == "ROVER" | clean_name == "LAGOON" | clean_name == "LAGOS" | clean_name == "LUMIERE" | clean_name == "ROGER" | clean_name == "FRISCO" | clean_name == "CASANOVA" | clean_name == "ATTENTION" | clean_name == "FINES" | clean_name == "COMMONWEALTH" | clean_name == "LISTEN" | clean_name == "MADISON" | clean_name == "GRISWOLD" | clean_name == "EIGHT" | clean_name == "ALBERTA" | clean_name == "LISLE" | clean_name == "ELECTRICAL" | clean_name == "GOODMAN" | clean_name == "FOCUS" | clean_name == "CREDO" | clean_name == "MENDEZ" | clean_name == "WALLINGFORD" | clean_name == "METROPOLITAN" | clean_name == "ESTATE" | clean_name == "PARKER" | clean_name == "EHRLICH" | clean_name == "VERSUS" | clean_name == "MULLER" | clean_name == "CONTAINER" | clean_name == "PEGASUS" | clean_name == "BRAVO" | clean_name == "NICHOLAS" | clean_name == "PRESCOTT" | clean_name == "SNELL" | clean_name == "STILLWATER" | clean_name == "TEMPLETON" | clean_name == "OLSON" | clean_name == "COSMO" | clean_name == "CAPRICE" | clean_name == "HARTMANN" | clean_name == "WALKER" | clean_name == "PROJECT" | clean_name == "GALAXY" | clean_name == "CREDENTIALS" | clean_name == "CHARGER" | clean_name == "COILS" | clean_name == "CONDOR" | clean_name == "WALKERS" | clean_name == "VISTA" | clean_name == "REGAN" | clean_name == "POBOX" | clean_name == "COCHRANE" | clean_name == "MOTION" | clean_name == "JORDAN" | clean_name == "FILTERS" | clean_name == "HARTWELL" | clean_name == "ROBINSON" | clean_name == "BONDIT" | clean_name == "TAGIT" | clean_name == "NICHOLS" | clean_name == "RADIO" | clean_name == "SURGICAL" | clean_name == "RALLY" | clean_name == "DIOGENES" | clean_name == "SKINS" | clean_name == "RIGHT" | clean_name == "SQUIRE" | clean_name == "GAMBLE" | clean_name == "SUNSHINE" | clean_name == "HOLBROOK" | clean_name == "RELIABLE" | clean_name == "EMBARK" | clean_name == "RIVERSIDE" | clean_name == "DARBY" | clean_name == "ELTON" | clean_name == "FORMS" | clean_name == "APPLETON" | clean_name == "SALMON" | clean_name == "FRANCISCO" | clean_name == "HOUSEMAN" | clean_name == "STUDIES" | clean_name == "BONDS" | clean_name == "CLIFTON" | clean_name == "PAIGE" | clean_name == "COATES" | clean_name == "DURHAM" | clean_name == "TRUMPET" | clean_name == "PRIME" | clean_name == "SWIRL" | clean_name == "HOUSTON" | clean_name == "INTIME" | clean_name == "SHUTTLE" | clean_name == "VERMILION" | clean_name == "NUEVA" | clean_name == "STARR" | clean_name == "ALPHA" | clean_name == "SPECIALTIES" | clean_name == "WARRINGTON" | clean_name == "FJORD" | clean_name == "COLTS" | clean_name == "PORTMAN" | clean_name == "SALVER" | clean_name == "MILESTONE" | clean_name == "ENKEL" | clean_name == "STONE" | clean_name == "COLONY" | clean_name == "RATIONAL" | clean_name == "ARCHETYPE" | clean_name == "POLIS" | clean_name == "TEXTILE" | clean_name == "SUPERVISION" | clean_name == "VALVE" | clean_name == "STEWART" | clean_name == "COLLECTION" | clean_name == "SYKES" | clean_name == "GOLDEN" | clean_name == "CORDOVA" | clean_name == "DYNAMICS" | clean_name == "STORAGE" | clean_name == "LONGITUDE" | clean_name == "CONVEY" | clean_name == "SENIOR" | clean_name == "OSAGE" | clean_name == "REICH" | clean_name == "EARTH" | clean_name == "DAISY" | clean_name == "VALIANT" | clean_name == "SOLID" | clean_name == "LANCASTER" | clean_name == "DAVIS" | clean_name == "PAINE" | clean_name == "PURITAN" | clean_name == "CARROLL" | clean_name == "BRIDGE" | clean_name == "VERTICAL" | clean_name == "LAFAYETTE" | clean_name == "FLOWERS" | clean_name == "SIMPLICITY" | clean_name == "PATTERN" | clean_name == "SERRA" | clean_name == "REICHE" | clean_name == "NICKEL" | clean_name == "DENTAL" | clean_name == "DRAYTON" | clean_name == "FALKENBERG" | clean_name == "WILLETT" | clean_name == "HENSCHEL" | clean_name == "SUSTAIN" | clean_name == "WORKSHOP" | clean_name == "JEFFREY" | clean_name == "BRADLEY" | clean_name == "APPARATUS" | clean_name == "BARBER" | clean_name == "INTRA" | clean_name == "CARNOT" | clean_name == "ABERCROMBIE"


* Get The Clean Name's Tenure as a Subsidiary *

bysort clean_name: egen year1_cnSubs = min(year1)

label var year1_cnSubs "First year clean name appears as a subsidiary in our data"

bysort clean_name: egen yearN_cnSubs = min(yearN)

label var yearN_cnSubs "Last year clean name appears as a subsidiary in our data"


* Reduce back to Clean Name Level *

keep clean_name year1_cn yearN_cn

duplicates drop // Created by the multiple original names and gvkey ownerships


* Merge into Patenting Data *

merge 1:m clean_name using "$data/019e_patentsHomogenised_wDates.dta", keepusing(appYear) keep(1 3) // We restrict what we merge here, since the dataset we're merging to is massive and quite wide
/*
	Result                      Number of obs
	-----------------------------------------
	Not matched                           104
		from master                       104  (_merge==1) -- For 104 patenters, the USPTO does not provide dates for any of their patents, so their patents do not appear in the "Homgenised Patents with Dates" dataset.
		from using                          0  (_merge==2)

	Matched                           403,541  (_merge==3) -- 11,559 patenters for whom at least one patent is given a date by the USPTO.
	-----------------------------------------
*/
drop if _merge == 1 // We can't use the patents of these firms anyway; see above.

drop _merge // No longer useful


* Get Clean Name's Tenure as a Patenter *

bysort clean_name: egen year1_cnPat = min(appYear)

label var year1_cnPat "First year clean name applies for a (later granted) patent in our data"

bysort clean_name: egen yearN_cnPat = max(appYear)

label var yearN_cnPat "Last year clean name applies for a (later granted) patent in our data"


* Reduce Back to Clean Name Level *

drop appYear // Only remaining patent-level variable

duplicates drop


* Drop Subsidiaries who do not Patent within 10 Years of their Tenure as a Subsidiary *

drop if year1_cnPat > yearN_cnSubs + 10 | yearN_cnPat < year1_cnSubs - 10

drop year1_cnSubs yearN_cnSubs year1_cnPat yearN_cnPat // No longer needed


* Merge Back to Collated Subsidiary Data *

merge 1:m clean_name using "$data/018d_collatedSubsidiaries.dta"
/*
	Result                      Number of obs
	-----------------------------------------
	Not matched                       849,163
		from master                         0  (_merge==1)
		from using                    849,163  (_merge==2) -- All the subsidiaries with clean names that have already been excluded from contention.

	Matched                            18,285  (_merge==3) -- All the subsidiaries with clean names that we're still considering using in our final data at this point in the code.
	-----------------------------------------
*/
keep if _merge == 3 // See above

drop _merge // No longer informative


* Export *

compress

save "$data/019g_subsidiariesCut.dta", replace





********************************************************************************
********************** PROCESS REMAINING SUBSIDIARY NAMES **********************
********************************************************************************

* Import *

use "$data/019g_subsidiariesCut.dta", clear


* Pick a Random Name to Use an Example from the Subsidiary Data *

// For example, the clean name OXOID has 40 different unclean names of subsidiaries mapping to it. We can't retain all of these

set seed 0

gen runif = runiform()

label var runif "Random variable from Uniform[0,1] distribution"

quietly unique subs_name, by(clean_name gvkey) gen(cnG_nrNames)

bysort clean_name gvkey (cnG_nrNames): replace cnG_nrNames = cnG_nrNames[1]

label var cnG_nrNames "Number of original names mapping to clean_name-gvkey pairing"

bysort clean_name gvkey (runif): replace subs_name = subs_name[1]

bysort clean_name gvkey (runif): replace name_source = name_source[1]

replace subs_name = "Example: " + subs_name if cnG_nrNames > 1 // Indicate that the name is but an example

drop runif cnG_nrNames

duplicates drop // Created by randomly assigning original subsidiary name to every observation in the gvkey-clean_name pair


* Smooth Over Subsidiary (by Clean Name) -to- gvkey Links *

// This doesn't smooth over gaps, but overlaps. Suppose clean_name ALPHACORP links to gvkey 000001 over three observations: one for 2000-2002; one for 2001-2003; one for 2004-2006. We want to convert this to a single observation running from 2000-2006. That's what we do here. Suppose BETATECH links to gvkey 000002 over two observations: one for 1990-1992; one for 1994-1997. We do *nothing* here, and postpone that until later.

bysort clean_name gvkey: gen cnG_nrObs = _N

label var cnG_nrObs "Number of observations within gvkey-clean_name pair"

gen smooth_forward = 0

label var smooth_forward "Observation flagged to be smoothed forward"

gen drop_obs = 0

label var drop_obs "Observation flagged to be dropped due to redundancy"

quietly summ cnG_nrObs // Gets maximal number of observations per clean_name-gvkey pair into `=r(max)'

forvalues i = 1/`=(`=r(max)' - 1)'{
	
	local loop_switch = 1 // We do this because if we delete the second observation within a clean_name-gvkey pair, the third observation becomes the second and we want to stay considering that one
	
	while(`loop_switch' == 1){
		
		bysort clean_name gvkey (year1 yearN): replace drop_obs = 1 if year1[_n-1] == year1 & yearN[_n-1] <= yearN & _n == `i' + 1 & _n <= _N
		
		bysort clean_name gvkey (year1 yearN): replace smooth_forward = 1 if year1 == year1[_n+1] & yearN < yearN[_n+1] & _n == `i'
		
		bysort clean_name gvkey (year1 yearN): replace drop_obs = 1 if year1[_n-1] < year1 & yearN[_n-1] >= yearN & _n == `i' + 1 & _n <= _N
		
		bysort clean_name gvkey (year1 yearN): replace smooth_forward = 1 if year1 < year1[_n+1] & yearN < yearN[_n+1] & yearN + 1 >= year1[_n+1] & _n == `i' & _n < _N
		
		bysort clean_name gvkey (year1 yearN): replace drop_obs = 1 if year1[_n-1] < year1 & yearN[_n-1] < yearN & yearN[_n-1] + 1 >= year1 & _n == `i' + 1 & _n <= _N
		
		quietly count if drop_obs == 1 | smooth_forward == 1 // Gets number of changes to be made into `=r(N)'
		
		if(`=r(N)' == 0){ // If no changes are to be made, we exit the loop
			
			local loop_switch = 0
			
		}
		
		bysort clean_name gvkey (year1 yearN): replace yearN = yearN[_n+1] if smooth_forward == 1 // The actual smoothing
		
		drop if drop_obs == 1 // The dropping of redundant observations
		
		replace smooth_forward = 0 // For the next round of consideration
		
		replace drop_obs = 0
		
	}
	
}

drop cnG_nrObs smooth_forward drop_obs // No longer needed


* Realign Overlaps * // These are created when a subsidiary is listed under two subsidiaries that both have the same ultimate owner.

bysort clean_name (year1 yearN): replace year1 = yearN[_n-1] + 1 if _n > 1 & yearN[_n-1] >= year1 & yearN[_n-1] < yearN // If the previous observation overlaps with the current one, we change the start date of the current one to the year after the previous one finishes (assuming yearN > yearN[_n-1]).


* Drop Redundant Observations *

// If the current observation overlaps with the previous (in terms of start date) observation for its entire tenure, then we just drop it

bysort clean_name: gen cn_nrObs = _N

label var cn_nrObs "Number of observations associated with clean name"

quietly summ cn_nrObs // Gets maximal number of observations into `=r(max)'

local max_obs = `=r(max)'

if(`max_obs' > 1){ // Executes if the maximal number of observations is greater than one, which in turn means we have potential redundant observations to look for
	
	forvalues i = 2/`max_obs'{ // We start at the 2nd observation because we're comparing to the previous one.
		
		local whileLoopSwitch = 1
		
		while(`whileLoopSwitch' == 1){ // If we delete the 2nd observation (ordered by start date) associated with a given clean name, then the 3rd becomes the second, so we need to consider the "2nd" observation twice. Thus, we run a while loop until no more drops are left to be made.
			
			bysort clean_name (year1 yearN): drop if _n == `i' & yearN[_n-1] >= year1 & yearN[_n-1] >= yearN 
			
			local whileLoopSwitch = `=(`=r(N_drop)' > 0)' // 1 if observations are dropped. 0 if not.
			
		}
		
	}
	
}

drop cn_nrObs // No longer needed


* Smooth over Gaps for clean_name-gvkey Links *

// If a subsidiary maps to a gvkey for 2000-2001 and then again for 2003-2004, and doesn't map to anyone for 2002, then we smooth over the link such that the mapping is from 2000-2004

bysort clean_name: gen cn_nrObs = _N

label var cn_nrObs "Number of observations associated with clean name"

quietly summ cn_nrObs // Gets maximal number of observations into `=r(max)'

local maxObsLessOne = `=r(max)' - 1

if(`maxObsLessOne' > 0){ // Executes if the maximal number of observations is greater than one, which in turn means we have potential gaps to smooth over.
	
	forvalues i = 1/`maxObsLessOne'{ // We loop through observations 1 to N-1
		
		local whileLoopSwitch = 1
		
		while(`whileLoopSwitch' == 1){ // If we extend the 1st observation (ordered by start date) forward to the yearN of the 2nd, and then drop the 2nd, the 3rd observation becomes the second. We need to make this comparison again. Therefore, we run a while loop until no more drops are left to be made.
			
			bysort clean_name (year1 yearN): replace yearN = yearN[_n+1] if _n == `i' & gvkey == gvkey[_n+1] // Extends the first link forward to the end date of the second
			
			bysort clean_name (year1 yearN): drop if _n == `i' + 1 & gvkey == gvkey[_n-1] // Drops the second link, which is now redundant
			
			local whileLoopSwitch = `=(`=r(N_drop)' > 0)' // 1 if observations are dropped. 0 if not.
			
		}
		
	}

}


* Joinby to Chains of Ownership *

rename gvkey gvkey_secondary // Facilitates the joinby

rename year1 year1_immediate // Since the chains of ownership data has a 'year1' variable with a different meaning

rename yearN yearN_immediate

joinby gvkey using "$data/019d_chainsOfOwnership.dta", unmatched(master)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |          2        0.02        0.02 -- One of these just has gvkey "000000" to flag that it is sold back into the privately-held world, the other is a gvkey that appears only in the SEC data, and not ours.
both in master and using data |     12,182       99.98      100.00
------------------------------+-----------------------------------
                        Total |     12,184      100.00
*/

replace gvkey_primary = "000000" if gvkey_secondary == "000000" // We use the gvkey 000000 to indicate that a subsidiary goes back to being privately owned by a private company (possibly itself)

drop if missing(gvkey_primary)

drop _merge gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkS_laterDivorced gvkT1_laterDivorced gvkT2_laterDivorced gvkT3_laterDivorced

rename gvkey_secondary gvkey

rename gvkey_primary gvkey_uo

label var year1 "First year of continuous ownership of gvkey by gvkey_uo"

label var yearN "Last year of continuous ownership of gvkey by gvkey_uo"


* Drop Extemporaneous Mappings *

drop if year1 > yearN_immediate | yearN < year1_immediate


* Get First and Last Years Subsidiary is Owned by gvkey_uo *

gen year1_uo = max(year1, year1_immediate)

label var year1_uo "First year of continuous ownership of clean_name by gvkey_uo via gvkey"

gen yearN_uo = min(yearN, yearN_immediate)

label var yearN_uo "Last year of continuous ownership of clean_name by gvkey_uo via gvkey"


* Drop Clean Names that Undergo Simultaneous Change of gvkey, gvkey_uo, and Original Subsidiary Name *

bysort clean_name (year1_uo): gen fullChangeFlag = (_n > 1 & gvkey != gvkey[_n-1] & gvkey_uo != gvkey_uo[_n-1] & upper(subs_name) != upper(subs_name[_n-1])) // Flags if previous or next change is "full ownership change"

bysort clean_name (fullChangeFlag): replace fullChangeFlag = fullChangeFlag[_N] // Makes flag uniform at clean_name level

label var fullChangeFlag "clean_name simultaneously changes both gvkey and gvkey_uo at some point"

drop if fullChangeFlag == 1


* Reduce Back to clean_name-gvkey-year1 Level *

keep clean_name gvkey subs_name year1_immediate yearN_immediate name_source subsidiary

duplicates drop


* Export *

compress

save "$data/019g_subsidiariesCleanedAndCutAgain.dta", replace





********************************************************************************
****************** CREATE SUBSIDIARY CHAINS OF OWNERSHIP DATA ******************
********************************************************************************

* Import Cleaned and Cut Subsidiary Data *

use "$data/019g_subsidiariesCleanedAndCutAgain.dta", clear


* Push Subsidiary Name Forward Where Possible *

// We assume the subsidiary to first be owned by gvkey in year1_immediate (i.e. when it first appears as a subsidiary in our data), but we also push forward where possible.

bysort clean_name (year1_immediate): replace yearN_immediate = year1_immediate[_n+1] - 1 if _n < _N

bysort clean_name (year1_immediate): replace yearN_immediate = 2020 if _n == _N // Even if this is too far forward, it'll be trimmed by the boundaries of ultimate ownership of gvkey anyway.


* Merge to Chains of (Publicly-held Firm) Ownership Data *

rename gvkey gvkey_secondary // To facilitate the merge

joinby gvkey using "$data/019d_chainsOfOwnership.dta", unmatched(master)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
both in master and using data |     10,681      100.00      100.00 -- Everything from the master merges.
------------------------------+-----------------------------------
                        Total |     10,681      100.00
*/
drop _merge // Not informative


* Drop Extemporaneous Mappings *

drop if year1 > yearN_immediate | yearN < year1_immediate


* Get First and Last Years Subsidiary Maps to gvkey_uo via gvkey *

gen year1_uo = max(year1, year1_immediate)

label var year1_uo "First year of continuous ownership of clean_name by gvkey_uo via gvkey"

gen yearN_uo = min(yearN, yearN_immediate)

label var yearN_uo "Last year of continuous ownership of clean_name by gvkey_uo via gvkey"

drop year1_immediate yearN_immediate year1 yearN // No longer needed

rename year1_uo year1

rename yearN_uo yearN


* Rename Variables for Clarity *

rename gvkey_primary gvkey_uo

label var gvkey_uo "Ultimate owner of gvkey_secondary"

rename subsidiary privateSubsidiary

label var privateSubsidiary "clean_name belongs to a private subsidiary of gvkey_secondary"


* Get First and Last Year of Link Between Clean Name and *gvkey_uo* *

bysort clean_name (year1): gen uo_ownershipRun = 1 if _n == 1

bysort clean_name (year1): replace uo_ownershipRun = uo_ownershipRun[_n-1] + (gvkey_uo != gvkey_uo[_n-1]) if _n > 1 

label var uo_ownershipRun "Distinct stint of ultimate ownership of clean name"

bysort clean_name uo_ownershipRun (year1): egen cnLink_y1 = min(year1)

label var cnLink_y1 "First year of link between gvkey_uo and clean_name"

bysort clean_name uo_ownershipRun (yearN): egen cnLink_yN = max(yearN)

label var cnLink_yN "Last year of link between gvkey_uo and clean_name"

drop uo_ownershipRun // No longer needed


* Flag if Clean Name Maps to gvkey_uo through a Single gvkey *

bysort clean_name gvkey_uo cnLink_y1 cnLink_yN: egen singlePublicSubs = min(_n == 1 | gvkey_secondary == gvkey_secondary[_n-1]) // Equals one if there's only a single gvkey in the clean_name-gvkey_uo-cnLink_y1-cnLink_yN grouping

label var singlePublicSubs "clean_name maps to gvkey_uo through single subsidiary gvkey (possibly self)" // I think this needs re-writing at some point; see "XIOTECH"


* Get the "Clean Name Originator" gvkey *

gen gvkeyCNoriginator = gvkey_secondary if singlePublicSubs == 1

label var gvkeyCNoriginator "Sole public subsidiary (possibly self) mapping clean_name to gvkey_uo"


* Flag Whether Subsidiary is Later Divorced from Immediate Parent *

bysort clean_name: gen cn_nrMappings = _N

label var cn_nrMappings "Number of distinct mappings from clean_name to *any* gvkey_uo"

quietly summ cn_nrMappings // Gets maximal number of distinct mappings from clean_name into `=r(max)'

local maxMappings = `=r(max)'

local maxMappingsLessOne = `maxMappings' - 1

gen ps_laterDivorced = 0 if singlePublicSubs == 1 // We only consider this relevant where the clean name is mapped to gvkey_uo via a single public owner.

forvalues i = 1/`maxMappingsLessOne'{
	
	local iPlusOne = `i' + 1
	
	forvalues j = `iPlusOne'/`maxMappings'{
		
		bysort clean_name (cnLink_y1): replace ps_laterDivorced = 1 if (_n == `i' & `j' <= _N & gvkey_secondary != gvkey_secondary[`j'] & gvkey_secondary != gvkeyIntTier3[`j'] & gvkey_secondary != gvkeyIntTier2[`j'] & gvkey_secondary != gvkeyIntTier1[`j'] & gvkey_secondary != gvkey_uo[`j'] & singlePublicSubs == 1)
		
	}
	
}

label var ps_laterDivorced "Private subsidiary is later divorced from gvkeyCNoriginator"

drop cn_nrMappings // No longer needed


* Initiate gvkeyFR Variable *

gen gvkeyFR = gvkey_uo if singlePublicSubs == 0 | ((ps_laterDivorced == 0 | missing(ps_laterDivorced)) & (gvkS_laterDivorced == 0 | missing(gvkS_laterDivorced)) & (gvkT3_laterDivorced == 0 | missing(gvkT3_laterDivorced)) & (gvkT2_laterDivorced == 0 | missing(gvkT2_laterDivorced)) & (gvkT1_laterDivorced == 0 | missing(gvkT1_laterDivorced)))

label var gvkeyFR "gvkey used for patent reassignment"


* Replace gvkeyFR with Lowest Tier Later-divorced gvkey Where Appropriate *

replace gvkeyFR = gvkeyIntTier1 if gvkT1_laterDivorced == 1 & singlePublicSubs == 1

replace gvkeyFR = gvkeyIntTier2 if gvkT2_laterDivorced == 1 & singlePublicSubs == 1

replace gvkeyFR = gvkeyIntTier3 if gvkT3_laterDivorced == 1 & singlePublicSubs == 1

replace gvkeyFR = gvkey_secondary if gvkS_laterDivorced == 1 & singlePublicSubs == 1

replace gvkeyFR = "X" if ps_laterDivorced == 1 & singlePublicSubs == 1

drop gvkS_laterDivorced gvkT1_laterDivorced gvkT2_laterDivorced gvkT3_laterDivorced


* Get a Private-Subsidiary-specific gvkeyFR where Necessary *

gsort -ps_laterDivorced clean_name

gen ps_id = 1 if _n == 1 & ps_laterDivorced == 1

replace ps_id = ps_id[_n-1] + (clean_name != clean_name[_n-1]) if _n > 1 & ps_laterDivorced == 1

label var ps_id "Unique (amongst later-divorced private subsidiaries) private subsidiary ID"

tostring ps_id, replace // Move to string

replace ps_id = "" if ps_id == "." // Move to missing from missing numeric

gen ps_idLen = length(ps_id)

label var ps_idLen "Number of characters in ps_id"

quietly summ ps_idLen // Gets maximal number of characters in ps_idLen into `=r(max)'

local maxLenLessOne = `=r(max)' - 1 // We want all of the subsidiary gvkeyFRs to be the same length

forvalue i = 1/`maxLenLessOne'{
	
	replace ps_id = "0" + ps_id if length(ps_id) == `i'
	
}

replace gvkeyFR = "S" + ps_id if gvkeyFR == "X" // Gets a unique ps_id into gvkeyFR

drop ps_id ps_idLen ps_laterDivorced


* Relabel, Reorder Variables for Clarity *

label var privateSubsidiary "clean_name maps to gvkey_uo from a private subsidiary"

label var cnLink_y1 "First year of link between gvkey_uo, gvkeyFR, and clean_name"

label var cnLink_yN "Last year of link between gvkey_uo, gvkeyFR, and clean_name"

order clean_name privateSubsidiary gvkey_uo gvkeyFR cnLink_y1 cnLink_yN singlePublicSubs gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkeyCNoriginator gvkey_secondary subs_name year1 yearN name_source

rename gvkey_secondary gvkey

rename subs_name name

rename year1 name_year1

rename yearN name_yearN


* Move Intermediary Information to Missing Where clean_name Maps to gvkey_uo Through Multiple gvkeys *

foreach V in gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3{
	
	replace `V' = "" if singlePublicSubs == 0
	
}

label var gvkeyIntTier1 "Great-grandparent of gvkeyCNoriginator, ultimately owned by gvkey_uo"

label var gvkeyIntTier2 "Grandparent of gvkeyCNoriginator, ultimately owned by gvkey_uo"

label var gvkeyIntTier3 "Grandparent of gvkeyCNoriginator, ultimately owned by gvkey_uo"


* Reshape to clean_name-gvkey_uo-cnLink_y1-cnLink_yN Level *

bysort clean_name gvkey_uo cnLink_y1 cnLink_yN (name_year1 gvkey): gen _j = _n

label var _j "Reshape facilitator"

quietly summ _j // Gets the future width of the dataset into `=r(max)'

local width = `=r(max)'

reshape wide gvkey name name_year1 name_yearN name_source, i(clean_name gvkey_uo cnLink_y1 cnLink_yN) j(_j)

forvalues i = 1/`width'{
	
	label var gvkey`i' "gvkey through which name`i' maps to gvkey_uo, producing the clean name link"
	
	label var name`i' "Name #`i' producing link between gvkey_uo and clean_name"
	
	rename name_year1`i' name`i'_year1
	
	label var name`i'_year1 "First year name`i' strictly links to gvkey`i'"
	
	rename name_yearN`i' name`i'_yearN
	
	label var name`i'_yearN "Last year name`i' strictly links to gvkey`i'"
	
	rename name_source`i' name`i'_source
	
	label var name`i'_source "Source of data linking name`i' to gvkey`i'"
	
}


* Adjust gvkeyFRs for Reverse Spin-offs *

replace gvkeyFR = "026061B" if gvkey_uo == "026061" & cnLink_y1 < 2020 & cnLink_y1 > 1998 & clean_name != "HOTTIES" //IAC Interactive/Match Group. This is the only reverse spin-off that concerns subsidiaries.


* Order, Compress, Export *

order clean_name privateSubsidiary gvkey_uo gvkeyFR cnLink_y1 cnLink_yN

compress

save "$data/019g_whoOwnsWhomAndWhen_privateSubs.dta", replace