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
cd "$CURRENT_PATH"
msg_ok

# Run Deckard
msg_start "Running Deckard code-clone analysis"
cd "$ANALYSIS_ROOT/test/"
bash $DECKARD_SCRIPT > /dev/null
cat "deckard_clusters/cluster_vdb_$3""_2_allg_$4""_30" | awk '{print $4 " " $5}' > "raw_output"
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
	METHOD=$({\
	cat "$ANALYSIS_ROOT/test/tags"\
		| grep "$FILE_NAME";\
	echo "$LINE_NUMBER $FILE_NAME";\
	}\
		| sort "-k1,1n" "-k2r"\
		| grep -B1 "$LINE_NUMBER [^ ]\+$"\
		| head -n 1)
	if [ -z "$(echo $METHOD | grep "^[^ ]\+ [^ ]\+ [^ ]")" ]; then continue; fi
	METHOD=$(echo "$METHOD"\
		| sed 's/^[^ ]\+ [^ ]\+ [^ ]\+ \([^(]*[^ (]\) *(.*$/\1/'\
		| tr ' ' '-')
	echo "$FILE_NAME:$LINE_NUMBER-$(( LINE_NUMBER+NUM_LINES )):$METHOD" >> "$ANALYSIS_ROOT/test/merged_output"
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
			for j in "${GROUP2[@]}"; do
				echo "$i $j" >> "$ANALYSIS_ROOT/test/formatted_output"
			done
		done
		GROUP1=()
		GROUP2=()
		GROUP1_ID=""
		continue
	fi
	ID=$(echo "$LINE" | cut -f2 "-d/")
	if [ -z "$GROUP1_ID" ]; then GROUP1_ID=$ID; fi
	if [ "$ID" == "$GROUP1_ID" ]; then
		GROUP1+=($LINE)
	else
		GROUP2+=($LINE)
	fi
done < "$ANALYSIS_ROOT/test/merged_output"
IFS=$OLDIFS
/usr/bin/php collect_method_clusters.php "$ANALYSIS_ROOT/test/formatted_output" > "$ANALYSIS_ROOT/results/clones_$1""_$2"".csv" 2> "$ANALYSIS_ROOT/test/count_output"
if [ "$?" == "0" ]; then
	msg_ok
	echo -n "$3,$4,$1,$2," >> "$ANALYSIS_ROOT/results/all_counts.csv"
	echo -n "$(cat "$ANALYSIS_ROOT/results/clones_$1""_$2"".csv"\
		| wc | sed 's/^\s*\([0-9]\+\)\s.*$/\1/')," >> "$ANALYSIS_ROOT/results/all_counts.csv"
	cat "$ANALYSIS_ROOT/test/count_output" >> "$ANALYSIS_ROOT/results/all_counts.csv"
else
	msg_err
	echo "$3,$4,$1,$2,0,0,0,0" >> "$ANALYSIS_ROOT/results/all_counts.csv"
fi

# Done
msg_start "Results file saved"
msg_ok
echo -e "\033[1mDone!\033[0m"
