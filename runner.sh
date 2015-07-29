#!/bin/bash

# Configure
ANALYSIS_ROOT="$( cd "$( dirname "$0" )" && pwd )"
SRC_DIR="$ANALYSIS_ROOT/libraries/"

# Declare target parameters
declare -a toks=("50" "100" "500")
declare -a sims=("0.85" "0.95" "0.98")

# Iterate through analysis settings
for tok in "${toks[@]}"; do
for sim in "${sims[@]}"; do
	sed -i "s/\(MIN_TOKENS='\)[^']*\(.*\)/\1$tok\2/" "$ANALYSIS_ROOT/config"
	sed -i "s/\(SIMILARITY='\)[^']*\(.*\)/\1$sim\2/" "$ANALYSIS_ROOT/config"
	if [ ! -d "$ANALYSIS_ROOT/results/tok_$tok""_sim_$sim" ]; then
		mkdir "$ANALYSIS_ROOT/results/tok_$tok""_sim_$sim"
	fi

	# Iterate through library names
	for i in $(ls "$SRC_DIR");do
	for j in $(ls "$SRC_DIR");do
	if [ "$i" = "temp" ] || [ "$j" = "temp" ]; then continue; fi
	if [[ "$j" > "$i" ]]; then

		# Run the analysis script
		bash "$ANALYSIS_ROOT/analyze.sh" $i $j $tok $sim

		# Catch errors
		if [ "$?" -ne 0 ]; then
			exit 1
		fi

		# Collect the results
		if [ -f "$ANALYSIS_ROOT/results/clones_$i""_$j"".csv" ];then
			mv $ANALYSIS_ROOT/results/clones_$i"_"$j".csv" $ANALYSIS_ROOT/results/tok_$tok"_sim_"$sim"/"
		else
			touch $ANALYSIS_ROOT/results/tok_$tok"_sim_"$sim/clones_$i"_"$j".csv"
		fi
	fi
	done
	done
done
done

# Done. Print an alert
echo -e "\a"
