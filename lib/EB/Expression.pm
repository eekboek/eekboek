#!/usr/bin/perl -w
#
# NOTICE ---- This is a stripped version of Math::Expression ---- NOTICE
#
#      /\
#     /  \		(C) Copyright 2003 Parliament Hill Computers Ltd.
#     \  /		All rights reserved.
#      \/
#       .		Author: Alain Williams, January 2003
#       .		addw@phcomp.co.uk
#        .
#          .
#
#	SCCS: @(#)Expression.pm 1.14 03/26/03 21:49:29
#
# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself. You must preserve this entire copyright
# notice in any use or distribution.
# The author makes no warranty what so ever that this code works or is fit
# for purpose: you are free to use this code on the understanding that any problems
# are your responsibility.

# Permission to use, copy, modify, and distribute this software and its documentation for any purpose and without fee is
# hereby granted, provided that the above copyright notice appear in all copies and that both that copyright notice and
# this permission notice appear in supporting documentation.

use strict;

## package Math::Expression;
package EB::Expression;

use EB;

=begin stripped

use Exporter;
use POSIX;

# What local variables - visible elsewhere
use vars qw/
	@ISA @EXPORT
	/;

@ISA = ('Exporter');

@EXPORT = qw(
        &CheckTree
	&Eval
	&EvalToScalar
	&EvalTree
	&FuncValue
	&Parse
	&ParseString
	&SetOpts
	&VarSetFun
	&VarSetScalar
	$Version
);

our $VERSION = "1.14";

=cut

# Operator precedence, higher means evaluate first.
# If precedence values are the same associate to the left.
# 2 values, depending on if it is the TopOfStack or JustRead operator - [TOS, JR]. See ':=' which right associates.
# Just binary operators makes life easier as well.
my $HighestOperPrec = 14;
my $PrecTerminal = 15;		# Precedence of terminal (or list) - ie operand
my %OperPrec = (
	'('	=>	[16, 16],
	'var'	=>	[15, 15],
	'const'	=>	[15, 15],
	'func'	=>	[15, 15],
	'*'	=>	[14, 14],
	'/'	=>	[14, 14],
	'%'	=>	[14, 14],
	'+'	=>	[13, 13],
	'-'	=>	[13, 13],
	'.'	=>	[12, 12],
	'>'	=>	[11, 11],
	'<'	=>	[11, 11],
	'>='	=>	[11, 11],
	'<='	=>	[11, 11],
	'=='	=>	[11, 11],
	'!='	=>	[11, 11],
	'<>'	=>	[11, 11],
	'lt'	=>	[11, 11],
	'gt'	=>	[11, 11],
	'le'	=>	[11, 11],
	'ge'	=>	[11, 11],
	'eq'	=>	[11, 11],
	'ne'	=>	[11, 11],
	'&&'	=>	[10, 10],
	'||'	=>	[9, 9],
	':'	=>	[8, 8],
	'?'	=>	[7, 7],
	','	=>	[6, 6],
	':='	=>	[4, 5],
	')'	=>	[3, 3],
#	';'	=>	[0, 0],
);

# Default error output function
sub PrintError {
	printf STDERR @_;
	print STDERR "\n";
}

=begin stripped

# Default function to set a variable value, store as a reference to an array.
# Assign to a variable. (Default function.) Args:
# 0	Self
# 1	Variable name
# 2	Value - an array
# Return the value;
sub VarSetFun {
	my ($self, $name, @value) = @_;

	unless(defined($name)) {
		$self->{PrintErrFunc}("Undefined variable name - need () to force left to right assignment ?");
	} else {
		$self->{VarHash}->{$name} = \@value;
	}

	return @value;
}

# Set a scalar variable function
# 0	Self
# 1	Variable name
# 2	Value - a scalar
# Return the value;
sub VarSetScalar {
	my ($self, $name, $value) = @_;
	my @arr;
	$arr[0] = $value;
	$self->{VarSetFun}($self, $name, @arr);
	return $value;
}

# Return the value of a variable - return an array
# 0	Self
# 1	Variable name
sub VarGetFun {
	my ($self, $name) = @_;

	return '' unless(exists($self->{VarHash}->{$name}));
	return @{$self->{VarHash}->{$name}};
}

# Return 1 if a variable is defined - ie has been assigned to
# 0	Self
# 1	Variable name
sub VarIsDefFun {
	my ($self, $name) = @_;

	return exists($self->{VarHash}->{$name}) ? 1 : 0;
}

=cut

# Parse a string argument, return a tree that can be evaluated.
# Report errors with $ErrFunc.
# 0	Self
# 1	String argument
sub ParseString {
	my ($self, $expr) = @_;

	my %top = (oper	=> '(');
	my @operators = (\%top);	# Put '(' at top of the tree, matches virtual Ket
	my @operands;			# Parsed tree ends up here
	my $nodep;

	while(1) {
		$nodep = {()};

		# Lexical part:

		$expr =~ s/^\s*//;
		my $VirtKet = $expr eq '';

=begin original

		# Match integer/float constant:
		if($expr =~ s/^(\d+\.?\d*)//) {
			$nodep->{oper} = 'const';
			$nodep->{val} = $1;
		} # Match string bounded by ' or "
		elsif($expr =~ /^(['"])/ and $expr =~ s/^$1([^$1]*)$1//) {
			$nodep->{oper} = 'const';
			$nodep->{val} = $1;
		} # Match (operators)
		elsif($expr =~ s@^(:=|>=|<=|==|<>|!=|&&|\|\||lt|gt|le|ge|eq|ne|[-./*%+,<>\?:\(\);])@@) {
			$nodep->{oper} = $1;
		} # End of input string:
		elsif($VirtKet) {
			$nodep->{oper} = ')';
		} # Match 'function(', leave '(' in input:
		elsif($expr =~ s/^([a-zA-Z][\w]*)\(/(/) {
			$nodep->{oper} = 'func';
			$nodep->{fname} = $1;
		} # Match ${SomeNonWhiteCharsOrCurlies} or VarName or $VarName or $123 or $OneNonSpaceCharacter
		elsif($expr =~ s/^\$\{([^\s{}]+)\}|^\$(\d+|[_a-zA-Z]\w*|[^\s])|^([_a-zA-Z]\w*)//) {
			$nodep->{oper} = 'var';
			$nodep->{name} = defined($1) ? $1 : defined($2) ? $2 : $3;
		} else {
			$self->{PrintErrFunc}("Unrecognised input in expression at '%s'", $expr);
			return;
		}

=cut

### replacement for original ###

		# Match integer/float constant:
		if($expr =~ s/^(\d+([.,]?)\d*)//) {
			$nodep->{oper} = 'const';
			$nodep->{val} = $1;
			$nodep->{val} =~ s/,/./ if defined($2) && $2 eq ",";
		} # Match string bounded by ' or "
		elsif($expr =~ s@^([-/*%+\(\)])@@) {
			$nodep->{oper} = $1;
		} # End of input string:
		elsif($VirtKet) {
			$nodep->{oper} = ')';
		} # Match 'function(', leave '(' in input:
		else {
			$self->{PrintErrFunc}("Unrecognised input in expression at '%s'", $expr);
			return;
		}

### end replacement for original ###

		# Grammatical part:

		while(1) {
			my $NewOpPrec = $OperPrec{$nodep->{oper}}[1];

			# End of input ?
			if($VirtKet and $#operators == 0) {
				if($#operands != 0) {
					$self->{PrintErrFunc}("Expression error - %s",
						$#operands == -1 ? "it's incomplete" : "missing operator");
					return;
				}
				return pop @operands;
			}

			# Terminal (var/const) - KV not '(' or 'func':
			if($NewOpPrec >= $PrecTerminal and $nodep->{oper} ne '(' and $nodep->{oper} ne 'func') {
				push @operands, $nodep;
				last;	# get next token
			} # It must be an operator, which must have a terminal to it's left side:

			if($#operators < 0) {
				$self->{PrintErrFunc}("Syntax error at '%s'", $expr);
				return;
			}

			# Eliminate ()
			if($operators[$#operators]->{oper} eq '(' and $nodep->{oper} eq ')') {
				if($VirtKet and $#operators != 0) {
					$self->{PrintErrFunc}("Unexpected end of expression with unmatched '('");
					return;
				}

				if(!$VirtKet and $#operators == 0) {
					$self->{PrintErrFunc}("Unexpected ')'");
					return;
				}

				pop @operators;
				last;	# get next token
			}

			# New operator binds more than top op, push so that we get the RH expression:
			if($NewOpPrec > $OperPrec{$operators[$#operators]->{oper}}[0] or $operators[$#operators]->{oper} eq '(') {
				push @operators, $nodep;
				last;	# get next token
			}

			# Reduce: While we have LH & RH operands, replace top 2 operands with node that evaluates them:
			while($NewOpPrec <= $OperPrec{$operators[$#operators]->{oper}}[0] and $operators[$#operators]->{oper} ne '(') {
				my $top = pop @operators;
				my $func = $top->{oper} eq 'func';

				unless($#operands >= ($func ? 0 : 1)) {
					$self->{PrintErrFunc}("Missing operand to operator '%s' at %s", $top->{oper},
						($expr ne '' ? "'$expr'" : 'end'));
					return;
				}

				# With 2 operands we can treat as an operand:
				$top->{right} = pop @operands;
				$top->{left}  = pop @operands unless($func);
				push @operands, $top;
			}
		}
	}
}

# Check the tree for problems, args:
# 0	Self
# 1	a tree, return that tree, return undef on error.
# Report errors with $ErrFunc.
sub CheckTree {
	my ($self, $tree) = @_;
	return unless(defined($tree));

	return $tree if($tree->{oper} eq 'var' or $tree->{oper} eq 'const');

	my $ok = 1;

	if($tree->{oper} eq '?' and $tree->{right}{oper} ne ':') {
		$self->{PrintErrFunc}("Missing ':' operator after '?' operator");
		$ok = 0;
	}

	if($tree->{oper} ne 'func') {
		$ok = 0 unless(&CheckTree($self, $tree->{left}));
	}
	$ok = 0 unless(&CheckTree($self, $tree->{right}));

	return $ok ? $tree : undef;
}

# Parse & check an argument string, return the parsed tree.
# Report errors with $ErrFunc.
# 0	Self
# 1	an expression
sub Parse {
	my ($self, $expr) = @_;

	return &CheckTree($self, &ParseString($self, $expr));
}

# Print a tree - for debugging purposes. Args:
# 0	Self
# 1	A tree
# Hidden second argument is the initial indent level.
sub PrintTree {
	my ($self, $nodp, $dl) = @_;

	$dl = 0 unless(defined($dl));
	$dl++;

	unless(defined($nodp)) {
		print "    " x $dl . "UNDEF\n";
		return;
	}

	print "    " x $dl;
	print "nod=$nodp [$nodp->{oper}] P $OperPrec{$nodp->{oper}}[0] ";

	if($nodp->{oper} eq 'var') {
		print "var($nodp->{name}) \n";
	} elsif($nodp->{oper} eq 'const') {
		print "const($nodp->{val}) \n";
	} else {
		print "\n";
		print "    " x $dl;print "Desc L \n";
		&PrintTree($self, $nodp->{left}, $dl);

		print "    " x $dl;print "op '$nodp->{oper}' P $OperPrec{$nodp->{oper}}[0] at $nodp\n";

		print "    " x $dl;print "Desc R \n";
		&PrintTree($self, $nodp->{right}, $dl);
	}
}

# Evaluate a tree. Return a scalar.
# Args:
# 0	Self
# 1	The root of a tree.
sub EvalToScalar {
	my ($self, $tree) = @_;
	my @res = &EvalTree($self, $tree, 0);

	return $res[$#res];
}

# Evaluate a tree. The result is an array, if you are expecting a single value it is the last (probably $#'th) element.
# Args:
# 0	Self
# 1	The root of a tree.
sub Eval {
	my ($self, $tree) = @_;

	return &EvalTree($self, $tree, 0);
}

# Evaluate a tree. The result is an array, if you are expecting a single value it is the last (probably $#'th) element.
# Args:
# 0	Self
# 1	The root of a tree.
# 2	Want Lvalue flag -- return variable name rather than it's value
# Report errors with the function $PrintErrFunc
# Checking undefined values is a pain, assignment of undef & concat undef is OK.
sub EvalTree {
	my ($self, $tree, $wantlv) = @_;

	return unless(defined($tree));

	my $oper = $tree->{oper};

	return $tree->{val}										if($oper eq 'const');
	return $wantlv ? $tree->{name} : $self->{VarGetFun}($self, $tree->{name})			if($oper eq 'var');

	# Recognise the 'defined' func specially - it needs a lvalue
	return $self->{FuncEval}($self, $tree->{fname},
				&EvalTree($self, $tree->{right}, $tree->{fname} eq 'defined'))		if($oper eq 'func');

	# This is complicated by multiple assignment: (a, b, c) := (1, 2, 3, 4). 'c' is given '(3, 4)'.
	if($oper eq ':=') {
		my @left = &EvalTree($self, $tree->{left}, 1);
		my @right = &EvalTree($self, $tree->{right}, $wantlv);

		# Easy case, assigning to one variable, assign the whole array:
		return $self->{VarSetFun}($self, @left, @right) if($#left == 0);

		# Assign conseq values to conseq variables. The last var gets the rest of the values.
		# Ignore too many vars.
		for(my $i = 0; $i <= $#right; $i++) {
			if($i != $#right and $i == $#left) {
				$self->{VarSetFun}($self, $left[$i], @right[$i ... $#right]);
				last;
			}
			$self->{VarSetFun}($self, $left[$i], $right[$i]);
		}
		return @right;
	}

	# Evaluate left - may be able to avoid evaluating right:
	my @left = &EvalTree($self, $tree->{left}, $wantlv);
	my $left = $left[$#left];
	if(!defined($left) and $oper ne ',' and $oper ne '.') {
		unless($self->{AutoInit}) {
			$self->{PrintErrFunc}("Left value to operator '%s' is not defined", $oper);
			return;
		}
		$left = '';	# Set to the empty string
	}

	# Lazy evaluation:
	return $left ?  &EvalTree($self, $tree->{right}{left}, $wantlv) :
			&EvalTree($self, $tree->{right}{right}, $wantlv)		if($oper eq '?');

	# Constructing a list of variable names (for assignment):
	return (@left, &EvalTree($self, $tree->{right}, 1))				if($oper eq ',' and $wantlv);

	# More lazy evaluation:
	if($oper eq '&&' or $oper eq '||') {
		return 0 if($oper eq '&&' and !$left);
		return 1 if($oper eq '||' and  $left);

		my @right = &EvalTree($self, $tree->{right}, 0);

		return($right[$#right] ? 1 : 0);
	}

	# Everything else is a binary operator, get right side - value(s):
	my @right = &EvalTree($self, $tree->{right}, 0);

	return (@left, @right)	if($oper eq ',');
#	return @right		if($oper eq ';');

	# Everything else just takes a simple (non array) value, use last value in a list.
	# It is OK to concat undef.
	my $right = $right[$#right];

	if($oper eq '.') {
		# If one side is undef, treat as empty:
		$left = ""  unless(defined($left));
		$right = "" unless(defined($right));
		return $left . $right;
	}

	unless(defined($right)) {
		unless($self->{AutoInit}) {
			$self->{PrintErrFunc}("Right value to operator '%s' is not defined", $oper);
			return;
		}
		$right = '';
	}

	return $left lt $right ? 1 : 0 if($oper eq 'lt');
	return $left gt $right ? 1 : 0 if($oper eq 'gt');
	return $left le $right ? 1 : 0 if($oper eq 'le');
	return $left ge $right ? 1 : 0 if($oper eq 'ge');
	return $left eq $right ? 1 : 0 if($oper eq 'eq');
	return $left ne $right ? 1 : 0 if($oper eq 'ne');

	return ($left, $right) 		     if($oper eq ':');	# Should not be used, done in '?'
#	return $left ? $right[0] : $right[1] if($oper eq '?');	# Non lazy version

	# Everthing else is an arithmetic operator, check for left & right being numeric. NB: '-' 'cos may be -ve.
	# Returning undef may result in a cascade of errors.
	# Perl would treat 012 as an octal number, that would confuse most people, convert to a decimal interpretation.
	unless($left =~ /^(-?)0*([\d.]+)/) {
		unless($self->{AutoInit} and $left eq '') {
			$self->{PrintErrFunc}("Left hand operator to '%s' is not numeric '%s'", $oper, $left);
			return;
		}
		$left = 0;
	}
	$left = "$1$2";
	unless($right =~ /^(-?)0*([\d.]+)/) {
		unless($self->{AutoInit} and $right eq '') {
			$self->{PrintErrFunc}("Right hand operator to '%s' is not numeric '%s'", $oper, $right);
			return;
		}
		$right = 0;
	}
	$right = "$1$2";

	return $left *  $right if($oper eq '*');
	return $left /  $right if($oper eq '/');
	return $left %  $right if($oper eq '%');
	return $left +  $right if($oper eq '+');
	return $left -  $right if($oper eq '-');

	# Force return of true/false -- NOT undef
	return $left >  $right ? 1 : 0 if($oper eq '>');
	return $left <  $right ? 1 : 0 if($oper eq '<');
	return $left >= $right ? 1 : 0 if($oper eq '>=');
	return $left <= $right ? 1 : 0 if($oper eq '<=');
	return $left == $right ? 1 : 0 if($oper eq '==');
	return $left != $right ? 1 : 0 if($oper eq '!=');
	return $left != $right ? 1 : 0 if($oper eq '<>');
}

=begin stripped

# Evaluate a function:
sub FuncValue {
	my ($self, $fname, @arglist) = @_;

	my $last = $arglist[$#arglist];

	return int($last)					if($fname eq 'int');
	return int($last + 0.5)					if($fname eq 'round');

	return split $arglist[0], $arglist[$#arglist]		if($fname eq 'split');
	return join  $arglist[0], @arglist[1 ... $#arglist]	if($fname eq 'join');

	return sprintf $arglist[0], @arglist[1 ... $#arglist]	if($fname eq 'printf');

	return mktime(@arglist)					if($fname eq 'mktime');
	return strftime($arglist[0], @arglist[1 ... $#arglist])	if($fname eq 'strftime');
	return localtime($last)					if($fname eq 'localtime');

	return $self->{VarIsDefFun}($self, $last)		if($fname eq 'defined');

	# aindex(array, val) returns index (from 0) of val in array, -1 on error
	if($fname eq 'aindex') {
		my $val = $arglist[$#arglist];
		for( my $inx = 0; $inx <= $#arglist - 1; $inx++) {
			return $inx if($val eq $arglist[$inx]);
		}
		return -1;
	}

	$self->{PrintErrFunc}("Unknown function '$fname'");

	return '';
}

=cut

# Create a new parse/evalutation object.
# Initialise default options.
sub new {
	my $class = shift;

	# What we store about this evaluation environment, default values:
	my %ExprVars = (
		'PrintErrFunc'	=>	\&PrintError,		# Printf errors
		'VarHash'	=>	{(			# Variable hash
					EmptyArray	=>	[()],
					EmptyList	=>	[()],
			)},
		'VarGetFun'	=>	\&VarGetFun,		# Get a variable function
		'VarIsDefFun'	=>	\&VarIsDefFun,		# Is a variable defined function
		'VarSetFun'	=>	\&VarSetFun,		# Set an array variable function
		'VarSetScalar'	=>	\&VarSetScalar,		# Set a scalar variable function
		'FuncEval'	=>	\&FuncValue,		# Evaluate function
		'AutoInit'	=>	0,			# If true auto initialise variables
	);

	return bless \%ExprVars => $class;
}

# Set an option in the %template.
sub SetOpt {
	my $self = shift @_;

	while($#_ > 0) {
		&Error($self, "Unknown option '$_[0]'") unless(defined($self->{$_[0]}));
		&Error($self, "No value to option '$_[0]'") unless(defined($_[1]));
		$self->{$_[0]} = $_[1];
		shift;shift;
	}
}

1;

__END__

=head1 NAME

EB::Expression - Evaluate arithmetic/string expressions

=head1 SYNOPSIS

  use strict;
  use EB::Expression;

  my $ArithEnv = new Math::Expression;

  my $tree = $ArithEnv->Parse('( 1 + 2 ) *3');
  ...

  print $ArithEnv->EvalToScalar($tree);

=head1 DESCRIPTION

This is stripped version of Math::Expression.

Many things you read here do not work.

=head1 DESCRIPTION

An expression needs to be first compiled (parsed) and the resulting tree may be run (evaluated)
many times.
The result of an evaluation is an array.
You might also want to take computation results from stored variables.

For further examples of use please see the test program for the module.

=head2 Package functions

=over 4

=item new

This must be used before anything else to obtain a handle that can be used in calling other
functions.

=item SetOpt

The items following may be set.
In many cases you will want to set a function to extend what the standard one does.

=over 4

=item PrintErrFunc

This is a printf style function that will be called in the event of an error,
the error text will not have a trailing newline.
The default is C<printf STDERR>.

=item VarHash

The argument is a hash that will be used to store variables.
If this is called several times it is possible to manage distinct name spaces.
The name C<EmptyList> should, by convention, exist and be an empty array; this may be
used to assign an empty value to a variable.

=item VarGetFun

This specifies the that function returns the value of a variable as an array.
The arguments are: 0 - the value returned by C<new>; 1 - the name of the variable
wanted.
If no value is available you may return the empty array.

=item VarIsDefFun

This should return C<1> if the variable is defined, C<0> if it is not defined.
The arguments are the same as for C<VarGetFun>.

=item VarSetFun

This sets the value of a variable as an array.
The arguments are: 0 - the value returned by C<new>; 1 - the name of the variable
to be set; 2 - the value to set as an array.
The return value should be the variable value.

=item VarSetScalar

This sets the value of a variable as a simple scalar (ie one value).
The arguments are: 0 - the value returned by C<new>; 1 - the name of the variable
to be set; 2 - the value to set as a scalar.
The return value should be the variable value.

=item FuncEval

This will evaluate functions.
The arguments are: 0 - the value returned by C<new>; 1 - the name of the function
to be evaluated; 2... - an array of function arguments.
This should return the value of the function: scalar or array.

=item AutoInit

If true automatically initialise undefined values, to the empty string or '0' depending on use.
The default is that undefined values cause an error, except that concatentation (C<.>)
always results in the empty string being assumed.

Example:

  my %Vars = (
	EmptyList       =>      [()],
  );

  $ArithEnv->SetOpt('VarHash' => \%Vars,
	'VarGetFun' => \&VarValue,
	'VarIsDefFun' => \&VarIsDef,
	'PrintErrFunc' => \&MyPrintError,
	'AutoInit' => 1,
	);

=back

=item ParseString

This parses an expression string and returns a tree that may be evaluated later.
The arguments are: 0 - the value returned by C<new>; 1 - the string to parse.
If there is an error a complaint will be made via C<PrintErrFunc> and the
undefined value returned.

=item CheckTree

This checks a parsed tree.
The arguments are: 0 - the value returned by C<new>; 1 - the tree to check.
The input tree is returned.
If there is an error a complaint will be made via C<PrintErrFunc> and the
undefined value returned.

=item Parse

This combines C<ParseString> and C<CheckTree>.

=item VarSetFun

This sets a variable, see the description in &SetOpt.

=item VarSetScalar

This sets a variable, see the description in &SetOpt.

=item FuncValue

This evaluates a function, see the description in &SetOpt.

=item EvalTree

Evaluate a tree. The result is an array, if you are expecting a single value it is the last (probably $#'th) element.
The arguments are: 0 - the value returned by C<new>; 1 - tree to evaluate; 2 - true if
a variable name is to be returned rather than it's value (don't set this).
You should not use this, use &Eval or &EvalToScalar instead.

=item Eval

Evaluate a tree. The result is an array, if you are expecting a single value it is the last (probably $#'th) element.
The arguments are: 0 - the value returned by C<new>; 1 - tree to evaluate.

=item EvalToScalar

Evaluate a tree. The result is a scalar (simple variable).
The arguments are: 0 - the value returned by C<new>; 1 - tree to evaluate.

=back

=head2 Functions that may be used in expressions

The following functions may be used in expressions, if you want more than this write your own
function evaluator and set it with &SetOpt;
The POSIX package is used to provide some of the functions.

=over 4

=item int

Returns the integer part of an expression.

=item round

Adds 0.5 to input and returns the integer part.

=item split

Perl C<split>, the 0th argument is the RE to split on, the last argument what will be split.

=item join

Joins arguments 1..$#, separating elements with the 0th argument.

=item printf

The standard perl C<printf>, returns the formatted result.

=item mktime

Passes all the arguments to C<mktime>, returns the result.

=item strftime

Passes all the arguments to C<strftime>, returns the result.

=item localtime

Returns the result of applying C<localtime> to the last argument.

=item defined

Applies the C<VarIsDefFun> to the last argument.

=item aindex

Searches the arguments for the last argument and returns the index.
Return -1 if it is not found.
Eg the following will return 1:

  months := 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  aindex(months, 'Feb')

=back

=head2 Variables

Variables can 3 three forms, there is no difference in usage between any of them.
A variable name is either alphanumeric (starting with alpha), numeric (with
a leading C<$> or C<${>, or any non white space between C<{}> or one non
white space after a C<$>:

	Variable
	$Variable
	${Variable}
	$123
	${123}
	$#
	${###=##}

=head2 Literals

Literals may be: integers, floating point in the form nn.nn, strings bounded by
matching singe or double quotes. Escapes are not looked for in literal strings.

=head2 Operators and precedence

The operators should not surprise any Perl/C programmer, with the exception that assignemnt
is C<:=>. Operators associate left to right except for C<:=> which associates right to left.
Precedence may be overridden with parenthesis.
Unary C<+> and  C<-> do not exist.
<> is the same as C<!=>.

	* / %
	+ -
	.	String concatenation
	> < >= <= == != <>
	lt gt le ge eq ne
	&&
	||
	? :
	,
	:=

=head2 Arrays

Variables are implemented as arrays, if a simple scalar value is wanted (eg you want to go C<+>)
the last element of the array is used.
Arrays may be built using the comma operator, arrays may be joined using C<,> eg:

	a1 := (1, 2, 3, 4)
	a2 := (9, 8, 7, 6)
	a1 , a2

yeilds:

	1, 2, 3, 4, 9, 8, 7, 6

And:

	a2 + 10

yeilds:

	16

Arrays may be used to assign multiple values, eg:

	(v1, v2, v3) := (42, 44, 48)

If there are too many values the last variable receives the remainder.
If there are not enough values the last ones are unchanged.

=head2 Conditions

Conditional assignment may be done by use of the ternary operator:

	a > b ? ( c := 3 ) : 0

Variables may be the result of a conditional, so below one of C<aa> or C<bb>
is assigned a value:

	a > b ? aa : bb := 124

=head1 AUTHOR

Alain D D Williams <addw@phcomp.co.uk>

=head2 Copyright and Version

Version "1.14", this is available as: $Math::Expression::Version.

Copyright (c) 2003 Parliament Hill Computers Ltd/Alain D D Williams. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. Please see the module source
for the full copyright.

=cut

# end
