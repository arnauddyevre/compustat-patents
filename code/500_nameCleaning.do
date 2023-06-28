/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17

This is the centralised name cleaning process. There were too many .do files using the name cleaning process, so now it is all in one place and can be edited as such.

Created: 08/08/2022
Last Modified: 12/04/2022

In Variables:
- orig_name (The original name of the firm)

Out Variables:
- orig_name (The original name of the firm)
- clean_name_1 (orig_name with whitespace cleaning and removal of redundant whitespace.)
- clean_name_2 (clean_name_1 cleaned of non-alphanumeric characters)
- clean_name_3 (clean_name_2 with acronyms condensed)
- clean_name_4 (clean_name_3 with standardised corporate terms removed)
- clean_name_5 (clean_name_4 with standard terms mapped to their abbreviations)
- clean_name_6 (clean_name_5 with all whitespace removed)

External Packages:
None

*/

********************************************************************************
********************************************************************************
***************************** Deal with Whitespace *****************************
********************************************************************************
********************************************************************************

* Get a New Clean Name *

gen clean_name_1 = orig_name


* Replace non-Space Whitespace with Space Whitespace * // An example of non-space whitespace would be tab or newline

replace clean_name_1 = regexr(clean_name_1, "[\s]", " ") // \s is all whitespace characters, the space is the space whitespace character.


* Trim Consecutive Whitespace Characters to Single Character *

replace clean_name_1 = stritrim(clean_name_1)


* Get Rid of Leading, Trailing Whitespace *

replace clean_name_1 = strtrim(clean_name_1)


* If Erased, Replace with Previous Clean Name *

replace clean_name_1 = orig_name if missing(clean_name_1)


* Label New Variable *

label var clean_name_1 "Name after cleaning leading, trailing, or non-standard whitespace."



********************************************************************************
********************************************************************************
********************** Remove non-Alphanumeric Characters **********************
********************************************************************************
********************************************************************************

/* The below code is what I used to get examples of remaining non-alphanumeric characters.

preserve
gen nonalphanumeric = regexm(clean_name_2, "[^a-zA-z0-9 ]")
gen what_character = regexs(0) if regexm(clean_name_2, "[^a-zA-z0-9 ]")
drop if nonalphanumeric == 0
tabulate what_character
count
restore
*/

* Get New Clean Name *

gen clean_name_2 = clean_name_1


* ! *

replace clean_name_2 = subinstr(clean_name_2, "!", "", .)


* " *

replace clean_name_2 = subinstr(clean_name_2, "&#34;", "", .) //  &#34; is a substitute for "

replace clean_name_2 = subinstr(clean_name_2, `"""', "", .) 


* # *

replace clean_name_2 = subinstr(clean_name_2, "#", "", .)


* $ *

replace clean_name_2 = subinstr(clean_name_2, "$", "S", .) // These appear to all be mis-parsed "S" characters


* % *

// First replace with " PERCENT", then strip of whitespace.

replace clean_name_2 = substr(clean_name_2, 1, length(clean_name_2) - 6) if substr(clean_name_2, -2, 2) == "%)" // Removes, for example, " (60%)" from the end of the string.

replace clean_name_2 = subinstr(clean_name_2, "%", " PERCENT", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* & *

replace clean_name_2 = subinstr(clean_name_2, "&AMP", "AND", .) // "&AMP" is a particularly common thing in the Fleming Dataset.

replace clean_name_2 = subinstr(clean_name_2, "&amp", "AND", .)

replace clean_name_2 = subinstr(clean_name_2, "&", "AND", .)


* ' *

replace clean_name_2 = subinstr(clean_name_2, "&#39;", "", .) // "&#39;" is a common substitute for "'" in the Fleming Dataset.

replace clean_name_2 = subinstr(clean_name_2, "'", "", .)


* () *

replace clean_name_2 = subinstr(clean_name_2, "(", "", .)

replace clean_name_2 = subinstr(clean_name_2, ")", "", .)


* * *

replace clean_name_2 = subinstr(clean_name_2, "*", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* + *

// This requires some care, but can mostly be replaced with " AND "

replace clean_name_2 = subinstr(clean_name_2, "A+", "A PLUS", .) if clean_name_2 == "A+ CORP" | clean_name_2 == "A+ ELEVATORS AND LIFTS LLC" | clean_name_2 == "A+ MANUFACTURING LLC" | clean_name_2 == "A+MANUFACTURING LLC" | clean_name_2 == "A+ CORP" | clean_name_2 == "A+SCIENCE INVEST AB" | clean_name_2 == "TYPE A+ LLC"

replace clean_name_2 = "A PLUS ELEVATORS AND LIFTS LLC" if clean_name_2 == "A + CORP"

replace clean_name_2 = "ADD ON INDUSTRIES INC" if clean_name_2 == "ADD +ON INDUSTRIES INC"

replace clean_name_2 = subinstr(clean_name_2, "&#43;", " AND ", .) // "&#43;" is a substitute for "+" in the Fleming Dataset

replace clean_name_2 = subinstr(clean_name_2, "+", " AND ", .) 

replace clean_name_2 = stritrim(clean_name_2) 

replace clean_name_2 = strtrim(clean_name_2)


* - *

replace clean_name_2 = subinstr(clean_name_2, "-", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* . *

replace clean_name_2 = subinstr(clean_name_2, ".", " ", .) 

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* / *

// Like with hyphens, here we replace a forward slash with a space, and then use the standard whitespace procedure

replace clean_name_2 = subinstr(clean_name_2, "/", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* , *

replace clean_name_2 = subinstr(clean_name_2, ",", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* @ *

replace clean_name_2 = subinstr(clean_name_2, "@", " AT ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* ; *

replace clean_name_2 = subinstr(clean_name_2, ";", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* : *

// First replace with a space, then strip whitespace.

replace clean_name_2 = "WATER SOLUTIONS INC" if clean_name_2 == "1:7 WATER SOLUTIONS INC"

replace clean_name_2 = subinstr(clean_name_2, ":", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* % *

// First replace with " PERCENT", then strip of whitespace.

replace clean_name_2 = subinstr(clean_name_2, "%", " PERCENT", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* < *

// This are all just part of mis-parsed gibberish.

replace clean_name_2 = subinstr(clean_name_2, "<", "", .)


* = *

// Only one valid company name, in which = is properly replaced with nothing

replace clean_name_2 = subinstr(clean_name_2, "=", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* > *

// Again, mis-parsed gibberish

replace clean_name_2 = subinstr(clean_name_2, ">" , "", .)


* ? *

// Comes at the end of a lot of company names.

replace clean_name_2 = subinstr(clean_name_2, "?", " ", .)

replace clean_name_2 = stritrim(clean_name_2)

replace clean_name_2 = strtrim(clean_name_2)


* {} *

// These all indicate nonstandard latin characters, i.e. {HACEK OVER N}, {DOT OVER O}. Since nonstandard latin characters do not appear in compustat, these are replaced with the latin characters that are amended, which can be parsed as the character before }...

replace clean_name_2 = subinstr(clean_name_2, "{", "", .) if clean_name_2 == "{PERSONALIZED MEDIA COMMUNICATIONS LLC"

// Since regular expressions works one matched substring at a time (and we need to use regular expressions here), we loop through this process until it's complete.

count if regexm(clean_name_2, "{[^}]*}") // This counts the number of observations in which "{some phrase}" is matched

local loop_switch = r(N) // Initiates loop switch

while (`loop_switch' > 0){
	
	gen nonstandard_char = regexs(0) if regexm(clean_name_2, "{[^}]*}") // Gets matched "{some phrase}" substring
	
	gen nonstandard_char_clean = subinstr(nonstandard_char, "(", "", .)

	replace nonstandard_char_clean = subinstr(nonstandard_char_clean, ")", "", .)
	
	replace nonstandard_char_clean = stritrim(nonstandard_char_clean)

	replace nonstandard_char_clean = strtrim(nonstandard_char_clean)
	
	list clean_name_2 if nonstandard_char_clean != "" // Prints observations to be changed
	
	gen standard_char = substr(nonstandard_char_clean, -2, 1) // Extracts standard latin character that is amended
	
	replace clean_name_2 = subinstr(clean_name_2, nonstandard_char, standard_char, .) // Replaces "{some phrase}" with standard character the curly brackets signify an amendment to
	
	list clean_name_2 if nonstandard_char != "" // Prints now-changed observations
	
	quietly count if regexm(clean_name_2, "{[^}]*}") // Counts observations with changes still needed
	
	local loop_switch = r(N) // Updates loop switch
	
	drop nonstandard_char nonstandard_char_clean standard_char
	
}

replace clean_name_2 = subinstr(clean_name_2, "{", "", .)

replace clean_name_2 = subinstr(clean_name_2, "}", "", .)


* | *

replace clean_name_2 = subinstr(clean_name_2, "|", " ", .)


* [] *

// We deal with these the same way we dealt with ()

replace clean_name_2 = subinstr(clean_name_2, "[", "", .)

replace clean_name_2 = subinstr(clean_name_2, "]", "", .)


* _ *

// This is generally used instead of a space

replace clean_name_2 = subinstr(clean_name_2, "_", " ", .) 

replace clean_name_2 = stritrim(clean_name_2) 

replace clean_name_2 = strtrim(clean_name_2)


* ` *

// Since this works largely in the same way as an apostrophe, we just drop the character

replace clean_name_2 = subinstr(clean_name_2, "`", "", .)


* Accented Letters *

foreach mapping in "À:A" "Á:A" "Â:A" "Ä:A" "Å:A" "Ã:A" "Æ:AE" "Ç:C" "É:E" "È:E" "Ê:E" "Ë:E" "Í:I" "Ì:I" "Î:I" "Ï:I" "Ñ:N" "Ó:O" "Ò:O" "Ô:O" "Ö:O" "Ø:O" "Õ:O" "OE:OE" "Ú:U" "Ù:U" "Û:U" "Ü:U" "Ý:Y"{
	
	local subout `=substr("`mapping'", 1, strpos("`mapping'", ":") - 1)' 
	
	local subin `=substr("`mapping'", strpos("`mapping'", ":") + 1, .)'
	
	replace clean_name_2 = subinstr(clean_name_2, "`subout'", "`subin'", .)
	
}


* Remove Other Characters *

local loop_switch = 1

gen alphanumeric_clean_name_2 = ""

while(`loop_switch' == 1){

	replace alphanumeric_clean_name_2 = regexs(0) if regexm(clean_name_2, "[A-Z0-9 ]*") // Gets the starting alphanumeric string for *all* observations. Using list if alphanumeric_clean_name_2 != clean_name_2 is also a good way of identifying nonalphanumeric characters present

	replace clean_name_2 = substr(clean_name_2, 1, length(alphanumeric_clean_name_2)) + substr(clean_name_2, length(alphanumeric_clean_name_2) + 2, .) if regexm(clean_name_2, "[A-Z0-9 ]*") // Removes the non-alphanumeric character from clean_name_2

	quietly count if regexm(clean_name_2, "[^A-Z0-9 ]")

	local loop_switch = !!`=r(N)'

}

drop alphanumeric_clean_name

replace clean_name_2 = stritrim(clean_name_2) 

replace clean_name_2 = strtrim(clean_name_2)


* Strip Extraneous Whitespace *

replace clean_name_2 = stritrim(clean_name_2)


* If Erased, Replace with Previous Clean Name *

replace clean_name_2 = clean_name_1 if missing(clean_name_2)


* Label New Variable *

label var clean_name_2 "Name after cleaning non-alphanumeric characters."





********************************************************************************
********************************************************************************
****************************** Condense Acronyms *******************************
********************************************************************************
********************************************************************************

* Generate New Clean Name *

gen clean_name_3 = clean_name_2


* Leading Acronyms * // Here we clean acronyms that appear at the start of a string, i.e. "D O G   CAT   C O W   FOX   R A T" becomes "DOG   CAT   C O W   FOX   R A T"

gen A_B_ = regexs(0) if regexm(clean_name_3, "^(. (. )+)") // The gappy acronym

gen AB_ = subinstr(A_B_, " ", "", .) + " " // Removes all spaces from acronym, then adds one at the end.

replace clean_name_3 = subinstr(clean_name_3, A_B_, AB_, .) if A_B_ != "" // Does the condensing.

drop A_B_ AB_ // No longer needed


* Trailing Acronyms * // Here we clean acronyms that appear at the end of a string, i.e. "D O G   CAT   C O W   FOX   R A T" becomes "D O G   CAT   C O W   FOX   RAT"

gen _Y_Z = regexs(0) if regexm(clean_name_3, "(( .)+ .)$") // The gappy acronym

gen _YZ = " " + subinstr(_Y_Z, " ", "", .) // Removes all spaces from acronym, then adds one at the start.

replace clean_name_3 = subinstr(clean_name_3, _Y_Z, _YZ, .) if _Y_Z != "" // Does the condensing.

drop _Y_Z _YZ  // No longer needed.


* Mid-string Acronyms * // Here we clean acronyms that appear in the middle of a string, i.e. "D O G   CAT   C O W   FOX   R A T" becomes "D OG   CAT   COW   FOX   RA T". This is why we do leading and trailing acronyms first.

gen _M_N_ = regexs(0) if regexm(clean_name_3, " . (. )+") // The gappy acronym

gen _MN_ = " " + subinstr(_M_N_, " ", "", .) + " " // Removes all spaces from acronym, then adds one at each end

replace clean_name_3 = subinstr(clean_name_3, _M_N_, _MN_, .) if _M_N_ != "" // Does the condensing.

drop _M_N_ _MN_ // No longer needed.


* Strip Extraneous Whitespace *

replace clean_name_3 = stritrim(clean_name_3)


* If Erased, Replace with Previous Clean Name *

replace clean_name_3 = clean_name_2 if missing(clean_name_3)


* Label New Variable *

label var clean_name_3 "Name after condensing acronyms."





********************************************************************************
********************************************************************************
**************************** Remove Corporate Terms ****************************
********************************************************************************
********************************************************************************

* Generate New Clean Name *

gen clean_name_4 = clean_name_3


* Loop Through Cleaning *

local loop_switch = 1 // We leave the loop switch on to start with

while(`loop_switch' == 1){ // We run this until no more changes are made. If we ran it only once, then "THE DOG BISCUIT CORP SA DE CV NY" would become "DOG BISCUIT SA DE CV" whereas we just want "DOG BISCUIT"
	
	local loop_switch = 0 // We turn it to zero at the start of a loop
	
	
	** Prefixes **
	
	foreach pref in "THE " "AKTIEBOLAG " "AKTIEBOLAGET " "AB " "KABUSHIKI KAISHA " "KABUSHIKI GAISHA " "GRUPPO " "FIRMA " "SOCIETE ANONYME DITE "{
	
		quietly count if substr(clean_name_4, 1, length("`pref'")) == "`pref'" // Here we get a positive integer in `=r(N)' if a change is due to be made
		
		if(`=r(N)' > 0){ // If a change is due to be made, we turn the loop switch back on
			
			local loop_switch = 1
			
		}
		
		replace clean_name_4 = substr(clean_name_4, length("`pref'") + 1, .) if substr(clean_name_4, 1, length("`pref'")) == "`pref'"
	
	}
	
	
	** THE (Prefix) **
	
	quietly count if substr(clean_name_4, 1, length(" THE")) == "THE " // Here we get a positive integer in `=r(N)' if a change is due to be made
	
	if(`=r(N)' > 0){ // If a change is due to be made, we turn the loop switch back on
		
		local loop_switch = 1
		
	}
	
	replace clean_name_4 = substr(clean_name_4, 5, .) if substr(clean_name_4, 1, 4) == "THE "
	
	
	** Suffixes, List One **
	
	foreach suff in " INC" " INCORPORATED" " CORP" " LTD" " LIMITED LIABILITY COMPANY" " AND CO" " CO" " LP" " CP" " PUBLIC LIMITED COMPANY" " PLC" " TRUST" " ADR" " ADS" " TR" " SA" " SAS" " LLC" " HOLDINGS" " HOLDING" "HLDGS" "HLDG" " ILP" " INTELLECTUAL PROPERTY" " INTELLECTUAL CAPITAL" " LICENSING" " LICENCING" " NEW" " OLD" " COMPANIES" " CORPORATE"{
		
		quietly count if substr(clean_name_4, -1*length("`suff'"), .) == "`suff'" // Here we get a positive integer in `=r(N)' if a change is due to be made
	
		if(`=r(N)' > 0){ // If a change is due to be made, we turn the loop switch back on
			
			local loop_switch = 1
			
		}
		
		replace clean_name_4 = substr(clean_name_4, 1, length(clean_name_4) - length("`suff'")) if substr(clean_name_4, -1*length("`suff'"), .) == "`suff'"
		
	}
	
	
	** State Suffixes **
	
	local states "AL KY OH AK LA OK AZ ME OR AR MD PA AS MA PR CA MI RI CO MN SC CT MS SD DE MO TN DC MT TX FL NE GA NV UT NH VT HI NJ VA ID NM IL NY WA IN NC WV IA ND WI KS WY"
	
	gen lw = word(clean_name_4, -1) // Variable containing last word in string

	gen lwl = length(lw) // Variable containing length of last word in string
	
	quietly count if (strpos("`states'", lw) > 0) & (lwl == 2) & (substr(clean_name_4, -7, 7) != " AND CO") // Here we get a positive integer in `=r(N)' if a change is due to be made
	
	if(`=r(N)' > 0){ // If a change is due to be made, we turn the loop switch back on
		
		local loop_switch = 1
		
	}
	
	replace clean_name_4 = substr(clean_name_4, 1, length(clean_name_4) - 3) if (strpos("`states'", lw) > 0) & (lwl == 2) & (substr(clean_name_4, -7, 7) != " AND CO")
	
	drop lw lwl
	
	
	** Suffixes (List 2) **
	
	foreach suff in " COS" " AG" " KGAA" " AB" " SE" " THE" " COM" " SPA" " LIMITED" " CORPORATION" " COMPANY" " DEL" " GMBH" " SER" " CL A" " CL B" " CL" " COMPAN" " COMP" " PTY" " SARL" " ETS" " ET CIE" " CIE" " COR" " FA" " BV" " SRL" " KG" " KABUSHIKI KAISHA" " KABUSHIKIKAISHA" " KABUSHIKI GAISHA" " KAISHA" " KK" " GAISHA" " OY" " AND" " MBH" " SL" " PTE" " IP" " APS" " LTDA" " SA DE CV" " CV" " VZW" " AKTIENGESELLSCHAFT" " AKTIEBOLAG" " AKTIEBOLAGET" " HOLDING GROUP" " HOLDING GP" " SOCIETE ANONYME" " SOCIETE ANONYME DITE" " GENERALNI REDITALSTVI"{
		
		quietly count if substr(clean_name_4, -1*length("`suff'"), .) == "`suff'" // Here we get a positive integer in `=r(N)' if a change is due to be made
	
		if(`=r(N)' > 0){ // If a change is due to be made, we turn the loop switch back on
			
			local loop_switch = 1
			
		}
		
		replace clean_name_4 = substr(clean_name_4, 1, length(clean_name_4) - length("`suff'")) if substr(clean_name_4, -1*length("`suff'"), .) == "`suff'"
		
	}
	
}

* Removing Words from Middle of String *

// We now remove the above from the middle of the string. This is because we might wish to retain the "CANADA" in "DOGS CO CANADA", but would like to remove "CO". The exception here is "DE" which appears frequently but is "de" as in "of" in French/Spanish. Terms that do not make any changes are omitted from the code.

foreach mid_word in " INC "" CORP " " LTD " " AND CO " " CO " " SER A " " LP " " CP " " TRUST " " TR " " SA " " LLC " " COS " " AG " " AB " " SE " " THE " " COM " " SPA " " LIMITED " " COMPANY " " GMBH " " SER " " CL " " COMPAN " " COMP " " PTY " " SARL " " ETS " " ET CIE " " CIE " " COR " " FA " " CORPORATION " " INCORPORATED " " CORPO "{
	
	replace clean_name_4 = subinstr(clean_name_4, "`mid_word'", " ", .)
	
}


* Strip Extraneous Whitespace *

replace clean_name_4 = stritrim(clean_name_4)


* If Erased, Replace with Previous Clean Name *

replace clean_name_4 = clean_name_3 if missing(clean_name_4)


* Label New Variable *

label var clean_name_4 "Name after removing standardised corporate terms."





********************************************************************************
********************************************************************************
******************************* Map Abbreviations ******************************
********************************************************************************
********************************************************************************

* Get New Name Variable *

gen clean_name_5 = clean_name_4


* Loop Through (Reverse) Mappings *

foreach mapping in  "BRND:BRAND,BRANDS" "INT:INTERNATIONAL,INTERN,INTL" "SVCS:SERVICES" "GP:GROUP,GRP,GR" "PWR:POWER" "MFG:MANUFACTURING,MANUF" "SYS:SYSTEMS,SYSTEM,SYST" "RES:RESOURCES" "ASSD:ASSOCIATED" "DEV:DEVELOPMENT" "IVT:INVESTMENT,INVESTMENTS,INVT,INVS" "MGMT:MANAGEMENT" "PROD:PRODUCTS,PRODS" "CAN:CANADA,CDA" "US:USA,AM,AMERICA,AMER" "PPTYS:PROPERTIES" "ASS:ASSOCIATION,ASSOC,ASSN" "SVC:SERVICE" "COMM:COMMUNICATIONS,COMMUNICATION" "ENTMT:ENTERTAINMENT" "TELECOM:TELECOMMUNICATIONS,TELECOMM" "PRTNRS:PARTNERS" "EXPL:EXPLORATION,EXPLORATIONS" "INS:INSURANCE" "AMERN:AMERICAN" "NATL:NATIONAL" "CMNTY:COMMUNITIES,COMMUN,COMMUNITY" "BK:BANK,BANC" "SVGS:SAVINGS" "CHEM:CHEMICALS,CHEMICAL" "REALTY:RLTY" "SOLTNS:SOLUTIONS" "TRANS:TRANSPORT,TRANSPRT,TRNSPRT" "FIN:FINANCE,FINANCIAL,FINL" "1ST:FIRST" "2ND:SECOND" "3RD:THIRD" "4TH:FOURTH" "5TH:FIFTH" "6TH:SIXTH" "DRUG:DRUGS" "TECH:TECHNOLOGY,TECHNOLOGIES" "LAB:LABORATORIES,LABORATORY,LABS,LABO" "BROS:BROTHERS" "ELEC:ELECTRICAL,ELECTRIC" "COMML:COMMERCIAL" "CONS:CONSOLIDATED" "IND:INDUSTRIES,INDUSTRIAL,INDS,INDUSTRIE,INDUSTRY" "INSTR:INSTRUMENT,INSTRUMENTS" "SOC:SOCIETY,SOCIEDAD,SOCIETE,STE" "GEN:GENERAL" "ENTPR:ENTERPRISE,ENTERPRISES" "ENG:ENGINEERING" "HEALTHCARE:HEALTH CARE" "N AM:NORTH US,N US" "US:UNITED STATES,US OF US,OF US" "RE:REAL ESTATE" "PHARM:PHARMACEUTICALS,PHARMA,PHARMACEUTICAL" "ORG:ORGANISATION,ORGANIZATION"{
	
	
	** Extract Abbreviation to Substitute in **
	
	local subin `=substr("`mapping'", 1, strpos("`mapping'", ":") - 1)' // Extracts everything in the string before the colon
	
	local _subin = " " + "`subin'"
	
	local subin_ = "`subin'" + " "
	
	local _subin_ = " " + "`subin'" +  " " // Used when the abbrevation we want to map is neither the first nor the last word of clean_name_5
	
	
	** Subsitution, 1:1 Mappings **
	
	if(strpos("`mapping'", ",") == 0){
	
		local subout `=substr("`mapping'", strpos("`mapping'",":") + 1, .)' // Extracts everything in the string after the colon
		
		local _subout = " " + "`subout'"
		
		local subout_ = "`subout'" + " "
		
		local _subout_ = " " + "`subout'" + " "
		
		replace clean_name_5 = subinstr(clean_name_5, "`_subout_'", "`_subin_'", .) // Handles unabbreviated terms in the middle of the string
		
		replace clean_name_5 = "`subin_'" + substr(clean_name_5, length("`subout_'") + 1, .) if strpos(clean_name_5, "`subout_'") == 1 // Handles unabbreviated terms that are the first word of multiple
		
		replace clean_name_5 = substr(clean_name_5, 1, length(clean_name_5) - length("`_subout'")) + "`_subin'" if strpos(clean_name_5, "`_subout'") == length(clean_name_5) - length("`_subout'") + 1 & strpos(clean_name_5, "`_subout'") != 0 // Handles unabbreviated terms that are the last word of multiple
		
	}
	
	
	** Substitution, m:1 Mappings **
	
	if(strpos("`mapping'", ",") > 0){
		
		local nr_commas = `=length("`mapping'")' - `=length(subinstr("`mapping'", ",", "", .))' // A bit of chicanery to work out the number of commas
		
		local nr_mappings = `nr_commas' + 1 // There will be one more mapping than there are commas
		
		local comma0_pos = `=strpos("`mapping'", ":")' // We put "Comma 0" at the position of the colon
		
		forvalues i = 1/`nr_commas'{
			
			local iMinus1 = `i' - 1 // Pretty self-explanatory this one.
			
			local comma`i'_pos = `=strpos(substr("`mapping'", `comma`iMinus1'_pos' + 1, .), ",")' + `comma`iMinus1'_pos' // Returns the position of the first comma in the string that follows the previous comma
				
		}
		
		local comma`nr_mappings'_pos = length("`mapping'") + 1 // We put "Comma N" at the position right after the string ends
		
		forvalues j = 1/`nr_mappings'{
			
			local jMinus1 = `j' - 1
			
			local subout `=substr("`mapping'", `comma`jMinus1'_pos' + 1, `comma`j'_pos' - `comma`jMinus1'_pos' - 1)'
		
			local _subout = " " + "`subout'"
			
			local subout_ = "`subout'" + " "
			
			local _subout_ = " " + "`subout'" + " "
			
			replace clean_name_5 = subinstr(clean_name_5, "`_subout_'", "`_subin_'", .) // Handles unabbreviated terms in the middle of the string
			
			replace clean_name_5 = "`subin_'" + substr(clean_name_5, length("`subout_'") + 1, .) if strpos(clean_name_5, "`subout_'") == 1 // Handles unabbreviated terms that are the first word of multiple
			
			replace clean_name_5 = substr(clean_name_5, 1, length(clean_name_5) - length("`_subout'")) + "`_subin'" if strpos(clean_name_5, "`_subout'") == length(clean_name_5) - length("`_subout'") + 1 & strpos(clean_name_5, "`_subout'") != 0 // Handles unabbreviated terms that are the last word of multiple
			
		}
		
	}
	
}


* Strip Extraneous Whitespace *

replace clean_name_5 = stritrim(clean_name_5)


* Drop Dangling Terms *

replace clean_name_5 = substr(clean_name_5, 1, length(clean_name_5) - length(" AND")) if strpos(clean_name_5, " AND") == length(clean_name_5) - 2 & strpos(clean_name_5, " AND") != 0

replace clean_name_5 = substr(clean_name_5, 1, length(clean_name_5) - length(" OF")) if strpos(clean_name_5, " OF") == length(clean_name_5) - 1 & strpos(clean_name_5, " OF") != 0


* If Erased, Replace with Previous Clean Name *

replace clean_name_5 = clean_name_4 if missing(clean_name_5)


* Label New Variable *

label var clean_name_5 "Name after mapping standard terms to their abbreviations."





********************************************************************************
********************************************************************************
************************** Remove Remaining Whitespace *************************
********************************************************************************
********************************************************************************

* Get New Name Variable *

gen clean_name_6 = clean_name_5


* Strip out all whitespace *

replace clean_name_6 = subinstr(clean_name_6, " ", "", .)


* If Erased, Replace with Previous Clean Name *

replace clean_name_6 = clean_name_5 if missing(clean_name_6)


* Label New Variable *

label var clean_name_6 "Name after removing *all* whitespace"