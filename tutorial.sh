# This tutorial shows how to derive ISGRI spectrum in peculiar custom.
#
# This tutorial is provided as constributed material, complementing IBIS manual. 
# Please address the manual for details: https://www.isdc.unige.ch/integral/download/osa/doc/11.1/osa_um_ibis/node41.html). 
# In the future, this tutorial may be partially absorbed in the manual.

# There are 3 ways to define energy bins https://www.isdc.unige.ch/integral/download/osa/doc/11.1/osa_um_ibis/node41.html
# one of them is suitable when using

# please refer to heasoft manual on how to construct this bin definition
# https://heasarc.gsfc.nasa.gov/docs/software/ftools/caldb/rbnrmf.html

set -e

[ -z ${ISDC_ENV+x} ] && { echo "no ISDC_ENV!"; exit 1; }
ibis_isgr_energy --version | grep 9.1.2 > /dev/null || { echo "old ibis_isgr_energy!"; exit 1; }

    

# test case
export scw=221500540010.001


function construct_broad_bin_rmf {
    # The question of role of optimal grouping is somewhat debated. 
    # Grouping kills information, so it's normally not useful. But it can also strategically hide some information, with desirable effects.
    # See some details in https://arxiv.org/abs/1601.05309

    # Grouping Except just for visualization. You can also do this exact kind of grouping in xspec.
    # 9 counts is not enough to use gaussian approximation. Also this sort of adapting grouping creates bins as random process, which makes it difficult to combine them later

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

}

function in_broad_bins {

# analyse the spectrum with these bins
    construct_broad_bin_rmf


    ls $REP_BASE_PROD/scw/${scw::4}/$scw/swg.fits > scws.txt

    rm -rfv obs/test-bins

    export COMMONLOGFILE=+$PWD/commonlog.txt
    export COMMONSCRIPT=1

# Standard OSA

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
            IBIS_SI_inEnergyValues="$new_rmf_fn[ISGR-EBDS-MOD]"
    )

# Inspect the spectrum  and make sure it has the desired number of bins

    fstruct obs/test-bins/scw/$scw/isgri_spectrum.fits[2]
}


function inspect_spectra {
    ( cut -c5- | python ) <<HERE
    from astropy.io import fits
    f = fits.open("obs/test-bins/scw/$scw/isgri_spectrum.fits")
    d = f[3]
    print(d.data['RATE'])
    
    print(d.data['RATE']*d.header['EXPOSURE'])
HERE
}

if [ -z $@ ]; then
    echo 'please pick one of the following commands:'
    cat "${BASH_SOURCE[0]}" | awk '/^function/ {print " * bash '"${BASH_SOURCE[0]}"' "$2}'
else
    $@
fi
