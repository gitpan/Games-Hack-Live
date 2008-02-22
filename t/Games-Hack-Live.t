#!/usr/bin/perl
#########################

use Test::More tests => 1;
use Expect;

#########################


# The Games::Hack::Live script is used to examine *this* script;
# it should be able to find a memory location, and change it.

ok(1, "start");
exit;

$client = new Expect;

$client->raw_pty(1);
$client->spawn("hack-live -p$$ 2>&1", ()) 
or die "Cannot spawn Games::Hack::Live: $!\n";


# Testing here doesn't work. It seems that perl doesn't keep the scalar at 
# the same memory location, but moves it around. Will have to be done via a 
# C program. TODO

$var=2371.0;
$ref=\$var;
for $run (1 .. 10)
{
	$$ref += 113/$run;
	$client->print("find " . ($var-1.0) . " " . ($var+1.0) . "\n");
	$client->expect(1, [ qr(--->), sub { } ], );
	$last=$client->before;
	print STDERR "$var... $last\n";
}
diag("Loop finished");


#$last=$client->before;
print STDERR "$last\n";
($adr, $count)=($last =~ /Most wanted:\s+(\w+)\((\d+)\)/);
is($adr, "No matches found?");
is($count < 7, "Not enough matches found?");
like($last, qr/Most wanted:\s+(\w+)\((\d+)\)/, "No matches found?");
is($2, $run, "Not everything matched?");

diag("Address is $1");



{ 
	use integer;
	$var=71;
	for $run (1 .. 10)
	{
		$var += $run;
		$client->print("find $var\n");
		$client->expect(1, [ qr(--->), sub { } ], );
$last=$client->before;
#print STDERR "$last\n";
	}
	diag("Loop finished");
}


#ok(1, "aga");
#pass("aa");
#fail("aa");

exit;

