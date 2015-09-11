#!/bin/bash

# Declare target parameters
declare -a toks=("90" "135" "180" "270")
declare -a sims=("0.85" "0.9" "0.95")
LABELING_K=5

# Configure the script
ANALYSIS_ROOT="$( cd "$( dirname "$0" )" && pwd )"
SRC_DIR="$ANALYSIS_ROOT/libraries/"
function msg_start(){ echo -en "\033[38;5;246m$1...\033[39m   "; }
function msg_ok(){ echo -e "\033[38;5;246m[ \033[38;5;118mOK \033[38;5;246m]\033[39m"; }
function msg_err(){ echo -e "\033[38;5;246m[ \033[38;5;161mERROR \033[38;5;246m]\033[39m"; }

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
	cp "$ANALYSIS_ROOT/results/label_predictions.csv"\
		"$ANALYSIS_ROOT/results/label_predictions_tok_"$tok"_sim_"$sim"_k_"$LABELING_K".csv"
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
		declare -A LABEL_SCORES
		LABEL_SCORES["R5P1Y11"]=0
		LABEL_SCORES["R5P1Y12"]=0
		LABEL_SCORES["R5P1Y13"]=0
		LABEL_SCORES["R5P1Y14"]=0
		METHOD2_LIST=$(\
			cat "$ANALYSIS_ROOT/results/neighbors_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/:[0-9]\+-[0-9]\+:/:/g'\
				| grep "^$(echo "$METHOD1" | sed 's/[][]/./g')\\b"\
				| awk '{print $3 " " $2}'\
				| sort "-k2,2d" "-k1,1n"\
				| uniq -f1\
				| sort "-k1,1nr")
		TEMP_K=$LABELING_K
		LOW=$(echo $METHOD2_LIST | tail "-n$LABELING_K" | head -n1 | cut -f1 '-d ')
		for i in `seq $LABELING_K 1000`; do
			TEST=$(echo $METHOD2_LIST | tail "-n$i" | head -n1 | cut -f1 '-d ')
			if [ "$TEST" == "$LOW" ]; then
				TEMP_K=$i
			else
				break
			fi
		done
		for METHOD2 in $(echo $METHOD2_LIST | tail "-n$TEMP_K" | tr ' ' '@'); do
			BEST_NEIGHBOR="$(echo "$METHOD2" | cut -f2 '-d@')"
			SIMILARITY="$(echo "$METHOD2" | cut -f1 '-d@')"
			GUESS_LABEL="$(grep "^$(echo "$BEST_NEIGHBOR" | sed 's/[][]/./g')\\b"\
				"$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/^[^@]*@\(.*\)$/\1/')"
			LABEL_SCORES["$GUESS_LABEL"]=$(echo\
				"${LABEL_SCORES["$GUESS_LABEL"]} + $SIMILARITY" | bc)
		done
		if [ -z "$BEST_NEIGHBOR" ]; then continue; fi;
		if [ "$(bc <<< "${LABEL_SCORES["R5P1Y11"]} > ${LABEL_SCORES["R5P1Y12"]}")" -ne 0 ]; then
			if [ "$(bc <<< "${LABEL_SCORES["R5P1Y11"]} > ${LABEL_SCORES["R5P1Y13"]}")" -ne 0 ]; then
				if [ "$(bc <<< "${LABEL_SCORES["R5P1Y11"]} > ${LABEL_SCORES["R5P1Y14"]}")" -ne 0 ]; then
					GUESS_LABEL="R5P1Y11"
				else
					GUESS_LABEL="R5P1Y14"
				fi
			else
				if [ "$(bc <<< "${LABEL_SCORES["R5P1Y13"]} > ${LABEL_SCORES["R5P1Y14"]}")" -ne 0 ]; then
					GUESS_LABEL="R5P1Y13"
				else
					GUESS_LABEL="R5P1Y14"
				fi
			fi
		else
			if [ "$(bc <<< "${LABEL_SCORES["R5P1Y12"]} > ${LABEL_SCORES["R5P1Y13"]}")" -ne 0 ]; then
				if [ "$(bc <<< "${LABEL_SCORES["R5P1Y12"]} > ${LABEL_SCORES["R5P1Y14"]}")" -ne 0 ]; then
					GUESS_LABEL="R5P1Y12"
				else
					GUESS_LABEL="R5P1Y14"
				fi
			else
				if [ "$(bc <<< "${LABEL_SCORES["R5P1Y13"]} > ${LABEL_SCORES["R5P1Y14"]}")" -ne 0 ]; then
					GUESS_LABEL="R5P1Y13"
				else
					GUESS_LABEL="R5P1Y14"
				fi
			fi
		fi
		if [ -n "$GUESS_LABEL" ]; then
			METHOD1="$(grep "$(echo "$METHOD1" | sed 's/[][]/./g')"\
				"$ANALYSIS_ROOT/results/methods_tok_"$tok"_sim_"$sim".txt"\
				| sed 's/^src\/CJ_201._\([^\/]\+\)\/\([^\.]\+\)\.java:\([0-9]\+\)[^0-9]*[:-]\([^:-@]\+\)@\(.*\)$/\5.\1.\2.\4:\3/')"
			METHOD2="$(grep "$(echo "$METHOD2" | sed 's/[][]/./g')"\
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
			echo "$RESULT" >> "$ANALYSIS_ROOT/results/label_predictions_tok_"$tok"_sim_"$sim"_k_"$LABELING_K".csv"
		fi
	done
	msg_ok
	echo "[1;39mDone![0m"
done
done

# Done. Print an alert
echo -e "\a"
