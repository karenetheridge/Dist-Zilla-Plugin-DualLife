package Dist::Zilla::Plugin::DualLife;
# ABSTRACT: Distribute dual-life modules with Dist::Zilla
# KEYWORDS: Makefile.PL core dual-life install INSTALLDIRS

our $VERSION = '0.06';

use Moose;
use List::Util 'first';
use namespace::autoclean;

with
    'Dist::Zilla::Role::ModuleMetadata',
    'Dist::Zilla::Role::InstallTool';

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

(assuming a module that entered core in 5.009005).

    [DualLife]
    entered_core=5.006001

=for Pod::Coverage setup_installer

=attr entered_core

Indicates when the distribution joined core.  This option is not normally
needed, as L<Module::CoreList> is used to determine this.

=cut

has entered_core => (
    is => 'ro',
    isa => 'Str',
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
    default => 0,
);

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        $self->entered_core ? ( entered_core => $self->entered_core ) : (),
        eumm_bundled => $self->eumm_bundled ? 1 : 0,
    };

    return $config;
};

sub setup_installer {
    my ($self) = @_;

    my $entered = $self->entered_core || do {
        my $mmd = $self->module_metadata_for_file($self->zilla->main_module);
        my $module = ($mmd->packages_inside)[0];
        require Module::CoreList;
        Module::CoreList->VERSION('2.19');
        Module::CoreList->first_release($module);
    };

    if (not $self->eumm_bundled)
    {
        # technically this only checks if the module is core, not dual-lifed, but a
        # separate repository shouldn't exist for non-dual modules anyway
        $self->log_fatal('this module is not dual-life!') if not $entered;

        if ($entered > 5.011000) {
            $self->log('this module entered core after 5.011 - nothing to do here');
            return;
        }
    }

    my $makefile = first { $_->name eq 'Makefile.PL' } @{ $self->zilla->files };
    $self->log_fatal('No Makefile.PL. It needs to be provided by another plugin')
        unless $makefile;

    my $content = $makefile->content;

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
