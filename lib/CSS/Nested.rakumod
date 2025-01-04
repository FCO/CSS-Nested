use CSS::Grammar::CSS3;

use CSS::Grammar::Actions;
unit grammar CSS::Nested is CSS::Grammar::CSS3;

rule any-declaration  {
	<Ident=.property> <expr> <prio>? <end-decl>
	| <at-keyw> <declarations>
	|| <ruleset>
	|| <dropped-decl>
}

multi rule combinator:sym<&> { <sym> }
rule selector{ <op=.combinator>? <simple-selector> +%% <op=.combinator>? }

class Actions is CSS::Grammar::Actions {
	method combinator:sym<&>($/) { make (:op<&>) }
	method any-declaration($/)    {
		use CSS::Grammar::Defs :CSSObject, :CSSValue, :CSSUnits, :CSSSelector;

		return if $<dropped-decl>;

		return make $.build.at-rule($/)
		if $<declarations>;

		return make .made with $<ruleset>;

		return $.warning('dropping declaration', $<Ident>.ast)
		if !$<expr>.caps
		|| $<expr>.caps.first({! .value.ast.defined});

		make $.build.token($.build.node($/), :type(CSSValue::Property));
	}
}

sub parse-stylesheet($css) is export {
    use CSS::Grammar::Actions;
    my Actions $actions .= new;

    CSS::Nested.parse($css, :$actions)
       or die "unable to parse: $css";

    if $actions.warnings[] {
	    .note for $actions.warnings[];
	    die
    }

    return process-ast $/.ast
}

sub process-ast($ast) {
	die "I don't know how to process this { $ast.key }" unless $ast.key.Str eq "stylesheet";
	my @ss := $ast.value;

	sub while-ruleset(@decls) {
		do for @decls -> %opts {
			do with %opts<ruleset> -> %ruleset {
				my @selectors = |%ruleset<selectors>;
				my %ds := %ruleset<declarations>.map({ %$_ }).classify: {
					.<ruleset>:exists
						?? "rule"
						!! "decl"
				};
				my @rsets = %( :ruleset(%( :@selectors, :declarations(.[]) ))) with %ds<decl>;
				@rsets.push: |.[].&while-ruleset.map: -> (:$key, :%value ( :selectors(@sel), *%pars )) {
					:ruleset(%( |%pars, :selectors(merge-selectors @selectors, @sel) ))
				} with %ds<rule>;
				|@rsets
			}
		}
	}

	my @all = |while-ruleset @ss;
	stylesheet => @all
}

sub merge-selectors(@parent, @child) {
	|do for @parent X @child -> [%p-selectors, %c-selectors] {
		my @p = %p-selectors<selector>[];
		my @c = %c-selectors<selector>[];
		selector => do if (@c.head<op> // '') eq '&' {
			@c.shift;
			my @pss = @p.tail<simple-selector>[];
			my @css = @c.head<simple-selector>[];
			[ |@p.head(*-1), simple-selector => [|@pss, |@css], |(@c.skip if @c) ];
		} else {
			[ |%p-selectors<selector>[], |%c-selectors<selector>[] ]
		}
	}
}

=begin pod

=head1 NAME

CSS::Nested - CSS::Grammar, but nested

=head1 SYNOPSIS

=begin code :lang<raku>

use CSS::Nested;

=end code

=head1 DESCRIPTION

CSS::Nested is CSS, but nested

Still very early stage of development. It has no tests yet!

=head1 AUTHOR

Fernando Corrêa de Oliveira <fco@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2025 Fernando Corrêa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
