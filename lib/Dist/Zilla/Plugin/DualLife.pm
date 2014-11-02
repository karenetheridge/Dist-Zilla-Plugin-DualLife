package Dist::Zilla::Plugin::DualLife;
# ABSTRACT: Distribute dual-life modules with Dist::Zilla

use Moose;
use List::AllUtils 'first';
use namespace::autoclean;

with 'Dist::Zilla::Role::InstallTool';

=head1 SYNOPSIS

In your dist.ini:

  [DualLife]

=head1 DESCRIPTION

Dual-life modules, which are modules distributed both as part of the perl core
and on CPAN, sometimes need a little special treatment. This module tries
provide that for modules built with C<Dist::Zilla>.

Currently the only thing this module does is providing an C<INSTALLDIRS> option
to C<ExtUtils::MakeMaker>'s C<WriteMakefile> function, so dual-life modules will
be installed in the right section of C<@INC> depending on different versions of
perl.

As more things that need special handling for dual-life modules show up, this
module will try to address them as well.

The options added to your C<Makefile.PL> by this module are roughly equivalent
to:

    'INSTALLDIRS' => ($] >= 5.009005 && $] <= 5.011000 ? 'perl' : 'site'),

If the module didn't enter core in 5.009005, set the C<entered_core>
attribute appropriately:

    [DualLife]
    entered_core=5.006001

=begin Pod::Coverage

setup_installer

=end Pod::Coverage

=attr entered_core

Indicates when the distribution joined core.  Defaults to 5.009005 for
all the things that came in for 5.10.

=cut

has entered_core => (
    is => 'ro',
    isa => 'Str',
    default => "5.009005",
);

=attr eumm_bundled

Boolean for distributions bundled with ExtUtils::MakeMaker.  Prior to v5.12,
bundled modules might get installed into the core library directory, so
even if they didn't come into core until later, they need to be forced into
core prior to v5.12 so they take precedence.

=cut

has eumm_bundled => (
    is => 'ro',
    isa => 'Bool',
    default => "0",
);

sub setup_installer {
    my ($self) = @_;

    my $makefile = first { $_->name eq 'Makefile.PL' } @{ $self->zilla->files };
    $self->log_fatal('No Makefile.PL. It needs to be provided by another plugin')
        unless $makefile;

    my $content = $makefile->content;
    my $entered = $self->entered_core;

    my $dual_life_args = q[$WriteMakefileArgs{INSTALLDIRS} = 'perl'];

    if ( $self->eumm_bundled ) {
        $dual_life_args .= "\n    if \$] <= 5.011000;\n\n";
    }
    else {
        $dual_life_args .= "\n    if \$] >= $entered && \$] <= 5.011000;\n\n"
    }

    $content =~ s/(?=WriteMakefile\s*\()/$dual_life_args/
        or $self->log_fatal('Failed to insert INSTALLDIRS magic');

    $makefile->content($content);
}

__PACKAGE__->meta->make_immutable;

1;
