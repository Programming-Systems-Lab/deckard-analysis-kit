<?php
if(count($argv)<2){
	fwrite(STDERR, "No file provided ");
	exit(1);
}
if(!file_exists($argv[1])){
	fwrite(STDERR, "No clones found ");
	exit(1);
}

$file_handle = fopen($argv[1], 'r');
$lines = 0.0;
$clones = 0;
$matches = array();
while($line = fgets($file_handle)){
	$line = rtrim($line);
	$parts = explode(" ", $line);
	$parts1 = explode(":", $parts[0]);
	$parts2 = explode(":", $parts[1]);
	$file1 = $parts1[0];
	$lines1 = explode("-", $parts1[1]);
	$method1 = $parts1[2];
	$file2 = $parts2[0];
	$lines2 = explode("-", $parts2[1]);
	$method2 = $parts2[2];
	if(!isset($matches[$file1]))
		$matches[$file1] = array();
	if(!isset($matches[$file1][$method1]))
		$matches[$file1][$method1] = array();
	if(!isset($matches[$file1][$method1][$file2]))
		$matches[$file1][$method1][$file2] = array();
	if(!isset($matches[$file1][$method1][$file2][$method2]))
		$matches[$file1][$method1][$file2][$method2] = array(
			0 => array()
			,1 => array()
		);
	$matches[$file1][$method1][$file2][$method2][0][implode('-',$lines1)]=1;
	$matches[$file1][$method1][$file2][$method2][1][implode('-',$lines2)]=1;
	++$clones;
	$lines += (($lines1[1]-$lines1[0]) + ($lines2[1]-$lines2[0])) / 2.0;
}
$lines_per_clone = $lines / ($clones*1.0);
fwrite(STDERR, "$clones,$lines,$lines_per_clone\n");

foreach($matches as $file1 => $file1Matches){
	foreach($file1Matches as $method1 => $method1Matches){
		foreach($method1Matches as $file2 => $file2Matches){
			foreach($file2Matches as $method2 => $method2Matches){
				echo "$file1:$method1, $file2:$method2, ".implode(';',array_keys($method2Matches[0])).", ".implode(';',array_keys($method2Matches[1]))."\n";
			}
		}
	}
}
