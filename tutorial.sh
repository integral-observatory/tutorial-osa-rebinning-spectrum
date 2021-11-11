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


export T1=2020-04-10T18:35:35.124
export T2=2020-04-10T18:35:36.124
export scw=$(converttime UTC 2020-04-10T18:35:36.124 SCWID | awk '{print $NF}').001

export ebin_compression_factor=${ebin_compression_factor:-8}
export ogid=test-bins-$ebin_compression_factor

echo "test scw: $scw"

user_rmf_fn=$PWD/new-rmf.fits
user_gti_fn=$PWD/user_gti.fits

function construct_broad_bin_rmf {
    # The question of role of optimal grouping is somewhat debated. 
    # Grouping kills information, so it's normally not useful. But it can also strategically hide some information, with desirable effects.
    # See some details in https://arxiv.org/abs/1601.05309

    # Grouping Except just for visualization. You can also do this exact kind of grouping in xspec.
    # 9 counts is not enough to use gaussian approximation. Also this sort of adapting grouping creates bins as random process, which makes it difficult to combine them later

    cat > bins.txt <<HERE
     0   9   -1
     10  137  $ebin_compression_factor
     138 255 -1
HERE

# check your heasoft versions. Note that between versions 6.24 and 6.28, there was a rapid evolution of this particular functionality in Heasoft. 
# This tutorial applies to 6.24. You 
    fversion

# let's use 256 channel rsp, tracing ISGRI energy resolution. It's stored in two parts
    rm -fv orig_rsp.fits
    fcopy $REP_BASE_PROD/ic/ibis/rsp/isgr_ebds_mod_0002.fits orig_rsp.fits
    fappend $REP_BASE_PROD/ic/ibis/rsp/isgr_rmf_rsp_0041.fits orig_rsp.fits

    fstruct orig_rsp.fits[ISGR-EBDS-MOD]

    rbnrmf \
        infile="orig_rsp.fits" \
        outfile=$user_rmf_fn \
        binfile="bins.txt" \
        clobber=yes

    # original matrix has 2048 channel bins
    fstruct $user_rmf_fn[ISGR-EBDS-MOD]

}

function in_broad_bins {

    # analyse the spectrum with these bins
    construct_broad_bin_rmf
    create_gti


    ls $REP_BASE_PROD/scw/${scw::4}/$scw/swg.fits > scws.txt

    rm -rfv obs/$ogid

    export COMMONLOGFILE=+$PWD/commonlog.txt
    export COMMONSCRIPT=1

# Standard OSA

    og_create \
        idxSwg=scws.txt \
        instrument=ibis \
        ogid=$ogid \
        baseDir=$PWD

    (
        cd obs/$ogid
        ibis_science_analysis \
            startLevel=COR \
            endLevel=SPE \
            IBIS_SI_inEnergyValues="$user_rmf_fn[ISGR-EBDS-MOD]" \
            SCW1_GTI_gtiUserI=$user_gti_fn
    )

# Inspect the spectrum  and make sure it has the desired number of bins

    fstruct obs/$ogid/scw/$scw/isgri_spectrum.fits[2]
}


function create_gti {
    rm -fv $user_gti_fn

    gti_user \
        begin=$T1 \
        end=$T2 \
        gti=$user_gti_fn
}

function inspect_spectra {
    ( cut -c5- | python ) <<HERE
    from astropy.io import fits
    f = fits.open("obs/$ogid/scw/$scw/isgri_spectrum.fits")
    d = f[3]
    print("RATE:", d.data['RATE'])
    print("EXPOSURE", d.header['EXPOSURE'])
    print("RATE*EXPOSURE", d.data['RATE']*d.header['EXPOSURE'])

    for shad in fits.open("obs/$ogid/scw/$scw/isgri_detector_shadowgram.fits")[2:]:
        print(shad.header['E_MIN'], shad.header['E_MAX'], shad.data.sum())
HERE
}


function inspect_two_spectra {
    # this requires two prior runs with compression 8 and 4
    # it checks verifies that regroupping spectral bins after the spectral extraction
    # is equivalent to extraction is broader bins 

    ( cut -c5- | python ) <<HERE

    import numpy as np
    from astropy.io import fits

    bycomp = {}

    for comp in [4, 8]:
        bycomp[comp] = {}

        for d in fits.open(f"obs/test-bins-{comp}/scw/$scw/isgri_spectrum.fits"):
            if d.header.get('NAME') == "Crab":
                break
            else:
                d = None

        bycomp[comp]['rate'] = d.data['RATE']
        bycomp[comp]['rate_err'] = d.data['STAT_ERR']
        bycomp[comp]['exposure'] = d.header['EXPOSURE']
        bycomp[comp]['counts'] = d.data['RATE']*d.header['EXPOSURE']
        bycomp[comp]['counts_err'] = d.data['STAT_ERR']*d.header['EXPOSURE']*d.header['EXPOSURE']
    
        bycomp[comp]['e_min'] = []
        bycomp[comp]['e_max'] = []
        bycomp[comp]['detcounts'] = []
        for shad in fits.open(f"obs/test-bins-{comp}/scw/$scw/isgri_detector_shadowgram.fits")[2:]:
            if shad.header.get('ISDCLEVL') == 'BIN_S':
                bycomp[comp]['detcounts'].append(shad.data.sum())
                bycomp[comp]['e_min'].append(shad.header['E_MIN'])
                bycomp[comp]['e_max'].append(shad.header['E_MAX'])

        bycomp[comp]['detcounts'] = np.array(bycomp[comp]['detcounts'])
        bycomp[comp]['e_min'] = np.array(bycomp[comp]['e_min'])
        bycomp[comp]['e_max'] = np.array(bycomp[comp]['e_max'])

    # let's just pick one
    i_base = 15
    m_4 = np.zeros_like(bycomp[4]['rate'], dtype=bool)
    m_4[i_base*2:i_base*2 + 2] = True

    m_8 = np.zeros_like(bycomp[8]['rate'], dtype=bool)
    m_8[i_base:i_base + 1] = True 

    print("x", m_4.shape, bycomp[4]['e_max'].shape)

    print("4 comp, E_MIN, E_MAX", bycomp[4]['e_min'][m_4], bycomp[4]['e_max'][m_4])
    print("8 comp, E_MIN, E_MAX", bycomp[8]['e_min'][m_8], bycomp[8]['e_max'][m_8])
    print("4 comp, detcounts", bycomp[4]['detcounts'][m_4])
    print("8 comp, detcounts", bycomp[8]['detcounts'][m_8])
    print("4 comp, counts counts_err", bycomp[4]['counts'][m_4], bycomp[4]['counts_err'][m_4])

    regroupped_counts = bycomp[4]['counts'][m_4].sum()
    regroupped_counts_err = (bycomp[4]['counts_err'][m_4]**2).sum()**0.5

    print("4 comp regrouping produced spectrum", regroupped_counts, regroupped_counts_err)
    print("8 comp, counts counts_err", bycomp[8]['counts'][m_8], bycomp[8]['counts_err'][m_8])

    # in the given example, the difference is 0.04%
    print("relative difference between regrouped counts", (regroupped_counts/bycomp[8]['counts'][m_8] - 1) )

HERE
}

if [ -z $@ ]; then
    echo 'please pick one of the following commands:'
    cat "${BASH_SOURCE[0]}" | awk '/^function/ {print " * bash '"${BASH_SOURCE[0]}"' "$2}'
else
    $@
fi
