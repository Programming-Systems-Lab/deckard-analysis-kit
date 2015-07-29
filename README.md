# Deckard Analysis Kit

## Premise
[Deckard](https://github.com/skyhover/Deckard) is a static code clone detection
system (2008 paper [here](http://ieeexplore.ieee.org/xpls/abs_all.jsp?arnumber=4814143))
that finds semantically similar code segments, "clones",  within a codebase.
This kit provides a convenient set of scripts for finding code clones across
two _different_ codebases by essentially combining them into one, and then
filtering out same-origin clones. It is also equipped for automation, allowing
for multiple different codebases to be compared in all pair-wise combinations,
and allowing analysis to be run at different settings (see 'Kit Configuration'
below).


## Setup
Setup is fairly simple, since most of the scripts are ready-to-use immediately
after being downloaded.

### Requirements
This kit is intended to be used form a \*nix terminal with at least 256-color
support. It uses two bash scripts and one PHP script. Accordingly, bash > 4.0
and PHP > 4.3 are required.

### Installing Deckard
As of the time of this README's writing, the version of Deckard mentioned in
the 2008 ICSE paper is not available for download or use. However, an older
version is available [here](https://github.com/skyhover/Deckard), complete with
installation instructions.

### Kit Configuration
Once you install Deckard, you simply need to set an environment variable
telling this kit where Deckard was installed. You can do that with the
following command:

	export DECKARD_PATH="/path/to/Deckard"


## Usage
To run this kit, there are three simple steps.

1. Extract all the codebases you wish to compare to individually named
directories within `libraries`. For example, if you wish to find clones across
projects `foo`, `bar`, and `baz`, start by extracting them to `libraries/foo/`,
`libraries/bar/`, and `libraries/baz`, respectively.
2. Configure the settings with which Deckard should be run. This is done by
writing them into the arrays on lines 8 and 9 of `runner.sh`. Here are the
default values:

	declare -a toks=("50" "100" "500")
	declare -a sims=("0.85" "0.95" "0.98")

The first array, `toks`, controls the approximate number of tokens in each
clone. Keep in mind there are about 7 tokens per line of Java code. The second
array, `sims`, controls how similar code segments need to be in order to be
considered "clones". The number is fairly mysterious, but for reference,
Deckard's default is 0.95. With the arrays set as they are above, each pair of
codebases will be compared nine times, once for each combination of token and
similarity settings.
3. Invoke the runner script with:

	./runner.sh

The runner script may take some time to complete, depending on your settings
and the number and sizes of your codebases, however it prints diagnostic
information the whole while, and issues a terminal bell when processing has
completed, so it is pretty convenient for use in batch processing jobs.

After running the kit, results are saved to the `results` directory. Pair-wise
clone lists are stored in subdirectories named according to the settings with
which they were run. Aggregate data is written to `results/all_counts.csv`.

Please report any [issues](https://github.com/Programming-Systems-Lab/deckard-analysis-kit/issues)
you may encounter. Thanks!

