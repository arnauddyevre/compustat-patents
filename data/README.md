# compustat-patents\data

___

This subdirectory contains our static match of gvkeys to patents - *static.csv*. It also contains the "effective acquisition" events used to facilitate the dynamic reassignment of patents - *dynamic.csv*.

### *static.csv*

This dataset contains 8,315,311 patents granted by the United States Patent and Trademark Office (USPTO) in the years 1926-2020. Where appropriate, patents are matched to a Compustat gvkey according to the year of application.

#### Use of *gvkey* and *gvkey*-like Firm Identifiers

In *static.csv*, each patent is associated with one or two firm identifiers (possibly identical in value)...
- **gvkeyUO**, or "ultimate owner gvkey", is the sole firm identifier required where a researcher only studies firm-level innovation as it occurs. It identifies the ultimate owner of the applicant firm at the time of application. *gvkeyUO* maps directly into Compustat. If the ultimate owner of the patent is not active in Compustat at the time of application, the *gvkeyUO* is missing.
- **gvkeyFR**, or "gvkey for reassignment", is the additional firm identifier required where a researcher studies a firm's stock of intellectual property at a given time, or over time. It is a *gvkey*-like firm identifier; each gvkeyFR can be mapped to the appropriate ("ultimate owner") gvkey in Compustat in a given year using the dataset *dynamic.csv*.

#### Dataset Variables for *static.csv*

- **patent_id** - USPTO patent number.
- **appYear** - The year the patent application was submitted to the USPTO.
- **gvkeyUO** - "ultimate owner gvkey": the Compustat *gvkey* of the ultimate owner (at time of application) of the firm that is the patent's immediate assignee.
- **gvkeyFR** - "gvkey for reassignment": the *gvkey*-like identifier of the firm that is the patent's immediate assignee.
- **clean_name** - The (cleaned) firm name associated with the patent's immediate assignee.
- **cnLink_y1** - The first year for which we map the given *clean_name* to the given *gvkeyFR* and (where applicable) given *gvkeyUO*.
- **cnLink_yN** - The last year for which we map the given *clean_name* to the given *gvkeyFR* and (where applicable) given *gvkeyUO*.
- **privateSubsidiary** - Indicator that the patent is matched to a *gvkeyFR* via a privately-held subsidiary.
- **grantYear** - The year the patent was granted by the USPTO.

### *dynamic.csv*

This dataset contains mappings from *gvkeyFR* to *gvkey*, capturing firm ownership (and therefore patent ownership). This allows researchers to determine the ultimate owner of a patent at any given point in time. We construct this from our data on "effective acquistions" of one *gvkey* by another (more below).

#### Dataset Variables for *dynamic.csv*

- **gvkeyFR** - The "gvkey for reassignment"; a *gvkey*-like firm identifier of the firm ultimately owned by *gvkey* from *year1* to *yearN*.
- **gvkey** - The "ultimate owner gvkey" whose ownership of the gvkey-like identifier *gvkeyFR* is effective from *year1* to *yearN*.
- **year1** - The first year for which patents attributed to *gvkeyFR* are ultimately owned by *gvkey*. 
- **yearN** - The first year for which patents attributed to *gvkeyFR* are ultimately owned by *gvkey*.

#### "Effective Acquisitions"

For the above, an "effective acquisition" can refer to one of many instances of M&A activity or corporate restructuring...
- **True Acquisition**: suppose firm ALPHA (gvkey 000001) acquires firm BETA (gvkey 000002). We then say that gvkey 000001 "effectively acquires" gvkey 000002.
- **Merger**: suppose firm CHARLIE (gvkey 000003) merges with firm DELTA (gvkey 000004). Both firms are listed prior to the merger; the merged firm trades under gvkey 000004 following the merger; gvkey 000003 is discontinued following the merger. We then say that gvkey 000004 "effectively acquires" gvkey 000003.
- **Relisting**: suppose firm ECHO trades under gvkey 000005. It then de-lists, before later re-listing under gvkey 000006. We then say that gvkey 000006 "effectively acquires" gvkey 000005
- **Subsidiary Spin-off**: suppose firm FOXTROT trades under gvkey 000007. Firm FOXTROT's subsidiary, firm GOLF, is at some point spun-off and begins to trade under gvkey 000008. For patent reassignment purposes, this necessitates two effective acquisitions:
    - In the year that gvkey 000007 enters Compustat, we say that gvkey 000007 "effectively acquires" gvkey 000008. 
        - At this point, gvkey 000008 is not active in Compustat. However, this allows patents assigned to the name "GOLF", associated with gvkey 000008, to be re-assigned to gvkey 000007 until the spin off.
    - In the year in which firm GOLF is spun off, we say that gvkey 000008 "effectively acquires" itself. 
        - From this year onward, all patents assigned to the name "GOLF" will be re-assigned from gvkey 000007 to gvkey 000008. Patents assigned to the name "FOXTROT" will remain assigned to gvkey 000007.
- **Reverse Spin-off**: Suppose firm HOTEL initially trades under gvkey 000009. Its subsidiary, JULIET, is later spun-off but itself retains the listing associated with gvkey 000009 Compustat. The former parent, HOTEL, now trades under gvkey 000010. We resolve this by splitting the firm into two *gvkeyFR*s, with the reverse spin-off necessitating two separate effective acquisitions:
    - We permanently associate the name "JULIET" with gvkeyFR "000009"
    - We permanently associate the name "HOTEL" with gvkeyFR "000009A"
    - In the year that HOTEL lists under gvkey 000009, we say that gvkey_uo 000009 "effectively acquires" gvkeyFR "000009A".
    - In the year that the reverse spin-off takes place, we say that gvkey_uo 000010 "effectively acquires" gvkeyFR "000009A".