#!/bin/bash

# Configure
ANALYSIS_ROOT="$( cd "$( dirname "$0" )" && pwd )"
SRC_DIR="$ANALYSIS_ROOT/libraries/"
function msg_start(){ echo -en "\033[38;5;246m$1...\033[39m   "; }
function msg_ok(){ echo -e "\033[38;5;246m[ \033[38;5;118mOK \033[38;5;246m]\033[39m"; }
function msg_err(){ echo -e "\033[38;5;246m[ \033[38;5;161mERROR \033[38;5;246m]\033[39m"; }

# Declare target parameters
declare -a toks=("90")
declare -a sims=("0.90")
#declare -a toks=("50" "100" "500")
#declare -a sims=("0.85" "0.95" "0.98")

# Iterate through analysis settings
for tok in "${toks[@]}"; do
for sim in "${sims[@]}"; do
	sed -i "s/\(MIN_TOKENS='\)[^']*\(.*\)/\1$tok\2/" "$ANALYSIS_ROOT/config"
	sed -i "s/\(SIMILARITY='\)[^']*\(.*\)/\1$sim\2/" "$ANALYSIS_ROOT/config"
	if [ ! -d "$ANALYSIS_ROOT/results/tok_$tok""_sim_$sim" ]; then
		mkdir "$ANALYSIS_ROOT/results/tok_$tok""_sim_$sim"
	fi

	# Truncate the packages and neighbors files
	echo
	> "$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"
	> "$ANALYSIS_ROOT/results/neighbors_tok_"$tok"_sim_"$sim".txt"

	# Iterate through library names
	for i in $(ls "$SRC_DIR");do
	for j in $(ls "$SRC_DIR");do
	if [ "$i" = "temp" ] || [ "$j" = "temp" ]; then continue; fi
	if [[ "$j" > "$i" ]]; then

		# Run the analysis script
		bash "$ANALYSIS_ROOT/analyze.sh" $i $j $tok $sim

		# Catch errors
		if [ "$?" -ne 0 ]; then exit 1; fi

		# Collect the results
		if [ -f "$ANALYSIS_ROOT/results/clones_$i""_$j"".csv" ];then
			mv $ANALYSIS_ROOT/results/clones_$i"_"$j".csv" $ANALYSIS_ROOT/results/tok_$tok"_sim_"$sim"/"
		else
			touch $ANALYSIS_ROOT/results/tok_$tok"_sim_"$sim/clones_$i"_"$j".csv"
		fi
	fi
	done
	done

	# Aggregate neighbor data
	echo -e "\n[1;39m--- Analyzing Nearest-Neighbors ($tok/$sim) ---[0m"
	msg_start "Sorting method list"
	mv "$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"\
		"$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt.bkp"
	cat "$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt.bkp"\
		| sort | uniq\
		> "$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"
	msg_ok
	msg_start "Looking up best matches"
	for LINE in $(cat "$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"); do
		METHOD1="$(echo "$LINE" | cut -f1 '-d@')"
		ACTUAL_LABEL="$(echo "$LINE" | cut -f2 '-d@')"
		GUESS_LABELS=""
		BEST_NEIGHBOR=""
		SIMILARITY=""
		for METHOD2 in $(\
			cat "$ANALYSIS_ROOT/results/neighbors_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/:[0-9]\+-[0-9]\+:/:/g'\
				| grep "^$METHOD1 "\
				| awk '{print $3 " " $2}'\
				| sort "-k2,2d" "-k1,1n"\
				| uniq -f1\
				| sort "-k1,1nr"\
				| tail -n5\
				| tr ' ' '@'); do
			BEST_NEIGHBOR="$(echo "$METHOD2" | cut -f2 '-d@')"
			SIMILARITY="$(echo "$METHOD2" | cut -f1 '-d@')"
			GUESS_LABELS="$GUESS_LABELS\n$(grep "^$BEST_NEIGHBOR"\
				"$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/^[^@]*@\(.*\)$/\1/')"
		done
		GUESS_LABEL=$(echo -e "$GUESS_LABELS"\
			| tail -n +2\
			| sort | uniq -c\
			| sort "-k1,1nr"\
			| head -n1\
			| sed 's/^\s\+//'\
			| cut -f2 '-d ')
		if [ -n "$GUESS_LABEL" ]; then
			METHOD1="$(grep "$METHOD1"\
				"$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/^src\/CJ_201._\([^\/]\+\)\/\([^\.]\+\)\.java:\([0-9]\+\)[^0-9]*[:-]\([^:-@]\+\)@\(.*\)$/\5.\1.\2.\4:\3/')"
			METHOD2="$(grep "$METHOD2"\
				"$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/^src\/CJ_201._\([^\/]\+\)\/\([^\.]\+\)\.java:\([0-9]\+\)[^0-9]*[:-]\([^:-@]\+\)@\(.*\)$/\5.\1.\2.\4:\3/')"
			RESULT="$METHOD1"
			RESULT="$RESULT, $ACTUAL_LABEL"
			RESULT="$RESULT, $BEST_NEIGHBOR"
			RESULT="$RESULT, $SIMILARITY"
			RESULT="$RESULT, $GUESS_LABEL"
			if [ "$ACTUAL_LABEL" = "$GUESS_LABEL" ]; then
				RESULT="$RESULT, yes"
			else
				RESULT="$RESULT, no"
			fi
			echo "$RESULT" >> "$ANALYSIS_ROOT/results/label_predictions.csv"
		fi
	done
	msg_ok
	echo "[1;39mDone![0m"
done
done

# Done. Print an alert
echo -e "\a"
