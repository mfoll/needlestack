#!/bin/sh

usage ()
{
    echo ""
    echo "--------------------------------------------------------"
    echo "NEEDLESTACK v1.0b: A MULTI-SAMPLE SOMATIC VARIANT CALLER"
    echo "--------------------------------------------------------"
    echo "Copyright (C) 2015 Matthieu Foll and Tiffany Delhomme"
    echo "This program comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt"
    echo "This is free software, and you are welcome to redistribute it"
    echo "under certain conditions; see LICENSE.txt for details."
    echo "--------------------------------------------------------"
    echo ""
    echo "Usage: "
    echo "    ./needlestack.sh --region=chrX:pos1-pos2 --bam_folder=BAM/ --fasta_ref=reference.fasta [other options]"
    echo ""
    echo "Mandatory arguments:"
    echo "    --bam_folder     BAM_DIR                  BAM files directory."
    echo "    --fasta_ref      REF_IN_FASTA             Reference genome in fasta format."
    echo "    OR "
    echo "    --input_vcf      VCF FILE                 VCF file (basically from GATK pipeline) to annotate."
    echo "Options:"
    echo "    --min_dp         INTEGER                  Minimum median coverage (in addition, min_dp in at least 10 samples)."
    echo "    --min_ao         INTEGER                  Minimum number of non-ref reads in at least one sample to consider a site."
    echo "    --min_qval       VALUE                    Qvalue in Phred scale to consider a variant."
    echo "    --sb_type        SOR or RVSB              Strand bias measure."
    echo "    --sb_snv         VALUE                    Strand bias threshold for SNVs."
    echo "    --sb_indel       VALUE                    Strand bias threshold for indels."
    echo "    --power_min_af   VALUE                    Minimum allelic fraction for power computations."
    echo "    --sigma_normal   VALUE                    Sigma parameter for negative binomial modeling germline mutations."
    echo "    --map_qual       VALUE                    Samtools minimum mapping quality."
    echo "    --base_qual      VALUE                    Samtools minimum base quality."
    echo "    --max_DP         INTEGER                  Samtools maximum coverage before downsampling."
    echo "    --use_file_name                           Sample names are taken from file names, otherwise extracted from the bam file SM tag."
    echo "    --all_SNVs                                Output all SNVs, even when no variant found."
    echo "    --extra_robust_gl                         Perform an extra robust regression, basically for germline variants"
    echo "    --do_plots                                Output PDF regression plots."
    echo "    --do_alignments                           Add alignment plots."
    echo "    --no_labels                               Do not add labels to outliers in regression plots."
    echo "    --no_indels                               Do not call indels."
    echo "    --no_contours                             Do not add contours to plots and do not plot min(AF)~DP."
    echo "    --out_folder     OUTPUT FOLDER            Output directory, by default input bam folder."
    echo "    --region         CHR:START-END            A region for calling."
    echo "    --pairs_file     TEXT FILE                A tab-delimited file containing two columns (normal and tumor sample name) for each sample in line."
    echo "    --ref_genome                     Reference genome for alignments plot"
    echo ""

}


min_dp=30 : minimum median coverage to consider a site
min_ao=3 : minimum number of non-ref reads in at least one sample to consider a site
min_qval=50 : qvalue in Phred scale to consider a variant
sb_type="SOR" : strand bias measure to be used: "SOR" or "RVSB"
case $sb_type in 
	SOR|RVSB)
		sb_snv=100 : strand bias threshold for snv
		sb_indel=100 : strand bias threshold for indels
		;;
	*)
		sb_snv=1000 : strand bias threshold for snv
		sb_indel=1000 : strand bias threshold for indels
		;;
esac
power_min_af=-1 : minimum allelic fraction for power computations
sigma_normal=0.1 : sigma parameter for negative binomial modeling germline mutations
map_qual=0 : min mapping quality, passed to samtools
base_qual=13 : min base quality, passed to samtools
max_DP=50000 : downsample coverage per sample, passed to samtools
use_file_name=false : put these argument to use the bam file names as sample names and do not to use the sample name filed from the bam files \(SM tag\)
all_SNVs=false :  output all sites, even when no variant is detected
extra_robust_gl=false :  perform an extra robust regression basically for germline variants

pairs_file="FALSE" : by default R will get a false boolean value for pairs_file option

do_plots="ALL"
do_alignments=false : do not produce alignment plots in the pdf
no_indels=false : do not skip indels
no_labels=false : label outliers
no_contours=false : add contours to the plots and plot minAF\~DP

#arguments parsing
while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        --fasta_ref)
            fasta_ref=$VALUE
            fasta_ref_fai=$fasta_ref'.fai' 
			fasta_ref_gzi=$fasta_ref'.gzi' 
            ;;
        --base_qual)
            base_qual=$VALUE
            ;;
        --map_qual)
            map_qual=$VALUE
            ;; 
        --max_DP)
            max_DP=$VALUE
            ;;
        --no_indels)
            no_indels=$VALUE
            ;;
        --min_ao)
            min_ao=$VALUE
            ;;
        --pairs_file)
            pairs_file=$VALUE
            if [ $pairs_file != "FALSE" ]; then
				if [ ! -e "$pairs_file" ]; then
					echo "ERROR : input tumor-normal pairs file not located in execution directory, exit" 
					exit
				fi
				do_plots="SOMATIC"  : produce pdf plots of regressions for somatic variants
			fi
            ;;
        --do_plots)
            do_plots=$VALUE
            ;;
        --bam_folder)
            bam_folder=$VALUE
            ;;
        --ref_genome)
            ref_genome=$VALUE
            ;;
        --input_vcf)
            input_vcf=$VALUE
            ;;
        --min_dp)
            min_dp=$VALUE
            ;;
        --min_qval)
            min_qval=$VALUE
            ;;
        --sb_type)
            sb_type=$VALUE
            ;;  
        --sb_snv)
            sb_snv=$VALUE
            ;;
        --sb_indel)
            sb_indel=$VALUE
            ;;
        --min_qval)
            min_qval=$VALUE
            ;;
        --power_min_af)
            power_min_af=$VALUE
            ;;  
        --sigma_normal)
            sigma_normal=$VALUE
            ;;
        --use_file_name)
            use_file_name=$VALUE
            ;;
        --all_SNVs)
            all_SNVs=$VALUE
            ;;
        --extra_robust_gl)
            extra_robust_gl=$VALUE
            ;;  
        --do_alignments)
            do_alignments=$VALUE
            ;;
        --no_labels)
            no_labels=$VALUE
            ;;           
        --no_contours)
            no_contours=$VALUE
            ;;
        --out_folder)
            out_folder=$VALUE
            ;;
        --region)
            region=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

#parameters info
echo ''
echo '--------------------------------------------------------'
echo 'NEEDLESTACK v1.0b: A MULTI-SAMPLE SOMATIC VARIANT CALLER'
echo '--------------------------------------------------------'
echo 'Copyright (C) 2015 Matthieu Foll and Tiffany Delhomme'
echo 'This program comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt'
echo 'This is free software, and you are welcome to redistribute it'
echo 'under certain conditions; see LICENSE.txt for details.'
echo '--------------------------------------------------------'
if [ $pairs_file = "FALSE" ]; then
	echo "Perform a tumor-normal somatic variant calling (--pairs_file)   : no" 
else
	echo "Perform a tumor-normal somatic variant calling (--pairs_file)   : yes (file $pairs_file)" 
fi
echo "!!!!! $pairs_file"
echo "To consider a site for calling:"
echo "     minimum median coverage (--min_dp)                         : $min_dp"
echo "     minimum of alternative reads (--min_ao)                    : $min_ao"
echo "Phred-scale qvalue threshold (--min_qval)                       : $min_qval"

if [ -z $out_folder ];then out_folder=$bam_folder ;fi 

case $do_plots in 
	ALL)
		echo "PDF regression plots (--do_plots)                               : ALL"
		;;
	SOMATIC)
		echo "PDF regression plots (--do_plots)                               : SOMATIC"
		;;
	NONE)
		echo "PDF regression plots (--do_plots)                               : NONE"
		;;
	*)
		echo "option not reconized for --do_plots (SOMATIC,ALL or NONE)"
		;;
esac

if [ $do_alignments = true ]; then
	echo "Alignment plots (--do_alignments)                               : yes" 
else
	echo "Alignment plots (--do_alignments)                               : no" 
fi

if [ $no_labels = true ]; then
	echo "Labeling outliers in regression plots (--no_labels)             : no" 
else
	echo "Labeling outliers ibooleann regression plots (--no_labels)      : yes"
fi

if [ $no_contours = true ]; then
	echo "Add contours in plots and plot min(AF)~DP (--no_contours)       : no"
else
	echo "Add contours in plots and plot min(AF)~DP (--no_contours)       : yes"
fi

if [ $use_file_name = true ];then
	sample_names="FILE" 
else
	sample_names="BAM" 
fi
if [ -z $out_vcf ]; then out_vcf="all_variants.vcf"; fi


if [ ! -z $region ]
then
	input_region='region'
else 
	input_region='whole_genome'
fi

echo "Input BAM folder (--bam_folder)                                 : $bam_folder"
echo "output folder (--out_folder)                                    : $out_folder"
echo "Reference in fasta format (--fasta_ref)                         : $fasta_ref"
echo "Intervals for calling (--bed)                                   : $input_region"
echo "Strand bias measure (--sb_type)                                 : $sb_type"
echo "Strand bias threshold for SNVs (--sb_snv)                       : $sb_snv"
echo "Strand bias threshold for indels (--sb_indel)                   : $sb_indel"
echo "Minimum allelic fraction for power computations (--power_min_af): $power_min_af"
echo "Sigma parameter for germline (--sigma)                          : $sigma_normal"
echo "Samtools minimum mapping quality (--map_qual)                   : $map_qual"
echo "Samtools minimum base quality (--base_qual)                     : $base_qual"
echo "Samtools maximum coverage before downsampling (--max_DP)        : $max_DP"
echo "Sample names definition (--use_file_name)                       : $sample_names"
if [ $all_SNVs = true ]; then
	echo "Output all SNVs (--all_SNVs)                                    : yes" 
else
	echo "Output all SNVs (--all_SNVs)                                    : no"
fi
if [ $extra_robust_gl = true ]; then
	echo "Perform an extra-robust regression (--extra_robust_gl)          : yes" 
else
	echo "Perform an extra-robust regression (--extra_robust_gl)          : no"
fi
if [ $no_indels = true ]; then
	echo "Skip indels (--no_indels)                                       : yes"
else
	echo "Skip indels (--no_indels)                                       : no"
fi
echo "\n"

#check parameters values
if [ $sb_type != "SOR" ] && [ $sb_type != "RVSB" ] && [ $sb_type != "FS" ] 
then 
	echo "WARNING : --sb_type must be SOR, RVSB or FS "
fi
if [ $all_SNVs != true ] && [ $all_SNVs != false ] 
then 
	echo "WARNING : do not assign a value to --all_SNVs"
fi
if [ $extra_robust_gl != true ] && [ $extra_robust_gl != false ] 
then 
	echo "WARNING : do not assign a value to --extra_robust_gl"
fi

if [ $do_alignments != true ] && [ $do_alignments != false ] 
then 
	echo "WARNING : do not assign a value to --no_alignments"
fi
if [ $no_indels != true ] && [ $no_indels != false ] 
then 
	echo "WARNING : do not assign a value to --no_indels"
fi
if [ $use_file_name != true ] && [ $use_file_name != false ] 
then 
	echo "WARNING : do not assign a value to --use_file_name"
fi
  
if [ $do_plots = "SOMATIC" ] && [ $pairs_file = "FALSE" ]
then
	echo "\n ERROR : --do_plots can not be set to SOMATIC since no pairs_file was provided (--pairs_file option), exit."
	exit
fi
if [ $do_plots = "NONE" ] && [ $do_alignments = true ]
then
	echo "\n ERROR : --do_alignments can not be true since --do_plots is set to NONE, exit."
	exit
fi

if [ $do_alignments = true ] && [ -z $ref_genome ]
then
	echo "\n ERROR : --do_alignments is true, --ref_genome can not be null, exit."
	exit
fi
if [ $do_alignments = false ] && [ ! -z $ref_genome ]
then
	echo "\n WARNING : value assign to --ref_genome although do_alignments is false."
fi

if [ ! -e "$fasta_ref" ]; then
	echo "\n WARNING : fasta reference not located in execution directory. Make sure reference index is in the same folder as fasta reference"
	exit
else
	if [ ! -e "$fasta_ref_fai" ]; then
		echo "WARNING : input fasta reference does not seem to have a .fai index (use samtools faidx)"
	fi
fi
if [ ! -e "$bam_folder" ]; then
	echo "ERROR : Input BAM folder not located in execution directory"
	exit
fi


if [ $min_dp -lt 0 ];then echo "WARNING : minimum coverage must be higher than or equal to 0 (--min_dp)"; fi
if [ $max_DP -le 1 ];then echo "WARNING : maximum coverage before downsampling must be higher than 1 (--max_DP)"; fi
if [ $min_ao -lt 0 ];then echo "WARNING : minimum alternative reads must be higher than or equal to 0 (--min_ao)"; fi
if [ $min_qval -lt 0 ];then echo "WARNING : minimum Phred-scale qvalue must be higher than or equal to 0 (--min_qval)"; fi

if [ $(echo "$power_min_af" | awk '{print ($1 < 0)}') -eq 1 ] || [ $(echo "$power_min_af" | awk '{print ($1 > 1)}') -eq 1 ] || [ $(echo "$power_min_af" | awk '{print ($1 == -1)}') -eq 1 ]
then
	echo "WARNING : minimum allelic fraction for power computations must be in [0,1] (--power_min_af)"
fi

if [ $(echo "$sigma_normal" | awk '{print ($1 < 0)}') -eq 1 ]; then echo " sigma parameter for negative binomial must be positive (--sigma_normal)"; fi
if [ $sb_type = "SOR" ] || [ $sb_type = "RVSB" ]
then
	if [ $(echo "$sb_snv" | awk '{print ($1 <= 0)}') -eq 1 ] || [ $(echo "$sb_snv" | awk '{print ($1 >= 101)}') -eq 1 ]
	then
		echo "WARNING : strand bias (SOR or RVSB) for SNVs must be in [0,100]"
	fi
	if [ $(echo "$sb_indel" | awk '{print ($1 <= 0)}') -eq 1 ] || [ $(echo "$sb_indel" | awk '{print ($1 >= 101)}') -eq 1 ]
	then
		echo "WARNING : strand bias (SOR or RVSB) for indels must be in [0,100]"
	fi
else
	if [ $(echo "$sb_snv" | awk '{print ($1 <= 0)}') -eq 1 ] || [ $(echo "$sb_snv" | awk '{print ($1 >= 1001)}') -eq 1 ]
	then
		echo "WARNING : strand bias (FS) for SNVs must be in [0,1000]"
	fi
	if [ $(echo "$sb_indel" | awk '{print ($1 <= 0)}') -eq 1  ] || [ $(echo "$sb_indel" | awk '{print ($1 >= 1001)}') -eq 1 ]
	then
		echo "WARNING : strand bias (FS) for indels must be in [0,1000]"
	fi
fi


if [ $(echo "$map_qual" | awk '{print ($1 < 0)}') -eq 1 ]; then echo "WARNING : minimum mapping quality (samtools) must be higher than or equal to 0"; fi
if [ $(echo "$base_qual" | awk '{print ($1 < 0)}') -eq 1 ]; then echo "WARNING : minimum base quality (samtools) must be higher than or equal to 0"; fi



#calling on one region or on the whole genome
if [ $input_region = "whole_genome" ]; then
	region=$(cat "$fasta_ref_fai" | awk '{print $1":"0"-"$2 }')
fi

#parse indels or not
if [ $no_indels = true ]; then
	indel_par="true"
else
	indel_par="false"
fi

#generate names.txt file 
for cur_bam in $bam_folder*.bam
do
	if [ $sample_names = "FILE" ]; then
		# use bam file name as sample name
		bam_file_name=$(basename "${cur_bam%.*}")
		# remove whitespaces from name
		SM1="$(echo "${bam_file_name}" | tr -d '[[:space:]]')"
		SM2="$(echo "${bam_file_name}" | tr -d '[[:space:]]')"
	else
		# get bam file names 
		bam_file_name=$(basename "${cur_bam%.*}")
		# remove whitespaces from name
		SM1="$(echo "${bam_file_name}" | tr -d '[[:space:]]')"

		# extract sample name from bam file read group info field
		SM2="$(samtools view -H $cur_bam | grep "^@RG" | tail -n1 | sed "s/.*SM:\\([^	]*\\).*/\\1/" | tr -d '[:space:]')"
	fi
    printf "$SM1	$SM2\\n" >> names.txt
done

#parameters needed for the Rscript
if [ $no_labels = true ];then 
	labels=false
else 
	labels=true
fi
if [ $no_contours = true ];then 
	contours=false
else
	contours=true
fi

#mpileup2vcf
samtools mpileup --fasta-ref $fasta_ref --region $region --ignore-RG --min-BQ $base_qual --min-MQ $map_qual --max-idepth 1000000 --max-depth $max_DP $bam_folder*.bam | sed 's/		/	*	*/g' \
| ~/bin/mpileup2readcounts 0 -5 $indel_par 0 \
| Rscript ~/bin/needlestack.r --pairs_file=$pairs_file --source_path=~/bin/ --out_file=$out_vcf --fasta_ref=$fasta_ref --bam_folder=$bam_folder --ref_genome=$ref_genome \
--GQ_threshold=$min_qval --min_coverage=$min_dp --min_reads=$min_ao --SB_type=$sb_type --SB_threshold_SNV=$sb_snv --SB_threshold_indel=$sb_indel --output_all_SNVs=$all_SNVs \
--do_plots=$do_plots --do_alignments=$do_alignments --plot_labels=$labels --add_contours=$contours --extra_rob=$extra_robust_gl --afmin_power=$power_min_af --sigma=$sigma_normal

# Extract the header from the VCF
sed '/^#CHROM/q' $out_vcf > header.txt
# Add contigs in the VCF header
cat  $fasta_ref_fai | cut -f1,2 | sed -e 's/^/##contig=<ID=/' -e 's/[	 ][	 ]*/,length=/' -e 's/$/>/' > contigs.txt
sed -i '/##reference=.*/ r contigs.txt' header.txt
echo '##samtools='$(samtools --version | tr '\n' ' ') >> versions.txt
echo '##Rscript='$(Rscript --version 2>&1) >> versions.txt
sed -i '/##source=.*/ r versions.txt' header.txt
grep --no-filename -v '^#' $out_vcf >> header.txt
mv header.txt $out_vcf

#move pdf plots      
if [ $do_plots != "NONE" ]; then
	mkdir $out_folder'PDF'
	mv *.pdf $PWD/PDF
fi



#remove intermediate files

rm "names.txt"
rm "versions.txt"
rm "contigs.txt"








