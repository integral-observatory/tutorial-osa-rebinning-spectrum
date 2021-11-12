## Standard recommendation

For the standard procedure, it is advised to select bins in advance and follow the manual and the present tutorial.

## Providing energy bins

Several ways to provide energy bins are described in the IBIS manual. Note that it is possible provide bins which are too narrow to not allow adequate generation of the response, since response is stored in "standard" 256 bins.

## Rebinning narrow-bin ISGRI spectra

It is possible to re-group finely binned spectrum. For example, one might want to produce 256 bins (which is more sane than 2048) and re-group for presentation. 

Notably, in the case of a short events (like GRBs) which reach low-count statistics it is even possible to avoid large part of the reconstruction process (which is made to more naturally combine observations from different off-axis angles, times, etc) and do forward folding from model through response directly to time-tagged events (like I did for SGR1935). This is useful for fine time structures, for example.


## ISGRI spectra extraction in narrow bins

The fitting routine in `ii_spectra_extract` more or less adequately deals with small lambda. The approach it uses is somewhat convoluted but it 
was tentatively previously checked with normal pure Poisson assumption, which is the right way in low counts regime. 
Uncertainty on this cased some confusion in manuals and the code. It's usually irrelevant.

It would be a problem if this did not work, since number of counts in each data point (pixel,time-bin,energy-bin) is almost always small enough to require Poisson.

Remarkably, even if gaussian assumption is used in indivudal pixels/energy bins, if the results are later combined by the gaussial rules, and the final bin has enough counts to justify total gaussian, this artifical procedure may universally lead to precise results (TODO: to show mathematically)

However, spectrum for 2048 channels takes unreasonable amount of time to produce, roughly proportional to the number of bins (i.e. 100 times more than 20 bin).

Grouping the resulting spectrum to reach desired total number of counts is not straightforward since what is written in ISGRI spectra is not counts or regular rate. 
The are background-subtracted and corrected by various efficiencies (vignetting, per-pixel variations and time gaps).
See also [note on meaning of ISGRI count rates](https://github.com/integral-observatory/integral-isgri-rate-meaning).
What matters for the difference between Poisson and Gauss is not source counts, but total counts. These total counts are written in the isgri_detector_shadowgram.fits files in scw. I added for curiosity. It does not really get to the Poisson level except on GTI of second-length with sub-keV energy bins. 

In any case, adaptive binning by S/N is rarely useful, except just for visualization. This sort of grouping can be done during visualization e.g. xspec. In this case, xspec correctly does not use the adaptive rebinning for fitting.

## Rebinning vs full-information fitting

The question of role of optimal grouping is somewhat debated. In principle, grouping kills information, so it's normally not useful. But it can also strategically redistribute some information, with desirable effects. You could achieve  the same effects without rebinning, but it's trickier.

See some details in https://arxiv.org/abs/1601.05309


