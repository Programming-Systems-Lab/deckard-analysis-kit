#!/bin/bash
# Configure
function msg_start(){ echo -en "\033[38;5;246m$1...\033[39m   "; }
function msg_ok(){ echo -e "\033[38;5;246m[ \033[38;5;118mOK \033[38;5;246m]\033[39m"; }
function msg_err(){ echo -e "\033[38;5;246m[ \033[38;5;161mERROR \033[38;5;246m]\033[39m"; }
CURRENT_PATH=$(pwd)
DECKARD_SCRIPT="$DECKARD_PATH/scripts/clonedetect/deckard.sh"
ANALYSIS_ROOT="$( cd "$( dirname "$0" )" && pwd )"
if [ -z "$1" ] || [ -z "$2" ] || [ ! -d "$ANALYSIS_ROOT/libraries/$1" ] || [ ! -d "$ANALYSIS_ROOT/libraries/$2" ]; then
	echo "This script takes two library names as arguments. Options are:"
	ls "$ANALYSIS_ROOT/libraries/" | grep -v '^temp$' | sed 's/^/  /'
	exit 1
fi
if [ -z "$DECKARD_PATH" ] || [ ! -d "$DECKARD_PATH" ]; then
	echo -e "Environment variable 'DECKARD_PATH' not set or invalid."\
		"\nPlease make sure Deckard is installed and then run:"\
		"\n\n\texport DECKARD_PATH=\"/path/to/Deckard\"\n"
	exit 1
fi
echo -e "\033[1m--- Begin $1 vs $2 ($3/$4) ---\033[0m"

# Clean up
msg_start "Resetting test directory"
rm -rf "$ANALYSIS_ROOT/test/"*
mkdir "$ANALYSIS_ROOT/test/src"
msg_ok

# Move libraries and config file into position
msg_start "Loading $1 and $2 for comparison"
cp -R "$ANALYSIS_ROOT/libraries/$1" "$ANALYSIS_ROOT/test/src/"
cp -R "$ANALYSIS_ROOT/libraries/$2" "$ANALYSIS_ROOT/test/src/"
cp "$ANALYSIS_ROOT/config" "$ANALYSIS_ROOT/test/"
msg_ok

# Generate tags
msg_start "Running ctags to locate method headings"
cd "$ANALYSIS_ROOT/test/"
ctags -R -x -f- "src/" | grep '^[^ ]\+\s\+method' | sed 's/^[^ ]\+\s\+method\s\+//' | sort '-k2,2' '-k1,1n' > "tags"
ctags -R -x -f- "src/" | grep '^[^ ]\+\s\+package' | awk '{print $4 " " $1}' > "packages"
cd "$CURRENT_PATH"
msg_ok

# Run Deckard
msg_start "Running Deckard code-clone analysis"
cd "$ANALYSIS_ROOT/test/"
bash $DECKARD_SCRIPT > /dev/null
cat "deckard_clusters/cluster_vdb_$3""_2_allg_$4""_30" | awk '{print $4 " " $5 " " $2}' > "raw_output"
cd "$CURRENT_PATH"
msg_ok

# Filter Results
msg_start "Filtering Deckard output by method"
while read LINE; do
	if [ -z "$LINE" ]; then
		echo "" >> "$ANALYSIS_ROOT/test/merged_output"
		continue
	fi
	LINE_NUMBER=$(echo $LINE | sed 's/^[^:]\+:\([0-9]\+\):.*$/\1/')
	NUM_LINES=$(echo $LINE | sed 's/^[^:]\+:[0-9]\+:\([0-9]\+\).*$/\1/')
	FILE_NAME=$(echo $LINE | sed 's/^\([^ ]\+\) .*$/\1/')
	DIST=$(echo $LINE | sed 's/^.* dist:\([0-9\.]\+\)$/\1/')
	PACKAGE=$(cat "$ANALYSIS_ROOT/test/packages" | grep "$FILE_NAME" | cut -f2 "-d " | cut -f1 "-d.")
	METHOD=$({\
	cat "$ANALYSIS_ROOT/test/tags"\
		| grep "$FILE_NAME";\
	echo "$LINE_NUMBER $FILE_NAME";\
	}\
		| sort "-k1,1n" "-k2r"\
		| grep -B1 "$LINE_NUMBER [^ ]\+$"\
		| head -n 1)
	if [ -z "$(echo $METHOD | grep "^[^ ]\+ [^ ]\+ [^ ]")" ]; then continue; fi
	if [[ "$METHOD" =~ " next" ]]; then continue; fi
	if [[ "$METHOD" =~ " read" ]]; then continue; fi
	METHOD_LINE="$(echo $METHOD | cut -f1 '-d ')"
	METHOD=$(echo "$METHOD"\
		| sed 's/ \(public\|private\|static\|final\)//g'\
		| sed 's/^[^ ]\+ [^ ]\+ \([^(]*[^ (]\) *(.*$/\1/'\
		| tr ' ' '-')
	echo "$FILE_NAME:$METHOD_LINE:$METHOD@$PACKAGE" >> "$ANALYSIS_ROOT/results/methods_tok_"$3"_sim_"$4".txt"
	echo "$FILE_NAME:$METHOD_LINE:$LINE_NUMBER-$(( LINE_NUMBER+NUM_LINES )):$METHOD@$DIST"\
		>> "$ANALYSIS_ROOT/test/merged_output"
done < "$ANALYSIS_ROOT/test/raw_output"
msg_ok

# Format the results for Mike's stuff
msg_start "Formatting output for database"
OLDIFS=$IFS
IFS="@"
GROUP1=()
GROUP2=()
GROUP1_ID=""
while read LINE; do
	if [ -z "$LINE" ]; then
		for i in "${GROUP1[@]}"; do
			i=($i)
			for j in "${GROUP2[@]}"; do
				j=($j)
				echo "${i[0]} ${j[0]}"\
					| sed 's/:[0-9]\+:/:/g'\
					>> "$ANALYSIS_ROOT/test/formatted_output"

				# If clones are long enough, add to the nerest neighbors file
				NUM_LINES_i="$(echo "($(echo "${i[0]}" | cut -f3 "-d:")) * -1" | bc)"
				NUM_LINES_j="$(echo "($(echo "${j[0]}" | cut -f3 "-d:")) * -1" | bc)"
				if [ "$NUM_LINES_i" -lt 10 ] || [ "$NUM_LINES_j" -lt 10 ]; then
					continue
				fi
				if [ "${i[1]}" == "0.0" ]; then
					echo -e "${i[0]} ${j[0]} ${j[1]}\n${j[0]} ${i[0]} ${j[1]}"\
						>> "$ANALYSIS_ROOT/results/neighbors_tok_"$3"_sim_"$4".txt"
				fi
				if [ "${j[1]}" == "0.0" ]; then
					echo -e "${j[0]} ${i[0]} ${i[1]}\n${i[0]} ${j[0]} ${i[1]}"\
						>> "$ANALYSIS_ROOT/results/neighbors_tok_"$3"_sim_"$4".txt"
				fi
			done
		done
		GROUP1=()
		GROUP2=()
		GROUP1_ID=""
		continue
	fi
	LINE=($LINE)
	ID=$(echo "${LINE[0]}" | cut -f2 "-d/")
	if [ -z "$GROUP1_ID" ]; then GROUP1_ID=$ID; fi
	if [ "$ID" == "$GROUP1_ID" ]; then
		GROUP1+=("${LINE[0]}@${LINE[1]}")
	else
		GROUP2+=("${LINE[0]}@${LINE[1]}")
	fi
done < "$ANALYSIS_ROOT/test/merged_output"
IFS=$OLDIFS
/usr/bin/php collect_method_clusters.php "$ANALYSIS_ROOT/test/formatted_output" > "$ANALYSIS_ROOT/results/clones_$1""_$2"".csv" 2> "$ANALYSIS_ROOT/test/count_output"
if [ "$?" == "0" ]; then
	msg_ok
	echo -n "$3,$4,$1,$2," >> "$ANALYSIS_ROOT/results/all_counts.csv"
	echo -n "$(cat "$ANALYSIS_ROOT/results/clones_$1""_$2"".csv" | wc -l),"\
		>> "$ANALYSIS_ROOT/results/all_counts.csv"
	cat "$ANALYSIS_ROOT/test/count_output" >> "$ANALYSIS_ROOT/results/all_counts.csv"
else
	msg_err
	echo "$3,$4,$1,$2,0,0,0,0" >> "$ANALYSIS_ROOT/results/all_counts.csv"
fi

# Report Java 1.4 incompatibility and syntax errors
NUM_ERRORS=$(grep -c 'syntax error:'\
	"$ANALYSIS_ROOT/test/deckard_times/vgen_"$3"_2")
if [ "$NUM_ERRORS" -gt 0 ]; then
	echo "[38;5;208m$NUM_ERRORS Syntax errors reported[39m"
	echo "$1,$2,$NUM_ERRORS" >> "$ANALYSIS_ROOT/results/error_log.csv"
fi

# Done
msg_start "Results file saved"
msg_ok
echo -e "\033[1mDone!\033[0m"
