#!/usr/bin/env perl
#
# see sub usage() below for how to use.

use Data::Dumper;

sub usage() {
	print("usage: $0 [term]\n\n");
	print("generate and run zig code to test terminfo.zig on a terminfo file.\n");
	print("All terminfo attributes are checked against the output of infocmp.\n");
	print("If [term] is omitted, \$TERM is used. If \$TERM is unset, shit happens.\n\n");
	print("The terminfo file for the terminal is searched as detailed in the\n");
	print("section Fetching Compiled Definitions of man 5 terminfo.\n");
	exit 1;
}

sub getallattrs() {
	my $booleans = [];
	my $numbers = [];
	my $strings = [];
	my $in_booleans = 0;
	my $in_numbers = 0;
	my $in_strings = 0;
	local *IN;
	open IN, "<term/info.zig" or die "could not open term/info.zig for input: $!";
	for (<IN>) {
		if (/^\s*pub\s+const\s+Booleans\s+=\s+enum/) {
			$in_booleans = 1;
		} elsif (/^\s*pub\s+const\s+Numbers\s+=\s+enum/) {
			$in_numbers = 1;
		} elsif (/^\s*pub\s+const\s+Strings\s+=\s+enum/) {
			$in_strings = 1;
		} elsif (/^\s*\};\s*$/) {
			$in_booleans = 0;
			$in_numbers = 0;
			$in_strings = 0;
		} elsif (/^\s*([a-z][a-z0-9_]+)(\s*=.+)?,$/i) {
			if ($in_booleans) {
				push @$booleans, $1;
			} elsif ($in_numbers) {
				push @$numbers, $1;
			} elsif ($in_strings) {
				push @$strings, $1;
			}
		}
	}
	close IN;
	return {
		booleans => $booleans,
		numbers => $numbers,
		strings => $strings
	};
}

sub gettermattrs($) {
	my $term = shift;
	my $names = "";
	my $booleans = {};
	my $numbers = {};
	my $strings = {};
	local *IN;
	open IN, "infocmp -q1xL $term |" or die "could not call infocmp on term: $!";

	$_ = <IN>;
	chomp;
	s/,$//g;
	# first line is terminal name
	$names = $_;
	
	for (<IN>) {
		chomp;
		s/^\s+//;
		s/,$//;

		if (/^([a-z0-9_]+)$/i) {
			$booleans->{$1} = 1;
		} elsif (/^([a-z0-9_]+)#(.+)$/i) {
			my $n = $1;
			my $v = $2;
			if ($v =~ /^0x/) {
				$v = hex($v);
			}
			$numbers->{$n} = $v;
		} elsif (/^([a-z0-9_]+)=(.*)$/i) {
			my $a = $1;
			my $v = $2;
			# this is probably too simple, but seems to work so far
			$v =~ s/\\E\\/\\x1b\\x5c/g;	# escape + \ (rare?)
			$v =~ s/\\E/\\x1b/g;	# escape
			$v =~ s/\\n/\\x0a/g;	# newline
			$v =~ s/\\l/\\x0a/g;	# linefeed
			$v =~ s/\\r/\\x0d/g;	# carriage return
			$v =~ s/\\t/\\x09/g;	# tab
			$v =~ s/\\b/\\x08/g;	# backspace
			$v =~ s/\\f/\\x0c/g;	# form feed
			$v =~ s/\\s/ /g;		# space
			$v =~ s/\\([0-7]{3})/sprintf("\\x%02x", oct($1))/ge;
			$v =~ s/\\([,:^])//g;	# any other escaped char
			$v =~ s/\\$/\\\\/g;		# this only happened in cons25, maybe an error in infocmp?
			$v =~ s/\^([A-Z])/sprintf("\\x%02x", ord($1)-ord('A') + 1)/ge;
			$strings->{$a} = $v;
		} elsif (/^([a-z0-9_]+)\@/i) {
			#ignore
		} else {
			print("invalid line: $_\n");
			exit 1;
		}
	}

	close IN;
	return {
		names => $names,
		booleans => $booleans,
		numbers => $numbers,
		strings => $strings
	};
}

sub get_defined($) {
	my $h = shift;
	my @A = ();
	for (keys %$h) {
		push @A, $_ if defined $h->{$_};
	}
	return @A
}

sub report_extraneous($) {
	my $ta = shift;
	my @A;
	@A = get_defined($ta->{'booleans'});
	print "Extraneous booleans: " . join(", ", @A) . "\n" if @A;
	@A = get_defined($ta->{'numbers'});
	print "Extraneous numbers: " . join(", ", @A) . "\n" if @A;
	@A = get_defined($ta->{'strings'});
	print "Extraneous strings: " . join(", ", @A) . "\n" if @A;
}

# process the single command line argument, or default to $TERM
if ($#ARGV > 0 || $ARGV[0] eq '-h' || $ARGV[0] eq '-?') {
	usage();
}

$term=$ARGV[0];

if ($term eq "") {
	$term=$ENV{'TERM'};
}
if ($term eq "") {
	usage();
}

# try the usual places for TERMINFO unless it is set. Fail if no dir can be found.
my $tisubpath = substr($term, 0, 1)."/$term";
if (!defined $ENV{'TERMINFO'}) {
	if (-f $ENV{'HOME'} . "/.terminfo/$tisubpath") {
		$TERMINFO=$ENV{'HOME'} . "/.terminfo";
	} elsif (-f "/etc/terminfo/$tisubpath") {
		$TERMINFO="/etc/terminfo";
	} elsif (-f "/lib/terminfo/$tisubpath") {
		$TERMINFO="/lib/terminfo";
	} elsif ( -f "/usr/share/terminfo/$tisubpath") {
		$TERMINFO="/usr/share/terminfo";
	} else {
		print "no valid terminfo path could be found, please set TERMINFO.\n";
		exit 1;
	}
} else {
	$TERMINFO=$ENV{'TERMINFO'};
}

$terminfo="$TERMINFO/$tisubpath";

if (! -f $terminfo) {
	print("terminfo for terminal $term could not be found.\n");
	print("\$TERMINFO=$TERMINFO\n");
	exit 1;
}

# build test source file

$testsource="test_terminfo_$term.zig";
open OUT, ">$testsource" or die "could not open $testsource for output.";

print OUT <<"__END";
// automatically generated, do not edit. Run '$0 $term' instead.
const std = \@import("std");
const term = \@import("term/term.zig");
const terminfo = term.info;
const Terminfo = terminfo.Terminfo;
const expect = std.testing.expect;

test "test terminfo definitions for $term" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(gpa.deinit() == .ok) catch \@panic("leak");
    const allocator = gpa.allocator();
    var ti = try Terminfo.init(allocator, "$term");
    defer ti.deinit();
    ti.repairAcsc();

__END

$all_attrs = getallattrs();
$term_attrs = gettermattrs($term);

my $n = $term_attrs->{'names'};
$n =~ s/"/\\"/g;
print OUT "    try expect(std.mem.eql(u8,ti.names,\"$n\"));\n";

for (@{$all_attrs->{'booleans'}}) {
	print OUT "    try expect(ti.getBoolean(.$_)==";
	if ($term_attrs->{'booleans'}->{$_}) {
		print OUT "true";
		$term_attrs->{'booleans'}->{$_} = undef;
	} else {
		print OUT "false";
	}
	print OUT ");\n"
}

for (@{$all_attrs->{'numbers'}}) {
	print OUT "    try expect(ti.getNumber(.$_)";
	if (defined $term_attrs->{'numbers'}->{$_}) {
		print OUT ".?==".$term_attrs->{'numbers'}->{$_};
		$term_attrs->{'numbers'}->{$_} = undef;
	} else {
		print OUT "==null";
	}
	print OUT ");\n"
}

for (@{$all_attrs->{'strings'}}) {
	if (defined $term_attrs->{'strings'}->{$_}) {
		my $v = $term_attrs->{'strings'}->{$_};
		$v =~ s/"/\\"/g;
		print OUT "    try expect(std.mem.eql(u8,ti.getString(.$_).?,\"$v\"));\n";
		$term_attrs->{'strings'}->{$_} = undef;
	} else {
		print OUT "    try expect(ti.getString(.$_)==null);\n";
	}
}

print OUT "}\n";
close OUT;

if (system("zig test $testsource") == 0) {
	unlink $testsource;
}

report_extraneous($term_attrs);
