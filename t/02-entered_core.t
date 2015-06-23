use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

my $tzil = Builder->from_config(
    { dist_root => 'does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
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
