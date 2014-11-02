use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => dist_ini(
                {
                    name     => 'warnings',
                    abstract => 'oh noes!',
                    version  => '2.123',
                    author   => 'E. Xavier Ample <example@example.org>',
                    license  => 'Perl_5',
                    copyright_holder => 'E. Xavier Ample',
                },
                [ GatherDir => ],
                [ MakeMaker => ],
                [ DualLife  => { entered_core => '5.010001' } ],
            ),
            path(qw(source lib warnings.pm)) => "package warnings;\n1;\n",
        },
    },
);

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

my $build_dir = path($tzil->tempdir)->child('build');

my $file = $build_dir->child('Makefile.PL');
ok(-e $file, 'Makefile.PL created');

my $makefile = $file->slurp_utf8;
unlike($makefile, qr/[^\S\n]\n/m, 'no trailing whitespace in modified file');

like(
    $makefile,
    qr/\$WriteMakefileArgs\{INSTALLDIRS\} = 'perl'\s+if \$\] >= 5\.010001 && \$\] <= 5.011000;.*WriteMakefile\(\%WriteMakefileArgs\);/ms,
    'Makefile.PL has INSTALLDIRS arg set under correct conditions',
);

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
