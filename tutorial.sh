# This tutorial shows how to derive ISGRI spectrum in peculiar custom.
#
# This tutorial is provided as constributed material, complementing IBIS manual. 
# Please address the manual for details: https://www.isdc.unige.ch/integral/download/osa/doc/11.1/osa_um_ibis/node41.html). 
# In the future, this tutorial may be partially absorbed in the manual.

# There are 3 ways to define energy bins https://www.isdc.unige.ch/integral/download/osa/doc/11.1/osa_um_ibis/node41.html
# one of them is suitable when using

# please refer to heasoft manual on how to construct this bin definition
# https://heasarc.gsfc.nasa.gov/docs/software/ftools/caldb/rbnrmf.html
cat > bins.txt <<HERE
 0   9   -1
 10  409  8
 410 2047 -1
HERE

# check your heasoft versions. Note that between versions 6.24 and 6.28, there was a rapid evolution of this particular functionality in Heasoft. 
# This tutorial applies to 6.24. You 
fversion

# original matrix has 2048 channel bins
fstruct $REP_BASE_PROD/ic/ibis/rsp/isgr_rmf_grp_0025.fits[ISGR-EBDS-MOD]

new_rmf_fn=$PWD/new-rmf.fits

rbnrmf \
    infile="$REP_BASE_PROD/ic/ibis/rsp/isgr_rmf_grp_0025.fits" \
    outfile=$new_rmf_fn \
    binfile="bins.txt" \
    clobber=yes

# original matrix has 2048 channel bins
fstruct $new_rmf_fn[ISGR-EBDS-MOD]


# analyse the spectrum with these bins

export scw=198700220010.001

ls $REP_BASE_PROD/scw/${scw::4}/$scw/swg.fits > scws.txt

rm -rfv obs/test-bins

export COMMONLOGFILE=+$PWD/commonlog.txt
export COMMONSCRIPT=1

og_create \
    idxSwg=scws.txt \
    instrument=ibis \
    ogid=test-bins \
    baseDir=$PWD

(
    cd obs/test-bins
    ibis_science_analysis \
        startLevel=COR \
        endLevel=SPE \
        IBIS_SI_inEnergyValues=$new_rmf_fn[ISGR-EBDS-MOD]
)

fstruct obs/test-bins/scw/$scw/isgri_spectrum.fits[2]
