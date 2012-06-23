#!/usr/bin/perl
#########################

use Test::More;
use Expect;

#########################
@patients=("double", "long", "int");

# It seems that ok() cannot be used in a loop.
# So I had to change the "ok" in the middle to "fail() if".
plan "tests" => 1 + @patients*6;

sub Diag {
#diag(@_);
} 

$Expect::Log_Stdout=0;

#########################
ok(1, "start");

our $current_val;

sub slave_getvalue
{
	my($slave)=@_;

	$slave->print("\n");
	$slave->expect(1, 
			[ qr(^={5,} NEW VALUE: (\S+)), sub 
				{ 
					my($self)=@_;
					# Allow the child to print an expression, so that the values to 
					# be found isn't left on the stack (for printf() or similar).
					$current_val=eval(($self->matchlist())[0]); 
				} 
			]
		);

	return $current_val;
}



for $patient (@patients)
{
	Diag("Going for $patient");

	$slave=new Expect;
	$slave->raw_pty(1);
	$slave->spawn("sh -c t/test-$patient.*", ())
		or die "Cannot spawn test-$patient.pl";

	$client = new Expect;
	$client->raw_pty(1);
	$client->spawn("hack-live -p" . $slave->pid, ())
		or die "Cannot spawn Games::Hack::Live: $!\n";

# Testing here doesn't work. It seems that perl doesn't keep the scalar at 
# the same memory location, but moves it around. 
# Strangely that works if the perl script is run separately - does the 
# Test:: framework something like eval()?

	$client->print("\n\n");
	$client->expect(4, [ qr(^---), ] );



	$loop_min=5;
	$loop_max=17;
# Take a few values, then try to inhibit changes.
	for $loop (1 .. $loop_max)
	{
		slave_getvalue($slave);
		last unless $current_val;

		Diag("got current value as $current_val\n");
		$client->print(
				$current_val =~ m#\.# ?
				"find ($patient) ". ($current_val-1) ." ". ($current_val+1) ."\n" :
				"find ($patient) $current_val\n");
		$client->expect(4, [ qr(--->), sub { } ], );

		$last=$client->before;
		($wanted)=($last =~ /Most wanted:\s+(\w.*)/);
		last unless $wanted;

		%matches=@matches=grep($_ !~ /^(0x0+)?0$/,$wanted =~ /(\w+)\((\d+)\)/g);
#		print STDERR "$loop: $wanted\n==== has $current_val: ", 
#		join(" ", @matches),"\n", 0+@matches, $matches[1] > $matches[3],"\n";

# Stop testing if there's only a single match, or a single best match.
		last if ($loop > $loop_min) && 
			@matches &&
			(@matches == 2 ||
			 $matches[1] > $matches[3]);
	}

	ok($current_val>0, "Identifiable output");
	ok($wanted, "Got list of addresses");


	ok(@matches==2, 
			"matching addresses: 1 wanted; got " . 
			join(" ", sort keys %matches));

	($adr, $count)=each %matches;
	$last=$client->before;
	Diag("got address $adr, with $count matches.");
	ok($adr, "address found");
# we allow a single bad value.
	ok($count >= $loop_min, "Not enough matches found?");


	Diag("Trying to kill writes.\n");

	$client->print("killwrites $adr\n");
	$client->clear_accum;
	$client->expect(1, [ qr(--->), sub { } ], );

	slave_getvalue($slave);
	slave_getvalue($slave);
	$slave->clear_accum;

	$old=slave_getvalue($slave);
	$new=slave_getvalue($slave);

	Diag("old was $old, new is $new");
	ok($old == $new ,"changed value ($old == $new)?");

	$slave->print("quit\n");
	$client->print("kill\n\n");
	$client->hard_close;
	$slave->hard_close;

	Diag("$patient done\n");
}

exit;

