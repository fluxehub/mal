use strict;
use warnings FATAL => qw(all);
use File::Basename;
use lib dirname (__FILE__);
use List::Util qw(pairmap);
use readline qw(mal_readline set_rl_mode);
use Data::Dumper;

use types qw(_list_Q);
use reader;
use printer;

# read
sub READ {
    my $str = shift;
    return reader::read_str($str);
}

# eval
sub eval_ast {
    my($ast, $env) = @_;
    if ($ast->isa('Symbol')) {
	return $env->{$$ast} || die "'$$ast' not found\n";
    } elsif ($ast->isa('Sequence')) {
	return ref($ast)->new([ map { EVAL($_, $env) } @$ast ]);
    } elsif ($ast->isa('HashMap')) {
	return HashMap->new({ pairmap { $a => EVAL($b, $env) } %$ast });
    } else {
	return $ast;
    }
}

sub EVAL {
    my($ast, $env) = @_;
    #print "EVAL: " . printer::_pr_str($ast) . "\n";
    if (! _list_Q($ast)) {
        return eval_ast($ast, $env);
    }

    # apply list
    unless (@$ast) { return $ast; }
    my @el = @{eval_ast($ast, $env)};
    my $f = shift @el;
    return &$f(@el);
}

# print
sub PRINT {
    my $exp = shift;
    return printer::_pr_str($exp);
}

# repl
my $repl_env = {
    '+' => sub { Integer->new(${$_[0]} + ${$_[1]}) },
    '-' => sub { Integer->new(${$_[0]} - ${$_[1]}) },
    '*' => sub { Integer->new(${$_[0]} * ${$_[1]}) },
    '/' => sub { Integer->new(${$_[0]} / ${$_[1]}) },
};

sub REP {
    my $str = shift;
    return PRINT(EVAL(READ($str), $repl_env));
}

if (@ARGV && $ARGV[0] eq "--raw") {
    set_rl_mode("raw");
}
while (1) {
    my $line = mal_readline("user> ");
    if (! defined $line) { last; }
    do {
        local $@;
        my $ret;
        eval {
            use autodie; # always "throw" errors
            print(REP($line), "\n");
            1;
        } or do {
            my $err = $@;
            if ($err->isa('BlankException')) {
		# ignore and continue
	    } else {
		chomp $err;
		print "Error: $err\n";
            }
        };
    };
}
