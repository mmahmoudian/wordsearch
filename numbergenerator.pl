#!/usr/bin/perl
# Quick script to generate a series of random numbers

$X=0;
$Y=999999999999;
$total = 40;
open FILE, ">random_numbers";
for ($i=1;$i<=$total;$i++) {
	$random = int( rand( $Y-$X+1 ) ) + $X;
	print FILE "$random\n";
}
close FILE;
